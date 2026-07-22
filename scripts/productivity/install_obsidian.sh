#!/usr/bin/env bash
# install_obsidian.sh
#
# Instalador nuevo (Hito 26, ver docs/ROADMAP.md): agrega Obsidian al
# catálogo. Usa el dispatcher compartido y los helpers Snap compartidos
# (scripts/lib/snap.sh) — mismo mecanismo que Spotify/DBeaver/GitKraken.
#
# El snap `obsidian` está publicado por la cuenta verificada `obsidianmd`
# (el propio equipo de Obsidian) en Snap Store — fuente oficial.
# Requiere `--classic` (acceso amplio al sistema de archivos, necesario
# para abrir "vaults" en cualquier ubicación del home).

set -Eeuo pipefail

UCI_OBSIDIAN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_OBSIDIAN_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OBSIDIAN_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Obsidian"
SNAP_PACKAGE="obsidian"

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
    snap_install_package "${SNAP_PACKAGE}" --classic
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
