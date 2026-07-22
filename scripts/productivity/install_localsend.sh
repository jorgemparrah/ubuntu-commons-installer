#!/usr/bin/env bash
# install_localsend.sh
#
# Instalador nuevo (Hito 29, ver docs/ROADMAP.md): agrega LocalSend al
# catálogo. Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh), los helpers de descarga directa de `.deb`
# (scripts/lib/deb_direct.sh) y el helper nuevo de GitHub Releases
# (scripts/lib/github_release.sh) — mecanismo `deb-direct`, con la URL
# del `.deb` resuelta dinámicamente contra el último release del repo
# oficial (localsend/localsend), que no publica un alias "latest"
# estable en el nombre del archivo (a diferencia de Discord).
#
# Existe un snap `localsend` en Snap Store, pero publicado por una cuenta
# sin verificar como oficial del proyecto — se prefiere el `.deb` del
# repositorio oficial de GitHub, fuente confirmada.

set -Eeuo pipefail

UCI_LOCALSEND_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_LOCALSEND_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_LOCALSEND_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_LOCALSEND_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_LOCALSEND_SCRIPT_DIR}/../lib/installer_cli.sh"

# Nombre de paquete asumido a partir del app id del proyecto
# (org.localsend.localsend_app) — no confirmado con una instalación real;
# a verificar en la validación manual de tests/manual/ (Hito 19).
TOOL_NAME="LocalSend"
PACKAGE_NAME="localsend_app"
LOCALSEND_REPO="localsend/localsend"
LOCALSEND_DEB_NAME="localsend.deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v localsend_app &> /dev/null; then
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
    if ! deb_url="$(github_release_asset_url "${LOCALSEND_REPO}" 'linux-x86-64\.deb"')"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${LOCALSEND_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${LOCALSEND_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${LOCALSEND_DEB_NAME}"; then
        rm -f "${LOCALSEND_DEB_NAME}"
        return 1
    fi

    rm -f "${LOCALSEND_DEB_NAME}"

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
# deseado (siempre la versión más reciente disponible).

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
