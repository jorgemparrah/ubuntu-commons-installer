#!/usr/bin/env bash
# install_wezterm.sh
#
# WezTerm — terminal acelerada por GPU. No está en los repositorios
# oficiales de Ubuntu; se instala vía su repositorio APT propio en
# Fury.io (wezterm.org/install/linux.html), con clave GPG signed-by
# (nunca apt-key). A diferencia de Docker/VS Code/Cursor, este repo es
# "flat" (usa `* *` en vez del codename de Ubuntu como distribución), así
# que sirve igual para 24.04 y 26.04 sin detectar versión.
#
# Usa el dispatcher compartido (scripts/lib/installer_cli.sh), los
# helpers APT (scripts/lib/apt.sh) y los helpers de repositorio de
# proveedor (scripts/lib/apt_vendor_repo.sh, grupo vendor-repo del Hito 11).

set -Eeuo pipefail

UCI_WEZTERM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_WEZTERM_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_WEZTERM_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_WEZTERM_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="WezTerm"
PACKAGE_NAME="wezterm"
WEZTERM_KEYRING=/usr/share/keyrings/wezterm-fury.gpg
WEZTERM_REPO_LIST=/etc/apt/sources.list.d/wezterm.list

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v wezterm &> /dev/null; then
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

    apt_vendor_repo_fetch_key_dearmored "https://apt.fury.io/wez/gpg.key" "${WEZTERM_KEYRING}"
    apt_vendor_repo_write_list "${WEZTERM_REPO_LIST}" \
        "deb [signed-by=${WEZTERM_KEYRING}] https://apt.fury.io/wez/ * *"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${WEZTERM_REPO_LIST}" "${WEZTERM_KEYRING}"
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
