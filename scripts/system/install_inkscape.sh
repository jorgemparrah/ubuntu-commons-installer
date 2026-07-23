#!/usr/bin/env bash
# install_inkscape.sh
#
# Instalador nuevo (Hito 35, ver docs/ROADMAP.md): agrega Inkscape al
# catálogo, mismo grupo que GIMP (category=multimedia,
# subcategory=graphics) — complementario, no reemplazo (Inkscape es
# vectorial, GIMP es raster). Usa el dispatcher y los helpers APT
# compartidos, mismo patrón PPA que install_keepassxc.sh/install_ulauncher.sh.
#
# El propio equipo de Inkscape ("Inkscape Developers") mantiene un PPA
# oficial (ppa:inkscape.dev/stable, confirmado activo en Launchpad) — se
# prioriza sobre el paquete de los repositorios oficiales de Ubuntu, que
# queda 2 versiones mayores atrás (1.2.2 en 24.04 vs 1.4.x upstream).

set -Eeuo pipefail

UCI_INKSCAPE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_INKSCAPE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_INKSCAPE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Inkscape"
PACKAGE_NAME="inkscape"
UCI_INKSCAPE_PPA="ppa:inkscape.dev/stable"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v inkscape &> /dev/null; then
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

    sudo add-apt-repository -y "${UCI_INKSCAPE_PPA}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo add-apt-repository -y --remove "${UCI_INKSCAPE_PPA}"
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
