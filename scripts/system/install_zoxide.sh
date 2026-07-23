#!/usr/bin/env bash
# install_zoxide.sh
#
# Instalador nuevo (Hito 39, ver docs/ROADMAP.md): agrega zoxide al
# catálogo, mismo grupo que fzf/thefuck/jq/yq/HTTPie/xh/duf/btop
# (category=system, subcategory=cli-utils). Usa el dispatcher y los
# helpers APT compartidos, mismo patrón apt-simple que
# install_ranger.sh.
#
# El paquete `zoxide` está en los repositorios oficiales de Ubuntu
# (universe), confirmado en vivo (0.9.3-1 en 24.04).
#
# Este instalador SOLO instala el binario `zoxide` — no modifica
# `.bashrc`/`.zshrc` para agregar el hook de shell que hace falta para
# que reemplace efectivamente a `cd` (`eval "$(zoxide init bash)"` o
# equivalente por shell). Mismo criterio que Oh My Zsh/Powerlevel10k
# (AGENT.md §17: la configuración del shell le pertenece al usuario,
# nunca se modifica automáticamente sin que se pida explícitamente) — el
# binario queda disponible para usarlo manualmente (`zoxide add/query`),
# y activar el hook completo queda como paso manual documentado acá.

set -Eeuo pipefail

UCI_ZOXIDE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ZOXIDE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ZOXIDE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="zoxide"
PACKAGE_NAME="zoxide"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v zoxide &> /dev/null; then
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
    echo "${TOOL_NAME} instalado correctamente. Para que reemplace a 'cd', agregá el hook de tu shell manualmente: 'eval \"\$(zoxide init bash)\"' en ~/.bashrc (o el equivalente para tu shell, ver https://zoxide.org)."
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
