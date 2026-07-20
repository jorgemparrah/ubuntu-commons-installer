#!/usr/bin/env bash
# install_ubuntu_restricted_extras.sh
#
# Instalador individual del paquete "ubuntu-restricted-extras" (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md).
# Antes bandeado dentro del instalador multi-paquete de "Multimedia Tools".
# Usa el dispatcher y los helpers APT compartidos, mismo patrón que
# scripts/system/install_ranger.sh.

set -Eeuo pipefail

UCI_UBUNTU_RESTRICTED_EXTRAS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_UBUNTU_RESTRICTED_EXTRAS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_UBUNTU_RESTRICTED_EXTRAS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="ubuntu-restricted-extras"
PACKAGE_NAME="ubuntu-restricted-extras"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    # Paquete meta/de transición sin binario propio en PATH: no se intenta
    # detectar BROKEN vía 'command -v' (limitación honesta documentada en
    # ADR 0031, no una detección inventada).
    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
#
# ubuntu-restricted-extras pide aceptar el EULA de fuentes de Microsoft vía
# debconf; sin DEBIAN_FRONTEND=noninteractive, apt se queda esperando una
# respuesta interactiva que nunca llega en un flujo automatizado (mismo
# comportamiento que ya tenía el agrupador original de Multimedia Tools).
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "${PACKAGE_NAME}"
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
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
