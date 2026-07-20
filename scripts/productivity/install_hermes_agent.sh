#!/usr/bin/env bash
# install_hermes_agent.sh
#
# Hermes Agent (NousResearch) — agente de propósito general con memoria
# persistente (no específico de código, ver
# docs/adr/0036-candidatas-de-ia-en-categorias-existentes.md). Se instala
# vía el script oficial (curl -fsSL
# https://hermes-agent.nousresearch.com/install.sh | bash), mismo
# mecanismo que las CLIs del Hito 16 (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). El instalador
# oficial bundlea uv/Python 3.11/Node.js/ripgrep/ffmpeg/Git portable —
# este instalador no rastrea ni remueve esas dependencias por separado,
# quedan dentro del alcance del propio script oficial. Clasificación
# `optional` confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail
TOOL_NAME="Hermes Agent"
UCI_HERMES_AGENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_HERMES_AGENT_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_HERMES_AGENT_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_HERMES_AGENT_INSTALL_URL="https://hermes-agent.nousresearch.com/install.sh"
UCI_HERMES_AGENT_BIN="hermes"

check_status() {
    if curl_script_installed "${UCI_HERMES_AGENT_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_HERMES_AGENT_INSTALL_URL}" bash; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_HERMES_AGENT_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
