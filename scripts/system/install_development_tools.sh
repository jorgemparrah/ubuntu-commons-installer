#!/usr/bin/env bash
# install_development_tools.sh
#
# Agrupador delgado (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md):
# instala/desinstala/consulta el estado de los 7 instaladores individuales
# de "Development Tools" en secuencia. Existe para no romper setup.js, que
# sigue ofreciendo "Development Tools" como una sola opción de menú — cada
# paquete ya tiene su propio instalador migrado al contrato completo
# (install_wget.sh, install_curl.sh, install_git.sh,
# install_build_essential.sh, install_software_properties_common.sh,
# install_apt_transport_https.sh, install_gnupg2.sh).
#
# No implementa update_tool/repair_tool a propósito: el dispatcher
# (scripts/lib/installer_cli.sh) rechaza esos verbos con código 3 —
# "actualizar/reparar el grupo" no tiene una semántica clara si solo un
# paquete del grupo lo necesita; usa el instalador individual del paquete
# afectado.

set -Eeuo pipefail

UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Development Tools (wget, curl, git, build-essential, software-properties-common, apt-transport-https, gnupg2)"

UCI_DEVELOPMENT_TOOLS_MEMBERS=(
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_wget.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_curl.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_git.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_build_essential.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_software_properties_common.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_apt_transport_https.sh"
    "${UCI_DEVELOPMENT_TOOLS_SCRIPT_DIR}/install_gnupg2.sh"
)

# Function to check status
# INSTALLED solo si TODOS los miembros reportan un estado que 'status'
# considera "instalado" (código 0: INSTALLED u OUTDATED); NOT_INSTALLED si
# falta o está roto cualquiera. Miembro por miembro, para que quien quiera
# el detalle fino corra el instalador individual directamente.
check_status() {
    local member
    for member in "${UCI_DEVELOPMENT_TOOLS_MEMBERS[@]}"; do
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
    for member in "${UCI_DEVELOPMENT_TOOLS_MEMBERS[@]}"; do
        bash "${member}" install
    done
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    local member
    echo "Desinstalando ${TOOL_NAME}..."
    for member in "${UCI_DEVELOPMENT_TOOLS_MEMBERS[@]}"; do
        bash "${member}" uninstall
    done
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
