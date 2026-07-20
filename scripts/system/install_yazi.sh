#!/usr/bin/env bash
# install_yazi.sh
#
# Yazi — gestor de archivos de terminal (Rust). No está en los
# repositorios oficiales de Ubuntu; se instala vía el snap oficial del
# propio proyecto (yazi-rs.github.io/docs/installation), con
# confinamiento clásico. Usa el dispatcher compartido
# (scripts/lib/installer_cli.sh) y los helpers Snap
# (scripts/lib/snap.sh), mismo patrón que el grupo Snap del Hito 11.
#
# Semántica de los 6 verbos: idéntica al resto de los instaladores Snap
# (ver scripts/development/install_dbeaver.sh) — 'status' distingue
# snapd ausente (UNKNOWN) de "no instalado"; no distingue OUTDATED
# (requeriría consultar la store por red); 'repair' no se implementa (un
# snap no tiene el concepto de instalación parcial de un paquete APT).

set -Eeuo pipefail

UCI_YAZI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_YAZI_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_YAZI_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Yazi"
SNAP_PACKAGE="yazi"

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
