#!/usr/bin/env bash
# install_bitwarden.sh
#
# Instalador nuevo (Hito 44, ver docs/ROADMAP.md): agrega Bitwarden al
# catálogo (category=productivity, subcategory=security, mismo grupo que
# KeePassXC). Usa el dispatcher compartido y los helpers Snap compartidos
# (scripts/lib/snap.sh) — mismo mecanismo que Obsidian/Spotify.
#
# El snap `bitwarden` está publicado por la cuenta verificada "8bit
# Solutions LLC (bitwarden)" (el propio equipo de Bitwarden, confirmado
# en vivo vía `snap info bitwarden`) — fuente oficial. Confinamiento
# estricto (sin `--classic`, a diferencia de Obsidian/Bruno): la propia
# documentación oficial exige un paso adicional tras la instalación,
# conectar manualmente la interfaz `password-manager-service`
# (`snap connect bitwarden:password-manager-service`), sin la cual el
# almacenamiento seguro no funciona correctamente — se automatiza en
# `install_tool`. Licencia GPL-3.0 (confirmado en vivo vía `snap info`,
# no AGPL-3.0 como asumía el objetivo original de este Hito).

set -Eeuo pipefail

UCI_BITWARDEN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_BITWARDEN_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_BITWARDEN_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Bitwarden"
SNAP_PACKAGE="bitwarden"

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
    sudo snap connect "${SNAP_PACKAGE}:password-manager-service" || true
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
