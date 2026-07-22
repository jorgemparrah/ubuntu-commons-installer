#!/usr/bin/env bash
# install_ollama.sh
#
# Instalador nuevo (Hito 28, ver docs/ROADMAP.md): agrega Ollama al
# catálogo. Usa el mecanismo `curl-script` (scripts/lib/curl_script.sh,
# ver ADR 0037), mismo patrón que Claude Code/Codex CLI/OpenCode. Ollama
# es un runtime local de modelos de lenguaje (LLM), no un asistente de
# código — se registra en category=development/subcategory=ai-runtime
# (nueva), distinta de subcategory=ai-cli (asistentes de codificación) y
# ai-agent (agentes de propósito general).
#
# Funciona en modo CPU-only sin dependencias especiales (sin GPU/drivers
# obligatorios) — el requisito real es RAM suficiente, no hardware
# específico, así que no bloquea la instalación básica.
#
# 'uninstall' NO reutiliza curl_script_uninstall_local_bin (asume
# ~/.local/bin/<binario>, que no aplica acá): el script oficial de Ollama
# instala el binario en una ruta del sistema (típicamente
# /usr/local/bin/ollama) y registra un servicio systemd propio. Se sigue
# en cambio la secuencia de desinstalación documentada oficialmente
# (detener/deshabilitar el servicio, quitar el binario y el usuario/grupo
# dedicados) — convención asumida de los pasos publicados por Ollama, no
# una API oficial de "uninstall" de un solo comando.

set -Eeuo pipefail
TOOL_NAME="Ollama"
UCI_OLLAMA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_OLLAMA_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OLLAMA_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_OLLAMA_INSTALL_URL="https://ollama.com/install.sh"
UCI_OLLAMA_BIN="ollama"

check_status() {
    if curl_script_installed "${UCI_OLLAMA_BIN}"; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    if ! curl_script_run "${UCI_OLLAMA_INSTALL_URL}" sh; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if command -v systemctl &> /dev/null; then
        sudo systemctl stop ollama 2>/dev/null || true
        sudo systemctl disable ollama 2>/dev/null || true
    fi
    sudo rm -f /etc/systemd/system/ollama.service

    local ollama_bin
    ollama_bin="$(command -v ollama 2>/dev/null || echo /usr/local/bin/ollama)"
    sudo rm -f "${ollama_bin}"
    sudo rm -rf /usr/share/ollama

    sudo userdel ollama 2>/dev/null || true
    sudo groupdel ollama 2>/dev/null || true

    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
