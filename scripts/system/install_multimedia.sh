#!/usr/bin/env bash
# install_multimedia.sh
#
# Agrupador delgado (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md):
# instala/desinstala/consulta el estado de los 4 instaladores individuales
# de "Multimedia Tools" en secuencia. Existe para no romper setup.js, que
# sigue ofreciendo "Multimedia Tools" como una sola opción de menú — cada
# paquete ya tiene su propio instalador migrado al contrato completo
# (install_cheese.sh, install_v4l_utils.sh,
# install_ubuntu_restricted_extras.sh, install_vlc.sh; este último es el
# único de los 4 que pide DEBIAN_FRONTEND=noninteractive, por su EULA de
# fuentes de Microsoft).
#
# No implementa update_tool/repair_tool a propósito: el dispatcher
# (scripts/lib/installer_cli.sh) rechaza esos verbos con código 3 —
# "actualizar/reparar el grupo" no tiene una semántica clara si solo un
# paquete del grupo lo necesita; usa el instalador individual del paquete
# afectado.

set -Eeuo pipefail

UCI_MULTIMEDIA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_MULTIMEDIA_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Multimedia Tools (cheese, v4l-utils, ubuntu-restricted-extras, vlc)"

UCI_MULTIMEDIA_MEMBERS=(
    "${UCI_MULTIMEDIA_SCRIPT_DIR}/install_cheese.sh"
    "${UCI_MULTIMEDIA_SCRIPT_DIR}/install_v4l_utils.sh"
    "${UCI_MULTIMEDIA_SCRIPT_DIR}/install_ubuntu_restricted_extras.sh"
    "${UCI_MULTIMEDIA_SCRIPT_DIR}/install_vlc.sh"
)

# Function to check status
check_status() {
    local member
    for member in "${UCI_MULTIMEDIA_MEMBERS[@]}"; do
        if ! bash "${member}" status > /dev/null 2>&1; then
            echo "NOT_INSTALLED"
            return 1
        fi
    done
    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    local member
    echo "Instalando ${TOOL_NAME}..."
    for member in "${UCI_MULTIMEDIA_MEMBERS[@]}"; do
        bash "${member}" install
    done
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    local member
    echo "Desinstalando ${TOOL_NAME}..."
    for member in "${UCI_MULTIMEDIA_MEMBERS[@]}"; do
        bash "${member}" uninstall
    done
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
