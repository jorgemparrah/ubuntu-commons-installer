#!/usr/bin/env bash
# install_bruno.sh
#
# Instalador nuevo (Hito 31, ver docs/ROADMAP.md): agrega Bruno al
# catálogo, mismo grupo que Postman/Insomnia/SoapUI
# (category=development, subcategory=api-clients). Usa el dispatcher
# compartido y los helpers Snap compartidos (scripts/lib/snap.sh) — mismo
# mecanismo que Spotify/DBeaver/GitKraken.
#
# El snap `bruno` está publicado por `helloanoop` (Anoop M D, el propio
# creador/fundador de Bruno), sincronizado con el último release de
# GitHub del proyecto — fuente confiable aunque la cuenta de Snap Store
# no tenga verificación formal de "publisher". Requiere `--classic`
# (acceso amplio al sistema de archivos, necesario para abrir
# "colecciones" git-native en cualquier ubicación del home — mismo
# criterio que Obsidian con sus "vaults").
#
# Licencia: MIT en el núcleo. "Bruno Cloud" es un servicio opcional de
# sincronización/colaboración de pago — el uso local (requests,
# colecciones, sync vía git) es 100% funcional sin él.

set -Eeuo pipefail

UCI_BRUNO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_BRUNO_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_BRUNO_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Bruno"
SNAP_PACKAGE="bruno"

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
