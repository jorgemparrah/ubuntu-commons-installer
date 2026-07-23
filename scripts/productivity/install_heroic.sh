#!/usr/bin/env bash
# install_heroic.sh
#
# Instalador nuevo (Hito 37, ver docs/ROADMAP.md): agrega Heroic Games
# Launcher al catálogo, mismo grupo que Steam/Lutris (category=productivity,
# subcategory=gaming). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh), los helpers de descarga directa de `.deb`
# (scripts/lib/deb_direct.sh) y el helper de GitHub Releases
# (scripts/lib/github_release.sh) — mismo mecanismo `deb-direct` que
# LocalSend/Hoppscotch/Beekeeper Studio/DbGate/Lutris.
#
# Launcher FOSS para Epic Games Store/GOG/Amazon Games (usa Legendary,
# gogdl, nile y comet como backends embebidos). Sin repo APT ni snap
# oficial confirmado; publica `.deb`, AppImage, `.rpm`, `.pacman` y
# `.tar.xz` en GitHub Releases — se usa el `.deb`
# (`Heroic-<version>-linux-amd64.deb`), verificado que los últimos 3
# releases lo incluyen de forma consistente (a diferencia de Hoppscotch,
# sin releases "solo-hotfix" que lo omitan). Paquete y binario: `heroic`
# (el `postinst` del `.deb` crea `/usr/bin/heroic` automáticamente,
# verificado inspeccionando el `.deb` real).

set -Eeuo pipefail

UCI_HEROIC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_HEROIC_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_HEROIC_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_HEROIC_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_HEROIC_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Heroic Games Launcher"
PACKAGE_NAME="heroic"
HEROIC_REPO="Heroic-Games-Launcher/HeroicGamesLauncher"
HEROIC_DEB_NAME="heroic.deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v heroic &> /dev/null; then
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

    local deb_url
    if ! deb_url="$(github_release_asset_url "${HEROIC_REPO}" 'Heroic-[^"]*-linux-amd64\.deb"')"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${HEROIC_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${HEROIC_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${HEROIC_DEB_NAME}"; then
        rm -f "${HEROIC_DEB_NAME}"
        return 1
    fi

    rm -f "${HEROIC_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a resolver la URL del
# último release y descarga de nuevo — es exactamente el comportamiento
# deseado.

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
