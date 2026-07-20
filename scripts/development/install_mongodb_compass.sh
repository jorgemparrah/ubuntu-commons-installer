#!/usr/bin/env bash
# install_mongodb_compass.sh
#
# Instalador migrado en el Hito 11 (grupo deb-directo) al contrato
# completo de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de descarga directa de `.deb`
# (scripts/lib/deb_direct.sh, nuevos en esta migración).
#
# Riesgo conocido y aceptado (ver docs/UBUNTU_COMPATIBILITY.md): la URL de
# descarga fija una versión y arquitectura exactas
# (mongodb-compass_1.46.8_amd64.deb). MongoDB no publica un alias estable
# tipo "latest" para Compass, así que resolver la versión dinámicamente
# requeriría además scrapear su centro de descargas — fuera de alcance de
# este hito.

set -Eeuo pipefail

UCI_MONGODB_COMPASS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_MONGODB_COMPASS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_MONGODB_COMPASS_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_MONGODB_COMPASS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="MongoDB Compass"
PACKAGE_NAME="mongodb-compass"
MONGODB_COMPASS_DEB_NAME="mongodb-compass_1.46.8_amd64.deb"
MONGODB_COMPASS_DEB_URL="https://downloads.mongodb.com/compass/${MONGODB_COMPASS_DEB_NAME}"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v mongodb-compass &> /dev/null; then
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

    echo "Descargando ${TOOL_NAME}..."
    if ! deb_direct_download "${MONGODB_COMPASS_DEB_URL}" "${MONGODB_COMPASS_DEB_NAME}"; then
        echo "La versión fijada (1.46.8) podría ya no estar publicada; revisar https://www.mongodb.com/try/download/compass" >&2
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${MONGODB_COMPASS_DEB_NAME}"; then
        rm -f "${MONGODB_COMPASS_DEB_NAME}"
        return 1
    fi

    rm -f "${MONGODB_COMPASS_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) ya era exactamente lo que
# este script hacía a mano — descargar de nuevo el .deb es más simple que
# intentar un 'apt-get install --reinstall' sin el archivo a mano.

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
