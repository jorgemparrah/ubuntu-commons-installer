#!/usr/bin/env bash
# install_development_tools.sh

set -Eeuo pipefail
TOOL_NAME="Development Tools (wget, curl, git, build-essential, ...)"
DEV_PACKAGES=("wget" "curl" "git" "build-essential" "software-properties-common" "apt-transport-https" "gnupg2")

# Function to check if a package is installed
#
# dpkg -s devuelve éxito incluso para un paquete en estado remanente
# "config-files" tras un 'apt remove' sin purgar — falso positivo real
# encontrado en Cursor/VS Code/Chrome (ver docs/UBUNTU_COMPATIBILITY.md).
# 'dpkg -l | grep ^ii' solo es verdad para un paquete realmente instalado.
check_package_installed() {
    local package="$1"
    dpkg -l "$package" 2>/dev/null | grep -q '^ii'
}

# Function to check if all packages are installed
check_all_packages_installed() {
    local package
    for package in "${DEV_PACKAGES[@]}"; do
        if ! check_package_installed "$package"; then
            return 1
        fi
    done
    return 0
}

# Function to check status
check_status() {
    if check_all_packages_installed; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    echo "Instalando $TOOL_NAME..."

    sudo apt update
    sudo apt install -y "${DEV_PACKAGES[@]}"

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    sudo apt purge -y "${DEV_PACKAGES[@]}"
    sudo apt autoremove -y

    echo "$TOOL_NAME desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Main function
main() {
    case "${1:-}" in
        "status")
            check_status
            ;;
        "install")
            install_tool
            ;;
        "uninstall")
            uninstall_tool
            ;;
        "reinstall")
            reinstall_tool
            ;;
        *)
            echo "Uso: $0 {status|install|uninstall|reinstall}"
            exit 1
            ;;
    esac
}

main "$@"
