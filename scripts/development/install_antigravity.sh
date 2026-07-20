#!/usr/bin/env bash
# install_antigravity.sh
#
# Antigravity (Google) — CLI 'agy' únicamente. Se instala vía el script
# oficial (curl -fsSL https://antigravity.google/cli/install.sh | bash),
# mismo mecanismo que Claude Code/Codex CLI/OpenCode (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). El IDE/Desktop
# de Antigravity queda explícitamente fuera de este instalador: no tiene
# apt/snap oficial, solo un tarball manual sin checksum/firma descripta,
# lo que no cumple el estándar de seguridad del proyecto (AGENT.md §16) —
# se retoma cuando exista un mecanismo verificable. Clasificación
# `optional` confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail
TOOL_NAME="Antigravity CLI"
UCI_ANTIGRAVITY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_ANTIGRAVITY_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ANTIGRAVITY_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_ANTIGRAVITY_INSTALL_URL="https://antigravity.google/cli/install.sh"
UCI_ANTIGRAVITY_BIN="agy"

check_status() {
    if curl_script_installed "${UCI_ANTIGRAVITY_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_ANTIGRAVITY_INSTALL_URL}" bash; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_ANTIGRAVITY_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
