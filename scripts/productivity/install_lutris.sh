#!/usr/bin/env bash
# install_lutris.sh
#
# Instalador nuevo (Hito 37, ver docs/ROADMAP.md): agrega Lutris al
# catálogo, mismo grupo que Steam (category=productivity,
# subcategory=gaming). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh), los helpers de descarga directa de `.deb`
# (scripts/lib/deb_direct.sh) y el helper de GitHub Releases
# (scripts/lib/github_release.sh) — mecanismo `deb-direct`, mismo
# criterio que LocalSend/Hoppscotch/Beekeeper Studio/DbGate.
#
# El paquete `lutris` de los repositorios oficiales de Ubuntu (en
# `multiverse`, no `universe`) queda desactualizado (0.5.14-2 en 24.04
# frente a v0.5.22 en GitHub). Existe un PPA oficial del propio equipo
# (`ppa:lutris-team/lutris`, mantenido por Mathieu Comandon, el lead del
# proyecto), pero la propia documentación oficial de lutris.net recomienda
# en su lugar el `.deb` publicado en GitHub Releases — mismo mecanismo que
# ya usa este proyecto para casos similares, así que se prefiere sobre el
# PPA. El asset se llama `lutris_<version>_all.deb` (arquitectura
# independiente: es una app Python/GTK, las dependencias nativas las
# resuelve `apt`). El binario queda en `/usr/games/lutris` (confirmado
# inspeccionando el `.deb` real) — ruta ya incluida en el PATH por
# defecto de Ubuntu, sin necesitar ningún ajuste especial.

set -Eeuo pipefail

UCI_LUTRIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_LUTRIS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_LUTRIS_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_LUTRIS_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_LUTRIS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Lutris"
PACKAGE_NAME="lutris"
LUTRIS_REPO="lutris/lutris"
LUTRIS_DEB_NAME="lutris.deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v lutris &> /dev/null; then
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
    if ! deb_url="$(github_release_asset_url "${LUTRIS_REPO}" 'lutris_[^"]*_all\.deb"')"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${LUTRIS_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${LUTRIS_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${LUTRIS_DEB_NAME}"; then
        rm -f "${LUTRIS_DEB_NAME}"
        return 1
    fi

    rm -f "${LUTRIS_DEB_NAME}"

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
