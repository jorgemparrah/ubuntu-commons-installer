#!/usr/bin/env bash
# install_element.sh
#
# Instalador nuevo (Hito 36, ver docs/ROADMAP.md): agrega Element
# (cliente oficial del protocolo Matrix) al catálogo, mismo grupo que
# Slack/Discord/Telegram Desktop/Zoom (category=productivity,
# subcategory=communication). Usa el dispatcher compartido, los helpers
# APT (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh).
#
# La clave GPG oficial ya viene lista para 'signed-by' (sin
# 'gpg --dearmor', confirmado en vivo), pero a diferencia de Brave/ngrok/
# VSCodium, Element NO publica un archivo `.sources` completo — la línea
# de repo se construye a mano (`apt_vendor_repo_write_list`), con distro
# fija `default` (no depende de la versión real de Ubuntu, mismo patrón
# que Slack con `ubuntu trusty`).

set -Eeuo pipefail

UCI_ELEMENT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ELEMENT_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_ELEMENT_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ELEMENT_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Element"
PACKAGE_NAME="element-desktop"
ELEMENT_KEYRING=/usr/share/keyrings/element-io-archive-keyring.gpg
ELEMENT_REPO_LIST=/etc/apt/sources.list.d/element-io.list
ELEMENT_KEY_URL="https://packages.element.io/debian/element-io-archive-keyring.gpg"
ELEMENT_REPO_URL="https://packages.element.io/debian/"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v element-desktop &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${ELEMENT_KEY_URL}" "${ELEMENT_KEYRING}"
    apt_vendor_repo_write_list "${ELEMENT_REPO_LIST}" \
        "deb [signed-by=${ELEMENT_KEYRING}] ${ELEMENT_REPO_URL} default main"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${ELEMENT_REPO_LIST}" "${ELEMENT_KEYRING}"
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
