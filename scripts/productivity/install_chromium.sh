#!/usr/bin/env bash
# install_chromium.sh
#
# Instalador nuevo (Hito 27, ver docs/ROADMAP.md): agrega el navegador
# Chromium al catálogo. Usa el dispatcher compartido y los helpers Snap
# compartidos (scripts/lib/snap.sh) — mismo mecanismo que Spotify/GIMP.
#
# En Ubuntu 24.04+ el paquete `chromium-browser` de los repositorios
# oficiales es un paquete transicional vacío que en la práctica instala
# el snap — no un `.deb` real. El snap `chromium` está publicado por
# Canonical (cuenta verificada), sin `--classic`.

set -Eeuo pipefail

UCI_CHROMIUM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_CHROMIUM_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CHROMIUM_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Chromium"
SNAP_PACKAGE="chromium"

# Function to check status
check_status() {
    if ! snap_available; then
        echo "UNKNOWN"
        return 1
    fi

    if snap_package_installed "${SNAP_PACKAGE}"; then
        echo "INSTALLED"
        return 0
    fi

    echo "NOT_INSTALLED"
    return 1
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    snap_install_package "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    snap_remove_package "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo snap refresh "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
