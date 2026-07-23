#!/usr/bin/env bash
# install_pnpm.sh
#
# pnpm se instala vía Mise, igual mecanismo que Yarn (ver
# docs/adr/0017-mise-instala-yarn-pnpm-directo.md, que ya contemplaba
# pnpm sin haberlo implementado hasta el Hito 42). Usa
# scripts/lib/runtime.sh (Hito 8), el mismo mecanismo que kubectl/Yarn/gh.
#
# Mismos criterios que install_yarn.sh: 'reinstall' no define función
# propia (el fallback mecánico del dispatcher ya es exactamente lo que
# haría a mano); 'status' no distingue OUTDATED/BROKEN (Mise instala
# 'latest' en cada 'install', sin concepto de instalación parcial);
# 'update' vuelve a pedir 'latest' vía Mise.

set -Eeuo pipefail
TOOL_NAME="pnpm"
UCI_PNPM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_PNPM_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_PNPM_SCRIPT_DIR}/../lib/installer_cli.sh"

# Function to check status
check_status() {
    if runtime_mise_available "${HOME}" && "$(runtime_resolve_mise_bin "${HOME}")" which pnpm &> /dev/null; then
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

    if ! runtime_install "${HOME}" pnpm latest; then
        echo "No se pudo instalar pnpm vía Mise" >&2
        return 1
    fi

    if ! runtime_use_global "${HOME}" pnpm latest; then
        echo "No se pudo fijar pnpm como versión global de Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if runtime_mise_available "${HOME}"; then
        runtime_cmd "${HOME}" uninstall pnpm@latest || true
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."

    if ! runtime_install "${HOME}" pnpm latest; then
        echo "No se pudo actualizar pnpm vía Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
