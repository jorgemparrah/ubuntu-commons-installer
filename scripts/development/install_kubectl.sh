#!/usr/bin/env bash
# install_kubectl.sh
#
# kubectl se gestiona vía Mise, no vía Snap (ver
# docs/adr/0018-kubectl-via-mise.md). Usa scripts/lib/runtime.sh, el mismo
# mecanismo del Hito 8 (Gestor de runtimes) que ya gestiona Node y Python.
#
# Migrado en el Hito 11 (grupo Mise) solo en el dispatcher: adopta
# scripts/lib/installer_cli.sh en vez de su propio bloque main()/case, sin
# tocar la lógica de scripts/lib/runtime.sh.
#
# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) ya era exactamente lo que
# este script hacía a mano.
#
# 'status' no distingue OUTDATED/BROKEN: Mise instala 'latest' en cada
# 'install', y una instalación de Mise no tiene el concepto de "instalación
# parcial" que justifica BROKEN en un paquete APT — limitación honesta, no
# una detección inventada. 'update' vuelve a pedir la versión 'latest' vía
# Mise (que resuelve a la más nueva disponible en ese momento).

set -Eeuo pipefail
TOOL_NAME="kubectl"
UCI_KUBECTL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_KUBECTL_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_KUBECTL_SCRIPT_DIR}/../lib/installer_cli.sh"

# Function to check status
check_status() {
    if runtime_mise_available "${HOME}" && "$(runtime_resolve_mise_bin "${HOME}")" which kubectl &> /dev/null; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."

    if ! runtime_ensure_mise "${HOME}"; then
        echo "No se pudo instalar Mise" >&2
        return 1
    fi

    if ! runtime_install "${HOME}" kubectl latest; then
        echo "No se pudo instalar kubectl vía Mise" >&2
        return 1
    fi

    if ! runtime_use_global "${HOME}" kubectl latest; then
        echo "No se pudo fijar kubectl como versión global de Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if runtime_mise_available "${HOME}"; then
        runtime_cmd "${HOME}" uninstall kubectl@latest || true
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."

    if ! runtime_install "${HOME}" kubectl latest; then
        echo "No se pudo actualizar kubectl vía Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
