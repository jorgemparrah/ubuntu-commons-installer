#!/bin/bash
# install_kernel.sh

TOOL_NAME="Kernel & Headers"

# Function to check status
check_status() {
    if dpkg -l | grep -q "linux-generic-hwe"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to get the latest available HWE kernel
get_latest_hwe_kernel() {
    # Update package list to get latest available kernels
    sudo apt update
    
    # Find the latest HWE kernel available
    local latest_kernel=$(apt list --upgradable 2>/dev/null | grep "linux-generic-hwe" | tail -1 | cut -d'/' -f1)
    
    if [[ -n "$latest_kernel" ]]; then
        echo "$latest_kernel"
    else
        # Fallback to current Ubuntu version HWE kernel
        local ubuntu_version=$(lsb_release -cs)
        echo "linux-generic-hwe-${ubuntu_version}"
    fi
}

# Function to check if kernel update is available
check_kernel_update_available() {
    sudo apt update
    if apt list --upgradable 2>/dev/null | grep -q "linux-generic-hwe"; then
        return 0  # Update available
    else
        return 1  # No update available
    fi
}

# Function to install
install_tool() {
    echo "Instalando $TOOL_NAME..."
    
    # Check if any HWE kernel is installed
    if check_status > /dev/null; then
        echo "HWE Kernel ya está instalado."
        
        # Check if kernel update is available
        if check_kernel_update_available; then
            echo "Actualización de kernel disponible. Actualizando..."
            
            # Update kernel packages
            sudo apt upgrade -y linux-generic-hwe* linux-headers-generic linux-firmware
            
            echo "Kernel actualizado exitosamente."
        else
            echo "Kernel está actualizado."
        fi
        return 0
    fi
    
    echo "HWE Kernel no encontrado. Instalando última versión..."
    
    # Get the latest available HWE kernel
    local latest_kernel=$(get_latest_hwe_kernel)
    echo "Instalando: $latest_kernel"
    
    # Install kernel packages
    sudo apt install -y --install-recommends "$latest_kernel"
    sudo apt install -y linux-firmware linux-headers-generic
    
    echo "Kernel & Headers instalado correctamente."
    echo "Es posible que necesites reiniciar para que el nuevo kernel surta efecto."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    echo "ADVERTENCIA: Desinstalar el kernel puede hacer que el sistema no arranque."
    echo "Este comando solo eliminará kernels HWE específicos, manteniendo el kernel base."
    
    # Remove HWE kernel packages
    sudo apt remove -y linux-generic-hwe* linux-headers-generic-hwe*
    sudo apt autoremove -y
    
    echo "Kernels HWE desinstalados correctamente."
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
