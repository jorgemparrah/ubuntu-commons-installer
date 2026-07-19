#!/usr/bin/env bash
# install_obs_studio.sh
#
# 'status' distingue snap no instalado (NOT_INSTALLED) de snapd ausente
# (UNKNOWN, no se puede determinar) — antes reportaba NOT_INSTALLED en
# ambos casos por igual (hallazgo de docs/UBUNTU_COMPATIBILITY.md). No
# verificable automáticamente en Docker (snapd no corre sin systemd); ver
# la pauta de validación manual en docs/UBUNTU_COMPATIBILITY.md.

set -Eeuo pipefail
TOOL_NAME="OBS Studio"
SNAP_PACKAGE="obs-studio"

# Function to check status
check_status() {
    if command -v obs-studio &> /dev/null; then
        echo "INSTALLED"
        return 0
    fi
    if ! command -v snap &> /dev/null || ! snap list &> /dev/null; then
        echo "UNKNOWN"
        return 1
    fi
    if snap list 2>/dev/null | grep -q "^${SNAP_PACKAGE} "; then
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
    
    # Install OBS Studio via snap
    echo "Installing OBS Studio via snap..."
    sudo snap install "${SNAP_PACKAGE}" --classic
    
    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove package via snap
    sudo snap remove "${SNAP_PACKAGE}"
    
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
