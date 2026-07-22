#!/usr/bin/env bash
# install_telegram_desktop.sh
#
# Instalador nuevo (Hito 25, ver docs/ROADMAP.md): agrega Telegram
# Desktop al catálogo. Usa el dispatcher compartido
# (scripts/lib/installer_cli.sh) y los helpers Snap compartidos
# (scripts/lib/snap.sh) — mismo mecanismo que Spotify/Zoom/GIMP.
#
# Telegram FZ-LLC (los desarrolladores oficiales) no publica un
# repositorio APT propio; el paquete `telegram-desktop` de los
# repositorios de Ubuntu suele quedar desactualizado. El snap oficial
# `telegram-desktop` (publicado por la cuenta verificada de Telegram
# FZ-LLC en Snap Store) es la única fuente mantenida directamente por el
# fabricante para Ubuntu — se usa ese, con confinamiento estricto normal
# (sin `--classic`, a diferencia de otros snaps de este catálogo como
# DBeaver/GitKraken/Postman/Insomnia/GIMP).

set -Eeuo pipefail

UCI_TELEGRAM_DESKTOP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_TELEGRAM_DESKTOP_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_TELEGRAM_DESKTOP_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Telegram Desktop"
SNAP_PACKAGE="telegram-desktop"

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
