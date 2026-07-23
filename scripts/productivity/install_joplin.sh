#!/usr/bin/env bash
# install_joplin.sh
#
# Instalador nuevo (Hito 36, ver docs/ROADMAP.md): agrega Joplin al
# catálogo, mismo grupo que Obsidian (category=productivity,
# subcategory=notes) — alternativa 100% FOSS (AGPL-3.0) a Obsidian, que
# es gratis pero de código cerrado.
#
# Joplin no publica repositorio APT ni snap oficial confirmado como
# principal: el mecanismo oficial recomendado es su script
# `Joplin_install_and_update.sh` (`curl | bash`), así que se reutiliza
# `curl_script_run` de scripts/lib/curl_script.sh (descarga a un temporal
# y ejecuta, en vez de un pipe directo) para el paso de descarga/
# ejecución en sí.
#
# `check_status`/`uninstall_tool` NO reutilizan la convención genérica de
# ese mismo helper (`~/.local/bin/<binario>`, ver
# curl_script_uninstall_local_bin): se confirmó inspeccionando el script
# oficial que instala el AppImage en `~/.joplin/Joplin.AppImage`
# (con un archivo `~/.joplin/VERSION` junto al lanzador `.desktop`), SIN
# crear ningún symlink en el PATH — mismo criterio de adaptación a medida
# ya aplicado en install_ollama.sh cuando la convención genérica no
# encaja con el mecanismo real del proveedor.

set -Eeuo pipefail

UCI_JOPLIN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/curl_script.sh
source "${UCI_JOPLIN_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_JOPLIN_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Joplin"
JOPLIN_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh"
JOPLIN_APPIMAGE_PATH="${HOME}/.joplin/Joplin.AppImage"

# Function to check status
check_status() {
    if [[ ! -e "${JOPLIN_APPIMAGE_PATH}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ ! -x "${JOPLIN_APPIMAGE_PATH}" ]]; then
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
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi
    if [[ "${current_status}" == "INSTALLED" ]]; then
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."
    curl_script_run "${JOPLIN_INSTALL_SCRIPT_URL}" bash
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    if [[ ! -e "${JOPLIN_APPIMAGE_PATH}" ]]; then
        echo "${TOOL_NAME} no está instalado." >&2
        return 0
    fi

    echo "Desinstalando ${TOOL_NAME}..."
    rm -rf "${HOME}/.joplin"
    rm -f "${HOME}/.local/share/applications/appimagekit-joplin.desktop"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a correr el script
# oficial, que es exactamente el comportamiento deseado (siempre la
# última versión).

# Function to update (el propio script oficial ya maneja "ya instalado, actualizar")
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    curl_script_run "${JOPLIN_INSTALL_SCRIPT_URL}" bash
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
