#!/usr/bin/env bash
# install_onlyoffice.sh
#
# Instalador nuevo (Hito 26, ver docs/ROADMAP.md): agrega OnlyOffice
# Desktop Editors al catálogo. Usa el dispatcher compartido, los helpers
# APT (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mismo mecanismo `apt-vendor-repo` que
# Docker/VS Code/Cursor/Brave/VirtualBox/Slack.
#
# ONLYOFFICE publica su repositorio oficial directamente
# (download.onlyoffice.com), con clave GPG en URL HTTPS directa. La línea
# del repositorio usa 'debian squeeze' como distro/codename FIJO (mismo
# patrón que Slack con 'ubuntu trusty'), independiente de la versión real
# de Ubuntu — no es un error ni algo a corregir dinámicamente.

set -Eeuo pipefail

UCI_ONLYOFFICE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ONLYOFFICE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_ONLYOFFICE_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ONLYOFFICE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="OnlyOffice"
PACKAGE_NAME="onlyoffice-desktopeditors"
ONLYOFFICE_KEYRING=/usr/share/keyrings/onlyoffice.gpg
ONLYOFFICE_REPO_LIST=/etc/apt/sources.list.d/onlyoffice.list
ONLYOFFICE_KEY_URL="https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE"
ONLYOFFICE_REPO_LINE="deb [signed-by=${ONLYOFFICE_KEYRING}] https://download.onlyoffice.com/repo/debian squeeze main"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v onlyoffice-desktopeditors &> /dev/null; then
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

    apt_vendor_repo_ensure_gnupg
    apt_vendor_repo_fetch_key_dearmored "${ONLYOFFICE_KEY_URL}" "${ONLYOFFICE_KEYRING}"
    apt_vendor_repo_write_list "${ONLYOFFICE_REPO_LIST}" "${ONLYOFFICE_REPO_LINE}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${ONLYOFFICE_REPO_LIST}" "${ONLYOFFICE_KEYRING}"
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
