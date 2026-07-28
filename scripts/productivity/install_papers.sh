#!/usr/bin/env bash
# install_papers.sh
#
# Instalador nuevo (Hito 50, ver docs/ROADMAP.md): agrega Papers al
# catálogo (category=productivity, subcategory=office, mismo grupo que
# LibreOffice/OnlyOffice/Okular). Usa el dispatcher compartido y los
# helpers Flatpak compartidos (scripts/lib/flatpak.sh) — segundo caso del
# mecanismo `flatpak`, junto con Kooha (ver
# docs/adr/0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md).
#
# Papers (visor de documentos de GNOME, sucesor de Evince) NO está en los
# repositorios de Ubuntu 24.04 — recién se incorpora como app core de
# GNOME en versiones posteriores. Flathub es la única fuente disponible
# que cubre las dos versiones soportadas por este proyecto por igual. App
# ID confirmado en vivo contra la API de Flathub (`org.gnome.Papers`,
# GPL-2.0-or-later).
#
# Se agrega como opción adicional, no como reemplazo de Okular (ya en el
# catálogo) ni de Evince (presente en Ubuntu por defecto) — mismo criterio
# que Neovim frente a Vim (Hito 34).

set -Eeuo pipefail

UCI_PAPERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/flatpak.sh
source "${UCI_PAPERS_SCRIPT_DIR}/../lib/flatpak.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_PAPERS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Papers"
FLATPAK_APP_ID="org.gnome.Papers"

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
