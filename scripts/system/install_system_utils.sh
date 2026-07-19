#!/usr/bin/env bash
# install_system_utils.sh
#
# Agrupador delgado (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md):
# instala/desinstala/consulta el estado de los 3 instaladores individuales
# de "System Utilities" en secuencia. Existe para no romper setup.js, que
# sigue ofreciendo "System Utilities" como una sola opción de menú — cada
# paquete ya tiene su propio instalador migrado al contrato completo
# (install_meld.sh, install_baobab.sh, install_gparted.sh).
#
# No implementa update_tool/repair_tool a propósito: el dispatcher
# (scripts/lib/installer_cli.sh) rechaza esos verbos con código 3 —
# "actualizar/reparar el grupo" no tiene una semántica clara si solo un
# paquete del grupo lo necesita; usa el instalador individual del paquete
# afectado.

set -Eeuo pipefail

UCI_SYSTEM_UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SYSTEM_UTILS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="System Utilities (meld, baobab, gparted)"

UCI_SYSTEM_UTILS_MEMBERS=(
    "${UCI_SYSTEM_UTILS_SCRIPT_DIR}/install_meld.sh"
    "${UCI_SYSTEM_UTILS_SCRIPT_DIR}/install_baobab.sh"
    "${UCI_SYSTEM_UTILS_SCRIPT_DIR}/install_gparted.sh"
)

# Function to check status
check_status() {
    local member
    for member in "${UCI_SYSTEM_UTILS_MEMBERS[@]}"; do
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
    for member in "${UCI_SYSTEM_UTILS_MEMBERS[@]}"; do
        bash "${member}" install
    done
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    local member
    echo "Desinstalando ${TOOL_NAME}..."
    for member in "${UCI_SYSTEM_UTILS_MEMBERS[@]}"; do
        bash "${member}" uninstall
    done
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
