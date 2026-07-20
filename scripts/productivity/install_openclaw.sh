#!/usr/bin/env bash
# install_openclaw.sh
#
# OpenClaw — agente de terminal de propósito general (no específico de
# código, ver docs/adr/0036-candidatas-de-ia-en-categorias-existentes.md).
# Se instala vía el script oficial (curl -fsSL
# https://openclaw.ai/install.sh | bash), mismo mecanismo que las CLIs de
# codificación del Hito 16 (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). Requiere
# Node.js 22.22.3+/24.15+/25.9+; este instalador no lo gestiona por su
# cuenta — si Node no está disponible, el script oficial de OpenClaw es
# responsable de fallar con su propio mensaje. Clasificación `optional`
# confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail
TOOL_NAME="OpenClaw"
UCI_OPENCLAW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_OPENCLAW_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OPENCLAW_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_OPENCLAW_INSTALL_URL="https://openclaw.ai/install.sh"
UCI_OPENCLAW_BIN="openclaw"

check_status() {
    if curl_script_installed "${UCI_OPENCLAW_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_OPENCLAW_INSTALL_URL}" bash; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_OPENCLAW_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
