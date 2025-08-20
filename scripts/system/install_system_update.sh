#!/bin/bash
# install_system_update.sh

TOOL_NAME="System Updates"

# Function to check status
check_status() {
    # System updates don't have a specific "installed" state
    # We'll consider it always available since it's a system command
    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    echo "Instalando $TOOL_NAME..."
    
    # Update system
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
