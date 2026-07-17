#!/bin/bash
# install_system_update.sh
#
# `status` es un diagnóstico real de solo lectura (no siempre "INSTALLED"
# sin verificar nada, como antes — ver docs/adr/0013-separar-mantenimiento-de-instaladores.md
# y el hallazgo de docs/UBUNTU_COMPATIBILITY.md): reporta si hay
# actualizaciones pendientes según la última información de apt conocida,
# sin ejecutar `apt update` (eso sería una acción, no un diagnóstico).

TOOL_NAME="System Updates"

# Function to check status
check_status() {
    local upgradable_count
    upgradable_count="$(apt list --upgradable 2>/dev/null | grep -cv '^Listing' || true)"

    if [[ "${upgradable_count}" -eq 0 ]]; then
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
    sudo apt upgrade -y

    echo "Actualizaciones del sistema completadas."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    echo "Las actualizaciones del sistema no se pueden desinstalar."
    echo "Este comando solo actualiza el sistema."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
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
