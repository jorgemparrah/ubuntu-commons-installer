#!/usr/bin/env bash
# install_ghostty.sh
#
# Ghostty — terminal acelerada por GPU. Su mecanismo de instalación
# depende de la versión de Ubuntu, algo nuevo entre los instaladores de
# este proyecto:
#   - Ubuntu 26.04+: el paquete 'ghostty' ya está en el repositorio
#     oficial (universe) — apt-simple directo.
#   - Ubuntu 24.04: todavía no está en el repositorio oficial; se usa el
#     PPA mantenido por el autor del empaquetado Debian/Ubuntu
#     (ppa:mkasberg/ghostty-ubuntu, ver
#     github.com/mkasberg/ghostty-ubuntu), mismo patrón de PPA que
#     scripts/productivity/install_ulauncher.sh.
#
# Se detecta la versión con 'lsb_release -rs' (versión numérica, nunca el
# codename — mismo criterio que scripts/system/install_kernel.sh tras su
# corrección del Hito 9). Usa el dispatcher compartido
# (scripts/lib/installer_cli.sh) y los helpers APT (scripts/lib/apt.sh).
#
# 'status'/'update'/'repair' no distinguen el mecanismo: una vez
# instalado, el paquete 'ghostty' se comporta igual sin importar de dónde
# vino.

set -Eeuo pipefail

UCI_GHOSTTY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_GHOSTTY_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_GHOSTTY_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Ghostty"
PACKAGE_NAME="ghostty"
GHOSTTY_PPA="ppa:mkasberg/ghostty-ubuntu"

# ghostty_needs_ppa
# 0 si esta versión de Ubuntu todavía no publica 'ghostty' en su
# repositorio oficial (24.04); 1 en cualquier otra (26.04 en adelante).
ghostty_needs_ppa() {
    [[ "$(lsb_release -rs 2>/dev/null)" == "24.04" ]]
}

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v ghostty &> /dev/null; then
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

    if ghostty_needs_ppa; then
        if ! command -v add-apt-repository &> /dev/null; then
            apt_install_packages software-properties-common
        fi
        sudo add-apt-repository -y "${GHOSTTY_PPA}"
    fi

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"

    if ghostty_needs_ppa; then
        sudo add-apt-repository -y --remove "${GHOSTTY_PPA}"
    fi

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
