#!/usr/bin/env bash
# install_beekeeper_studio.sh
#
# Instalador nuevo (Hito 32, ver docs/ROADMAP.md): agrega Beekeeper
# Studio al catálogo, mismo grupo que DBeaver/MongoDB Compass
# (category=development, subcategory=db-clients). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh), los helpers de
# descarga directa de `.deb` (scripts/lib/deb_direct.sh) y el helper de
# GitHub Releases (scripts/lib/github_release.sh) — mismo mecanismo
# `deb-direct` que LocalSend/Hoppscotch.
#
# El propio `.deb` oficial (inspeccionado con dpkg-deb) sugiere
# fuertemente que existe un repositorio APT propio (su `postinst`
# migra `/etc/apt/sources.list.d/beekeeper-studio.list` a
# `beekeeper-studio-app.list` y embebe una clave GPG pública vía
# `apt-key`), pero no se pudo verificar la URL/línea de repo exacta en
# este entorno (restricción de red del sandbox de desarrollo) — se usa
# `deb-direct` con resolución dinámica en su lugar, confirmado
# funcionando contra el release real. Candidato a migrar a
# `apt-vendor-repo` en una ronda futura si se confirma el mecanismo
# exacto del repo oficial.
#
# El `postinst` del `.deb` crea automáticamente el symlink
# `/usr/bin/beekeeper-studio -> /opt/Beekeeper Studio/beekeeper-studio`
# si no existe, así que `command -v beekeeper-studio` funciona normal
# tras una instalación real (verificado inspeccionando el `.deb`).
#
# Licencia GPL-3.0 en el núcleo; la edición "Ultimate" es un addon de
# pago opcional que no bloquea el uso básico (conectar/consultar bases
# de datos SQL comunes).

set -Eeuo pipefail

UCI_BEEKEEPER_STUDIO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_BEEKEEPER_STUDIO_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_BEEKEEPER_STUDIO_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_BEEKEEPER_STUDIO_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_BEEKEEPER_STUDIO_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Beekeeper Studio"
PACKAGE_NAME="beekeeper-studio"
BEEKEEPER_STUDIO_REPO="beekeeper-studio/beekeeper-studio"
BEEKEEPER_STUDIO_DEB_NAME="beekeeper-studio.deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v beekeeper-studio &> /dev/null; then
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
    if ! deb_url="$(github_release_asset_url "${BEEKEEPER_STUDIO_REPO}" 'beekeeper-studio_[^"]*_amd64\.deb"')"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${BEEKEEPER_STUDIO_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${BEEKEEPER_STUDIO_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${BEEKEEPER_STUDIO_DEB_NAME}"; then
        rm -f "${BEEKEEPER_STUDIO_DEB_NAME}"
        return 1
    fi

    rm -f "${BEEKEEPER_STUDIO_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a resolver la URL
# del último release y descarga de nuevo — es exactamente el
# comportamiento deseado.

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
