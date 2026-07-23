#!/usr/bin/env bash
# install_azure_cli.sh
#
# Instalador nuevo (Hito 42, ver docs/ROADMAP.md): agrega Azure CLI al
# catálogo (category=development, subcategory=cloud-cli, junto a AWS CLI/
# Google Cloud CLI). Confirmado en vivo (learn.microsoft.com/en-us/cli/
# azure/install-azure-cli-linux, pestaña apt): mismo mecanismo
# `apt-vendor-repo` con clave dearmorada que Terraform/VirtualBox, pero el
# repositorio oficial de Microsoft se publica en formato DEB822 (no una
# línea 'deb [...]' simple) — se escribe con
# `apt_vendor_repo_write_list` pasándole el contenido completo del
# archivo `.sources` (varias líneas), en vez de una sola línea 'deb'. El
# codename de la distro sigue siendo dinámico (Suites: $(lsb_release -cs)),
# igual que Terraform.

set -Eeuo pipefail

UCI_AZURE_CLI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_AZURE_CLI_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_AZURE_CLI_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_AZURE_CLI_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Azure CLI"
PACKAGE_NAME="azure-cli"
AZURE_CLI_KEYRING=/etc/apt/keyrings/microsoft.gpg
AZURE_CLI_SOURCES=/etc/apt/sources.list.d/azure-cli.sources
AZURE_CLI_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
AZURE_CLI_REPO_URL="https://packages.microsoft.com/repos/azure-cli/"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v az &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${AZURE_CLI_KEY_URL}" "${AZURE_CLI_KEYRING}"
    apt_vendor_repo_write_list "${AZURE_CLI_SOURCES}" \
"Types: deb
URIs: ${AZURE_CLI_REPO_URL}
Suites: $(lsb_release -cs)
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: ${AZURE_CLI_KEYRING}"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${AZURE_CLI_SOURCES}" "${AZURE_CLI_KEYRING}"
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
