#!/usr/bin/env bash
# install_dust.sh
#
# Instalador nuevo (Hito 39, ver docs/ROADMAP.md): agrega dust al
# catálogo, mismo grupo que fzf/thefuck/jq/yq/HTTPie/xh/duf/btop/zoxide/
# tealdeer (category=system, subcategory=cli-utils). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh), los helpers de
# descarga directa de `.deb` (scripts/lib/deb_direct.sh) y el helper de
# GitHub Releases (scripts/lib/github_release.sh) — mismo mecanismo
# `deb-direct` que LocalSend/Hoppscotch/Lutris/Heroic.
#
# dust NO está en los repositorios oficiales de Ubuntu, pero SÍ publica
# un `.deb` propio en GitHub Releases (`du-dust_<version>-1_amd64.deb`,
# confirmado en vivo). El paquete se llama `du-dust` (para no chocar con
# el paquete `dust` de Debian/Ubuntu, un juego infantil sin relación) pero
# el binario que instala es `dust` (confirmado inspeccionando el `.deb`
# real) — no confundir nombre de paquete con nombre de binario.

set -Eeuo pipefail

UCI_DUST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_DUST_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_DUST_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_DUST_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_DUST_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="dust"
PACKAGE_NAME="du-dust"
DUST_REPO="bootandy/dust"
DUST_DEB_NAME="dust.deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v dust &> /dev/null; then
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
    if ! deb_url="$(github_release_asset_url "${DUST_REPO}" 'du-dust_[^"]*_amd64\.deb"')"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${DUST_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${DUST_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${DUST_DEB_NAME}"; then
        rm -f "${DUST_DEB_NAME}"
        return 1
    fi

    rm -f "${DUST_DEB_NAME}"

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
