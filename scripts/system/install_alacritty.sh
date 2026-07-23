#!/usr/bin/env bash
# install_alacritty.sh
#
# Instalador nuevo (Hito 40, ver docs/ROADMAP.md): agrega Alacritty al
# catálogo, mismo grupo que Ghostty/Terminator/WezTerm/Kitty
# (category=system, subcategory=terminals). Usa el dispatcher y los
# helpers APT compartidos, mismo patrón apt-simple que
# install_ranger.sh.
#
# El PPA histórico (`ppa:mmstick76/alacritty`, mantenido por el equipo de
# Pop!_OS, no por el propio proyecto Alacritty) está DESCONTINUADO:
# confirmado que su último paquete es de agosto de 2021 (versión 0.9.0)
# y no publica builds para `noble` (24.04) ni versiones posteriores —
# mismo hallazgo que Lazygit en el Hito 33 (PPA de terceros abandonado).
# Se usa el paquete oficial de Ubuntu (`universe`, 0.13.2 en 24.04, frente
# a v0.17.0 en GitHub) — desactualizado pero la única fuente gestionable
# viable, riesgo aceptado y documentado (mismo criterio que fzf/Lazygit/
# Neovim).

set -Eeuo pipefail

UCI_ALACRITTY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ALACRITTY_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ALACRITTY_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Alacritty"
PACKAGE_NAME="alacritty"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v alacritty &> /dev/null; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
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

    echo "Instalando ${TOOL_NAME}..."
    apt_install_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
