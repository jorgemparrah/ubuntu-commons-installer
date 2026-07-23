#!/usr/bin/env bash
# install_krita.sh
#
# Instalador nuevo (Hito 35, ver docs/ROADMAP.md): agrega Krita al
# catálogo, mismo grupo que GIMP (category=multimedia,
# subcategory=graphics) — complementario, no reemplazo (Krita es
# pintura digital, GIMP es edición raster general). Usa el dispatcher
# compartido y los helpers Snap compartidos (scripts/lib/snap.sh), mismo
# mecanismo que GIMP.
#
# Snap oficial `krita`, publicado por la cuenta verificada de la Krita
# Foundation en Snap Store (confirmado `validation: verified` vía la API
# de Snapcraft), con una versión más actualizada que el paquete de
# Ubuntu (5.2.11 vs 5.2.2 en 24.04). A diferencia de GIMP, NO requiere
# `--classic` (confirmado en la documentación oficial de instalación).

set -Eeuo pipefail

UCI_KRITA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_KRITA_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_KRITA_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Krita"
SNAP_PACKAGE="krita"

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
