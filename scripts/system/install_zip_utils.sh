#!/usr/bin/env bash
# install_zip_utils.sh
#
# Instalador nuevo (Hito 45, ver docs/ROADMAP.md): agrega `unzip`/`zip`
# al catálogo como un único instalador (category=system,
# subcategory=cli-utils), mismo criterio de agrupar paquetes
# estrechamente relacionados en un solo instalador que
# install_virt_manager.sh. Ambos paquetes son utilidades de compresión
# estándar de los repositorios oficiales de Ubuntu, cada uno con su
# propio binario homónimo (`unzip`, `zip`) — sin ninguna particularidad.
# `unzip` se usa como paquete de referencia para `status`/`update`.

set -Eeuo pipefail

UCI_ZIP_UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ZIP_UTILS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ZIP_UTILS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="unzip/zip"
PACKAGE_NAME="unzip"
ZIP_UTILS_PACKAGES=(unzip zip)

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v unzip &> /dev/null || ! command -v zip &> /dev/null; then
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
    apt_install_packages "${ZIP_UTILS_PACKAGES[@]}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${ZIP_UTILS_PACKAGES[@]}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${ZIP_UTILS_PACKAGES[@]}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${ZIP_UTILS_PACKAGES[@]}"
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
    sudo apt-get install --reinstall -y "${ZIP_UTILS_PACKAGES[@]}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
