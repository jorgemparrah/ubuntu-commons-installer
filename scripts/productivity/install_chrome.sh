#!/usr/bin/env bash
# install_chrome.sh
#
# Instalador migrado en el Hito 11 (grupo deb-directo) al contrato
# completo de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de descarga directa de `.deb`
# (scripts/lib/deb_direct.sh, nuevos en esta migración).
#
# El `.deb` oficial de Chrome descargado aquí está fijado a amd64 (ver
# ADR 0028: arquitectura oficialmente soportada). Google no publica un
# `.deb` directo para arm64 — no se inventa esa descarga; en
# arquitecturas no soportadas se rechaza con `UNSUPPORTED`, nunca en
# silencio.

set -Eeuo pipefail

UCI_CHROME_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_CHROME_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_CHROME_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CHROME_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Google Chrome"
PACKAGE_NAME="google-chrome-stable"
CHROME_SUPPORTED_ARCH="amd64"
CHROME_DEB_NAME="google-chrome-stable_current_amd64.deb"
CHROME_DEB_URL="https://dl.google.com/linux/direct/${CHROME_DEB_NAME}"

# check_architecture_supported
# exit 0 si la arquitectura real de la máquina es la soportada (amd64);
# exit 1 en cualquier otra (ver ADR 0028).
check_architecture_supported() {
    local machine_arch
    machine_arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    [[ "${machine_arch}" == "${CHROME_SUPPORTED_ARCH}" ]]
}

# Function to check status
check_status() {
    if ! check_architecture_supported; then
        echo "UNSUPPORTED"
        return 1
    fi

    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v google-chrome &> /dev/null; then
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
    if ! check_architecture_supported; then
        local machine_arch
        machine_arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
        echo "${TOOL_NAME} (paquete .deb directo) solo se soporta en '${CHROME_SUPPORTED_ARCH}'; esta máquina es '${machine_arch}' (ver ADR 0028)." >&2
        echo "No se instalará un paquete incompatible." >&2
        return 1
    fi

    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    echo "Descargando ${TOOL_NAME}..."
    if ! deb_direct_download "${CHROME_DEB_URL}" "${CHROME_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${CHROME_DEB_NAME}"; then
        rm -f "${CHROME_DEB_NAME}"
        return 1
    fi

    rm -f "${CHROME_DEB_NAME}"

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
