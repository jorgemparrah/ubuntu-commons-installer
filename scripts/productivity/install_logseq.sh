#!/usr/bin/env bash
# install_logseq.sh
#
# Instalador nuevo (Hito 51, ver docs/ROADMAP.md): agrega Logseq al
# catálogo (category=productivity, subcategory=notes, mismo grupo que
# Obsidian/Joplin). Usa el dispatcher compartido y los helpers Flatpak
# compartidos (scripts/lib/flatpak.sh) — tercer caso del mecanismo
# `flatpak` tras Kooha y Papers (ver
# docs/adr/0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md).
#
# Logseq no está en los repositorios de Ubuntu ni publica snap oficial.
# Sus únicas distribuciones son AppImage y Flatpak; se elige Flatpak por
# la misma razón que en el Hito 50 (integración con el escritorio y un
# camino de actualización gestionado, frente a un AppImage suelto sin
# `.desktop` ni symlink en el PATH). App ID `com.logseq.Logseq`
# confirmado en vivo contra la API de Flathub (AGPL-3.0-or-later).
#
# Notas en Markdown local con vista de grafo: se agrega como opción
# adicional junto a Obsidian y Joplin, no como reemplazo de ninguno
# (mismo criterio que Joplin frente a Obsidian en el Hito 36).

set -Eeuo pipefail

UCI_LOGSEQ_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/flatpak.sh
source "${UCI_LOGSEQ_SCRIPT_DIR}/../lib/flatpak.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_LOGSEQ_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Logseq"
FLATPAK_APP_ID="com.logseq.Logseq"

# Function to check status
check_status() {
    if ! flatpak_available; then
        echo "UNKNOWN"
        return 1
    fi

    if flatpak_app_installed "${FLATPAK_APP_ID}"; then
        echo "INSTALLED"
        return 0
    fi

    echo "NOT_INSTALLED"
    return 1
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    flatpak_ensure_flathub
    flatpak_install_app "${FLATPAK_APP_ID}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    flatpak_remove_app "${FLATPAK_APP_ID}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    flatpak_update_app "${FLATPAK_APP_ID}"
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
