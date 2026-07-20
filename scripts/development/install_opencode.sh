#!/usr/bin/env bash
# install_opencode.sh
#
# OpenCode — CLI de codificación. Se instala vía el script oficial
# (curl -fsSL https://opencode.ai/install | bash), mismo mecanismo que
# Claude Code/Codex CLI/OpenClaw/Hermes Agent (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). Clasificación
# `required` confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail
TOOL_NAME="OpenCode"
UCI_OPENCODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_OPENCODE_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OPENCODE_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_OPENCODE_INSTALL_URL="https://opencode.ai/install"
UCI_OPENCODE_BIN="opencode"

check_status() {
    if curl_script_installed "${UCI_OPENCODE_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_OPENCODE_INSTALL_URL}" bash; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_OPENCODE_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
