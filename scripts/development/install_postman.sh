#!/usr/bin/env bash
# install_postman.sh
#
# Instalador migrado en el Hito 11 (grupo Snap) al contrato completo de 6
# verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh) y los helpers Snap
# compartidos (scripts/lib/snap.sh, hermano de scripts/lib/apt.sh para
# este mecanismo).
#
# 'status' distingue snapd ausente/no disponible (UNKNOWN) de "no
# instalado" (NOT_INSTALLED) — ver docs/UBUNTU_COMPATIBILITY.md. No
# verificable automáticamente en Docker (snapd no corre sin systemd).
#
# 'status' no distingue OUTDATED: eso requeriría 'snap refresh --list',
# que consulta la store de Snap por red — 'status' debe seguir siendo
# liviano y de solo lectura local (ver docs/ARCHITECTURE.md §21, mismo
# criterio que ADR 0031 para los paquetes meta de APT). 'update' sigue
# existiendo como verbo explícito. 'repair' no se implementa: un snap es
# una imagen squashfs autocontenida, sin el concepto de "instalación
# parcial" que justifica 'repair' en paquetes APT — el dispatcher lo
# rechaza explícitamente (código 3) si se pide.

set -Eeuo pipefail

UCI_POSTMAN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_POSTMAN_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_POSTMAN_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Postman"
SNAP_PACKAGE="postman"

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
