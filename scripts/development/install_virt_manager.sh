#!/usr/bin/env bash
# install_virt_manager.sh
#
# Instalador nuevo (Hito 33, ver docs/ROADMAP.md): agrega virt-manager al
# catálogo, mismo grupo que VirtualBox (category=development,
# subcategory=virtualization). Front-end GTK para QEMU/KVM, libre (GPL),
# sin el Extension Pack propietario que restringe a VirtualBox. Usa el
# dispatcher compartido y los helpers APT (scripts/lib/apt.sh).
#
# Todos los paquetes están en los repositorios oficiales de Ubuntu (sin
# repo/PPA propio, a diferencia de VirtualBox): virt-manager, qemu-kvm,
# libvirt-daemon-system, libvirt-clients, bridge-utils. Se agrega también
# cpu-checker (paquete pequeño, provee 'kvm-ok') para advertir si el
# hardware no soporta virtualización (VT-x/AMD-V) — advertencia
# informativa, no bloquea la instalación: sin esas flags igual pueden
# correr VMs vía emulación de software (TCG), solo más lento.
#
# Mismo patrón que install_virtualbox.sh con el grupo `vboxusers`: agrega
# al usuario a los grupos `libvirt` y `kvm` (dos grupos, no uno) para usar
# virt-manager sin sudo. `systemctl` se guarda con 'command -v' (mismo
# criterio que install_ollama.sh): en un contenedor Docker sin systemd
# real, habilitar/iniciar el servicio 'libvirtd' no aplica.

set -Eeuo pipefail

UCI_VIRT_MANAGER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_VIRT_MANAGER_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_VIRT_MANAGER_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="virt-manager"
PACKAGE_NAME="virt-manager"
VIRT_MANAGER_PACKAGES=(virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker)

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v virt-manager &> /dev/null; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."
    apt_install_packages "${VIRT_MANAGER_PACKAGES[@]}"

    sudo groupadd libvirt 2>/dev/null || true
    sudo usermod -aG libvirt,kvm "$(id -un)"

    if command -v systemctl &> /dev/null; then
        sudo systemctl enable --now libvirtd 2>/dev/null || true
    fi

    echo "${TOOL_NAME} instalado correctamente. Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto."

    if command -v kvm-ok &> /dev/null && ! kvm-ok &> /dev/null; then
        echo "Advertencia: este equipo no parece soportar virtualización por hardware (VT-x/AMD-V, o está deshabilitada en el BIOS/UEFI) — las VMs igual pueden correr vía emulación de software, más lento." >&2
    fi
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${VIRT_MANAGER_PACKAGES[@]}"

    if groups | grep -qw libvirt; then
        sudo gpasswd -d "$(id -un)" libvirt
    fi
    if groups | grep -qw kvm; then
        sudo gpasswd -d "$(id -un)" kvm
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${VIRT_MANAGER_PACKAGES[@]}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${VIRT_MANAGER_PACKAGES[@]}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    sudo apt-get install --reinstall -y "${VIRT_MANAGER_PACKAGES[@]}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
