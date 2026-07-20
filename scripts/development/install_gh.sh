#!/usr/bin/env bash
# install_gh.sh
#
# gh (GitHub CLI) se instala vía Mise, no vía apt, aunque también está en
# el repositorio oficial de Ubuntu (universe, 24.04 y 26.04) — decisión
# explícita del dueño del proyecto que amplía el rol de Mise más allá de
# runtimes (ver docs/adr/0033-mise-amplia-su-rol-a-clis-via-registry.md y
# docs/adr/0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md). Usa
# scripts/lib/runtime.sh (Hito 8), el mismo mecanismo que kubectl/Yarn —
# se registra en tools_catalog.sh con manager=mise, igual que esos dos,
# no con un valor distinto: es exactamente el mismo caso (CLI sin
# política de versiones propia, instala 'latest').
#
# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) alcanza, mismo criterio que
# kubectl/Yarn.
#
# 'status' no distingue OUTDATED/BROKEN ni 'repair' está implementado:
# misma limitación honesta que kubectl/Yarn (Mise no tiene el concepto de
# instalación parcial que lo justifique).

set -Eeuo pipefail
TOOL_NAME="GitHub CLI"
UCI_GH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_GH_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_GH_SCRIPT_DIR}/../lib/installer_cli.sh"

# Function to check status
check_status() {
    if runtime_mise_available "${HOME}" && "$(runtime_resolve_mise_bin "${HOME}")" which gh &> /dev/null; then
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

    if ! runtime_install "${HOME}" gh latest; then
        echo "No se pudo instalar gh vía Mise" >&2
        return 1
    fi

    if ! runtime_use_global "${HOME}" gh latest; then
        echo "No se pudo fijar gh como versión global de Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if runtime_mise_available "${HOME}"; then
        runtime_cmd "${HOME}" uninstall gh@latest || true
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."

    if ! runtime_install "${HOME}" gh latest; then
        echo "No se pudo actualizar gh vía Mise" >&2
        return 1
    fi

    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
