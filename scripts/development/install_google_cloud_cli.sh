#!/usr/bin/env bash
# install_google_cloud_cli.sh
#
# Instalador nuevo (Hito 42, ver docs/ROADMAP.md): agrega Google Cloud CLI
# al catálogo (category=development, subcategory=cloud-cli, junto a AWS
# CLI/Azure CLI). Confirmado en vivo (docs.cloud.google.com/sdk/docs/
# install, sección apt): mismo mecanismo `apt-vendor-repo` con clave
# dearmorada + línea 'deb' construida a mano que Terraform/Azure CLI, pero
# más simple que ambos: la línea de repositorio usa una distro fija
# ("cloud-sdk"), sin depender del codename de Ubuntu/Debian. El nombre del
# paquete es `google-cloud-cli` (desde la versión 371.0.0+; versiones
# previas usaban `google-cloud-sdk`, ya obsoleto).

set -Eeuo pipefail

UCI_GOOGLE_CLOUD_CLI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_GOOGLE_CLOUD_CLI_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_GOOGLE_CLOUD_CLI_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_GOOGLE_CLOUD_CLI_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Google Cloud CLI"
PACKAGE_NAME="google-cloud-cli"
GOOGLE_CLOUD_CLI_KEYRING=/usr/share/keyrings/cloud.google.gpg
GOOGLE_CLOUD_CLI_REPO_LIST=/etc/apt/sources.list.d/google-cloud-sdk.list
GOOGLE_CLOUD_CLI_KEY_URL="https://packages.cloud.google.com/apt/doc/apt-key.gpg"
GOOGLE_CLOUD_CLI_REPO_URL="https://packages.cloud.google.com/apt"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v gcloud &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${GOOGLE_CLOUD_CLI_KEY_URL}" "${GOOGLE_CLOUD_CLI_KEYRING}"
    apt_vendor_repo_write_list "${GOOGLE_CLOUD_CLI_REPO_LIST}" \
        "deb [signed-by=${GOOGLE_CLOUD_CLI_KEYRING}] ${GOOGLE_CLOUD_CLI_REPO_URL} cloud-sdk main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${GOOGLE_CLOUD_CLI_REPO_LIST}" "${GOOGLE_CLOUD_CLI_KEYRING}"
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
