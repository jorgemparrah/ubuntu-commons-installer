#!/usr/bin/env bash
# install_anythingllm.sh
#
# Instalador nuevo (Hito 53, ver docs/ROADMAP.md): agrega AnythingLLM al
# catálogo (category=ai, subcategory=local-models, mismo grupo que
# Ollama). Usa el dispatcher compartido y los helpers curl-script
# (scripts/lib/curl_script.sh) — mecanismo ya existente (ADR 0037), sin
# necesidad de uno nuevo.
#
# Corrección al objetivo del Hito: asumía que AnythingLLM publicaba un
# `.deb`. Confirmado en vivo contra la API de GitHub Releases que NO —
# el release publica AppImage (x64 y Arm64), `.dmg`, `.exe` y un
# `installer.sh` oficial. Se usa ese script oficial, mismo patrón que
# Joplin (Hito 36): `curl_script_run` solo para descargar/ejecutar, con
# `check_status`/`uninstall_tool` propios, porque el script NO deja el
# binario en `~/.local/bin` (la convención del resto del grupo).
#
# Qué hace el `installer.sh` oficial (leído en vivo, nunca ejecutado a
# ciegas): descarga el AppImage a `$ANYTHING_LLM_INSTALL_DIR` (default
# `$HOME`), lo marca ejecutable, crea un `.desktop` en
# `~/.local/share/applications/`, y en sistemas con AppArmor genera un
# perfil en `/etc/apparmor.d/` (requiere sudo). También puede descargar
# un motor de Ollama embebido bajo `~/.config/anythingllm-desktop/`.
#
# Se fija `ANYTHING_LLM_INSTALL_DIR` a `~/.local/share/anythingllm` en
# vez del default: el default deja el AppImage suelto directamente en el
# home, y la variable es un parámetro oficial y documentado del propio
# script. El perfil de AppArmor usa una ruta con comodín
# (`/**/AnythingLLMDesktop.AppImage`), así que sigue funcionando.

set -Eeuo pipefail

TOOL_NAME="AnythingLLM"
UCI_ANYTHINGLLM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_ANYTHINGLLM_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ANYTHINGLLM_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_ANYTHINGLLM_INSTALL_URL="https://github.com/Mintplex-Labs/anything-llm/releases/latest/download/installer.sh"
UCI_ANYTHINGLLM_DIR="${HOME}/.local/share/anythingllm"
UCI_ANYTHINGLLM_APPIMAGE="${UCI_ANYTHINGLLM_DIR}/AnythingLLMDesktop.AppImage"
UCI_ANYTHINGLLM_DESKTOP="${HOME}/.local/share/applications/anythingllmdesktop.desktop"

# Function to check status
check_status() {
    if [[ ! -e "${UCI_ANYTHINGLLM_APPIMAGE}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ ! -x "${UCI_ANYTHINGLLM_APPIMAGE}" ]]; then
        echo "BROKEN"
        return 1
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "INSTALLED" ]]; then
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install'." >&2
        return 1
    fi
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    mkdir -p "${UCI_ANYTHINGLLM_DIR}"
    if ! ANYTHING_LLM_INSTALL_DIR="${UCI_ANYTHINGLLM_DIR}" \
        curl_script_run "${UCI_ANYTHINGLLM_INSTALL_URL}" sh; then
        echo "No se pudo instalar ${TOOL_NAME}" >&2
        return 1
    fi

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    rm -rf "${UCI_ANYTHINGLLM_DIR}"
    rm -f "${UCI_ANYTHINGLLM_DESKTOP}"

    # El perfil de AppArmor lo crea el script oficial con sudo; se
    # elimina si está presente. No se toca ~/.config/anythingllm-desktop:
    # ahí viven los datos del usuario (workspaces, modelos embebidos), y
    # este proyecto nunca borra datos de usuario sin pedirlo (AGENT.md §2).
    if [[ -f /etc/apparmor.d/anythingllmdesktop ]]; then
        sudo rm -f /etc/apparmor.d/anythingllmdesktop
    fi

    echo "${TOOL_NAME} desinstalado correctamente. Los datos en ~/.config/anythingllm-desktop se conservaron; elimínalos a mano si no los necesitas."
}

# Function to update
update_tool() {
    if [[ ! -e "${UCI_ANYTHINGLLM_APPIMAGE}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    if ! ANYTHING_LLM_INSTALL_DIR="${UCI_ANYTHINGLLM_DIR}" \
        curl_script_run "${UCI_ANYTHINGLLM_INSTALL_URL}" sh; then
        echo "No se pudo actualizar ${TOOL_NAME}" >&2
        return 1
    fi
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN: AppImage presente pero sin
# permiso de ejecución)
repair_tool() {
    if [[ ! -e "${UCI_ANYTHINGLLM_APPIMAGE}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    chmod +x "${UCI_ANYTHINGLLM_APPIMAGE}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
