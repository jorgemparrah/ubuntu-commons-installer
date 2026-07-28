#!/usr/bin/env bash
# install_kooha.sh
#
# Instalador nuevo (Hito 50, ver docs/ROADMAP.md): agrega Kooha al
# catálogo (category=multimedia, subcategory=capture, mismo grupo que OBS
# Studio/Cheese). Usa el dispatcher compartido y los helpers Flatpak
# compartidos (scripts/lib/flatpak.sh) — **primer instalador del
# mecanismo `flatpak`**, junto con Papers (ver
# docs/adr/0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md).
#
# Kooha no está en los repositorios de Ubuntu. Su repositorio oficial
# (SeaDve/Kooha) publica Flathub como método primario y advierte
# explícitamente que los paquetes que no son Flatpak "no están soportados
# por el desarrollador" — existe un snap de la misma cuenta del autor
# (`seadve`), pero al no estar declarado como soportado por el proyecto no
# se usa (criterio de priorizar fuentes oficiales sin ambigüedad de
# mantenimiento). App ID confirmado en vivo contra la API de Flathub.
#
# Grabador de pantalla simple para GNOME/Wayland, complementario a OBS
# Studio (que apunta a streaming/producción), no reemplazo.

set -Eeuo pipefail

UCI_KOOHA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/flatpak.sh
source "${UCI_KOOHA_SCRIPT_DIR}/../lib/flatpak.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_KOOHA_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Kooha"
FLATPAK_APP_ID="io.github.seadve.Kooha"

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
