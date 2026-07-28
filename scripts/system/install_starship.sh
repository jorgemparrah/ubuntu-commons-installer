#!/usr/bin/env bash
# install_starship.sh
#
# Instalador nuevo (Hito 49, ver docs/ROADMAP.md): agrega Starship al
# catálogo (category=system, subcategory=shell-personalization, mismo
# grupo que Oh My Zsh/Powerlevel10k). Usa el dispatcher compartido y los
# helpers curl-script (scripts/lib/curl_script.sh) — mismo mecanismo que
# Claude Code/Codex CLI/OpenCode (ver ADR 0037).
#
# Script oficial de instalación confirmado en vivo (`curl -sI
# https://starship.rs/install.sh` → 200, `content-type:
# application/x-sh`). Prompt de shell multi-shell (bash/zsh/fish/nu),
# ISC License. Requiere una Nerd Font instalada para renderizar sus
# íconos/símbolos por defecto correctamente — ese requisito se gestiona
# como configuración post-instalación en un Hito futuro (ver docs/ROADMAP.md,
# mismo patrón que Powerlevel10k/Flameshot vía `configure_tool()`), no en
# este instalador.

set -Eeuo pipefail
TOOL_NAME="Starship"
UCI_STARSHIP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_STARSHIP_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/nerd_font.sh
source "${UCI_STARSHIP_SCRIPT_DIR}/../lib/nerd_font.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_STARSHIP_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_STARSHIP_INSTALL_URL="https://starship.rs/install.sh"
UCI_STARSHIP_BIN="starship"

# Function to check status
check_status() {
    if curl_script_installed "${UCI_STARSHIP_BIN}"; then
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
    if ! curl_script_run "${UCI_STARSHIP_INSTALL_URL}" sh; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "${UCI_STARSHIP_BIN}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to configure (Hito 54, 7° verbo del contrato, ver ADR 0042)
#
# Starship necesita una Nerd Font para sus símbolos/íconos por defecto,
# igual que Powerlevel10k. A diferencia de aquel, no impone una familia
# concreta —solo pide "una Nerd Font"— así que se reutiliza MesloLGS NF
# vía scripts/lib/nerd_font.sh en vez de instalar una segunda familia
# para el mismo fin.
#
# Esta es la segunda mitad del par de casos reales que justificó extraer
# la biblioteca compartida en vez de duplicar la lógica (ADR 0032); el
# objetivo del Hito 54 ya anticipaba esta posibilidad.
configure_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" != "INSTALLED" ]]; then
        echo "${TOOL_NAME} no está instalado; corre 'install' antes de 'configure'." >&2
        return 1
    fi

    echo "Configurando ${TOOL_NAME}: instalando la Nerd Font MesloLGS NF..."
    nerd_font_install "${HOME}"
    echo "${TOOL_NAME} configurado."
    nerd_font_terminal_hint
}

installer_run_cli "$@"
