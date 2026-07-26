#!/usr/bin/env bash
# install_helix.sh
#
# Instalador nuevo (Hito 49, ver docs/ROADMAP.md): agrega Helix al
# catálogo (category=editors, subcategory=terminal-editors, mismo grupo
# que Vim/Neovim). Usa el dispatcher compartido y los helpers Snap
# compartidos (scripts/lib/snap.sh) — mismo mecanismo que Obsidian/Bruno.
#
# El PPA histórico del proyecto (`ppa:maveonair/helix-editor`) tiene
# estado ambiguo (reportado como archivado/solo-lectura en discusiones
# recientes de la comunidad, aunque el paquete sigue publicado en
# Launchpad para `noble`), y la documentación oficial de Helix
# (docs.helix-editor.com/package-managers.html, confirmado en vivo) lista
# el snap como alternativa explícita para Linux, con el flag `--classic`
# (`snap install --classic helix`) — se prioriza esta fuente,
# consistente con priorizar mecanismos oficiales sin ambigüedad de
# mantenimiento futuro.

set -Eeuo pipefail

UCI_HELIX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_HELIX_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_HELIX_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Helix"
SNAP_PACKAGE="helix"

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
