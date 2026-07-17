#!/bin/bash
# install_ulauncher.sh
#
# ULauncher no está en los repositorios oficiales de Ubuntu ni tiene un
# Snap/Flatpak oficial mantenido por el proyecto (ver ADR 0027, categoría
# "solo disponible comunitario" — evaluar reputación y mantenimiento). Se
# usa el PPA oficial del propio proyecto ULauncher
# (ppa:agornostal/ulauncher, mantenido por su autor/maintainer principal,
# documentado en https://ulauncher.io como método de instalación oficial
# para Ubuntu/Debian). Antes este script nunca agregaba esa fuente y
# `apt install ulauncher` fallaba siempre (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md, no específico de Ubuntu 26).

TOOL_NAME="ULauncher"

# Function to check status
check_status() {
    if command -v ulauncher &> /dev/null; then
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

    # add-apt-repository requiere software-properties-common; no se puede
    # asumir presente (encontrado al validar en CI, ver docs/UBUNTU_COMPATIBILITY.md).
    if ! command -v add-apt-repository &> /dev/null; then
        sudo apt update
        sudo apt install -y software-properties-common
    fi

    sudo add-apt-repository -y universe
    sudo add-apt-repository -y ppa:agornostal/ulauncher
    sudo apt update
    sudo apt install -y ulauncher

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    sudo apt remove -y ulauncher
    sudo apt autoremove -y
    sudo add-apt-repository -y --remove ppa:agornostal/ulauncher

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
    case "$1" in
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
