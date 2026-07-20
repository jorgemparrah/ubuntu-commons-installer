#!/usr/bin/env bash
# install_claude_code.sh
#
# Claude Code (Anthropic) — CLI de codificación. Se instala vía el script
# oficial (curl -fsSL https://claude.ai/install.sh | bash, sin depender de
# Node), mismo mecanismo que Codex CLI/OpenCode/OpenClaw/Hermes Agent (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). Clasificación
# `required` confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail
TOOL_NAME="Claude Code"
UCI_CLAUDE_CODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_CLAUDE_CODE_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CLAUDE_CODE_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_CLAUDE_CODE_INSTALL_URL="https://claude.ai/install.sh"
UCI_CLAUDE_CODE_BIN="claude"

check_status() {
    if curl_script_installed "${UCI_CLAUDE_CODE_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_CLAUDE_CODE_INSTALL_URL}" bash; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_CLAUDE_CODE_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
