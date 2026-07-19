#!/usr/bin/env bash
# install_kernel.sh
#
# ALTO RIESGO: modifica el kernel de arranque del host. Nunca se prueba
# instalando de verdad (ni en Docker ni en CI) — solo la lógica de
# resolución de nombres de paquete se prueba de forma unitaria/simulada
# (ver tests/test_kernel_hwe_fallback.sh). La instalación real requiere
# validación manual en una VM o máquina de prueba dedicada, nunca en la
# máquina de desarrollo ni en un contenedor compartido.

set -Eeuo pipefail
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

# resolve_hwe_fallback_package_name <ubuntu_release_version>
# Construye el nombre del paquete HWE de fallback a partir de la VERSIÓN
# NUMÉRICA de Ubuntu (ej. "24.04"), nunca el codename (ej. "noble") — el
# paquete real se llama linux-generic-hwe-24.04, no linux-generic-hwe-noble.
# Bug real encontrado en la auditoría de docs/UBUNTU_COMPATIBILITY.md:
# antes se usaba 'lsb_release -cs' (codename) para este fallback, generando
# un nombre de paquete que nunca existe. Extraída como función pura (sin
# I/O) para poder probarla sin instalar nada.
resolve_hwe_fallback_package_name() {
    local ubuntu_release_version="$1"
    echo "linux-generic-hwe-${ubuntu_release_version}"
}

# Function to get the latest available HWE kernel
get_latest_hwe_kernel() {
    # Update package list to get latest available kernels
    sudo apt update

    # Find the latest HWE kernel available
    local latest_kernel
    latest_kernel="$(apt list --upgradable 2>/dev/null | grep "linux-generic-hwe" | tail -1 | cut -d'/' -f1)"

    if [[ -n "$latest_kernel" ]]; then
        echo "$latest_kernel"
    else
        # Fallback a la versión numérica de Ubuntu (lsb_release -rs), NUNCA
        # el codename (lsb_release -cs) — ver resolve_hwe_fallback_package_name.
        local ubuntu_release_version
        ubuntu_release_version="$(lsb_release -rs)"
        resolve_hwe_fallback_package_name "${ubuntu_release_version}"
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
    #
    # 'local var=$(cmd)' enmascara el código de salida de cmd bajo el
    # nuevo modo estricto (set -e no vería un fallo de get_latest_hwe_kernel,
    # porque el propio 'local' siempre sale 0) — se separa en dos líneas.
    local latest_kernel
    latest_kernel="$(get_latest_hwe_kernel)"
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

# Permite sourcear este archivo desde una prueba (para llamar directamente
# a resolve_hwe_fallback_package_name) sin disparar main(), que de otro
# modo terminaría el proceso que lo sourcea con 'exit 1' si no recibe un
# subcomando válido.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
