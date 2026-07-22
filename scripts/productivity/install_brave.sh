#!/usr/bin/env bash
# install_brave.sh
#
# Instalador nuevo (Hito 27, ver docs/ROADMAP.md): agrega el navegador
# Brave al catálogo. Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mecanismo `apt-vendor-repo`, pero con
# una diferencia real respecto a Docker/VS Code/Cursor/VirtualBox/Slack/
# OnlyOffice/KeePassXC: Brave publica su clave YA lista para 'signed-by'
# (sin 'gpg --dearmor') Y un archivo de repositorio completo en formato
# DEB822 (`brave-browser.sources`), en vez de una línea 'deb [...]' que
# este proyecto tenga que construir a mano con un codename — se descargan
# ambos archivos tal cual con `apt_vendor_repo_fetch_file_plain` (nuevo
# en este instalador, ver scripts/lib/apt_vendor_repo.sh), sin
# `apt_vendor_repo_write_list`.

set -Eeuo pipefail

UCI_BRAVE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_BRAVE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_BRAVE_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_BRAVE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Brave"
PACKAGE_NAME="brave-browser"
BRAVE_KEYRING=/usr/share/keyrings/brave-browser-archive-keyring.gpg
BRAVE_SOURCES_LIST=/etc/apt/sources.list.d/brave-browser-release.sources
BRAVE_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
BRAVE_SOURCES_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser.sources"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v brave-browser &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${BRAVE_KEY_URL}" "${BRAVE_KEYRING}"
    apt_vendor_repo_fetch_file_plain "${BRAVE_SOURCES_URL}" "${BRAVE_SOURCES_LIST}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${BRAVE_SOURCES_LIST}" "${BRAVE_KEYRING}"
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
