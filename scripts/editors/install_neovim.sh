#!/usr/bin/env bash
# install_neovim.sh
#
# Instalador nuevo (Hito 34, ver docs/ROADMAP.md): agrega Neovim al
# catálogo, mismo grupo que Vim (category=editors,
# subcategory=terminal-editors) — se agrega como complemento, no
# reemplazo (LSP nativo, desarrollo más activo). Usa el dispatcher
# compartido y los helpers APT (scripts/lib/apt.sh) — mismo mecanismo
# apt-simple que Ranger.
#
# El paquete `neovim` de los repositorios oficiales de Ubuntu (universe)
# queda desactualizado frente a GitHub Releases (0.9.5 en 24.04 vs v0.12.x
# actual, brecha mayor que la de fzf/lazygit) — riesgo aceptado y
# documentado, mismo criterio que esos dos. Existe un PPA
# (`ppa:neovim-ppa/stable`) pero NO está mantenido por el equipo oficial
# de Neovim (aviso explícito del propio PPA en Launchpad) — se prefiere
# el paquete oficial de Ubuntu antes que un PPA de terceros no verificado
# como oficial (ver AGENT.md §15, evitar PPAs de terceros salvo que sea
# necesario).

set -Eeuo pipefail

UCI_NEOVIM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_NEOVIM_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_NEOVIM_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Neovim"
PACKAGE_NAME="neovim"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v nvim &> /dev/null; then
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
