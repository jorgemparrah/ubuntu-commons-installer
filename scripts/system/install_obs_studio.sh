#!/usr/bin/env bash
# install_obs_studio.sh
#
# Migrado de Snap a su PPA oficial (ppa:obsproject/obs-studio, ver
# docs/adr/0038-obs-studio-migra-de-snap-a-ppa-oficial.md): el snap de OBS
# Studio está etiquetado "unofficial" por el propio OBS Project, que
# recomienda su PPA (o Flatpak) como los únicos builds Linux oficiales.
# Mismo mecanismo que install_ulauncher.sh (el único otro instalador del
# catálogo que agrega un PPA vía add-apt-repository en vez de un
# repositorio con keyring manual): manager=apt-vendor-repo.
#
# Ya no depende de snapd (ausente en los contenedores Docker de CI):
# requires_manual_validation pasa a 'no' en tools_catalog.sh.
#
# El binario real se llama 'obs', no 'obs-studio' (ese es el nombre del
# paquete apt).

set -Eeuo pipefail

UCI_OBS_STUDIO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_OBS_STUDIO_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OBS_STUDIO_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="OBS Studio"
PACKAGE_NAME="obs-studio"
UCI_OBS_STUDIO_PPA="ppa:obsproject/obs-studio"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v obs &> /dev/null; then
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

    if ! command -v add-apt-repository &> /dev/null; then
        apt_install_packages "software-properties-common"
    fi

    sudo add-apt-repository -y universe
    sudo add-apt-repository -y "${UCI_OBS_STUDIO_PPA}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo add-apt-repository -y --remove "${UCI_OBS_STUDIO_PPA}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
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
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
