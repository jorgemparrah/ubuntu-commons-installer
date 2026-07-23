#!/usr/bin/env bash
# install_vagrant.sh
#
# Instalador nuevo (Hito 48, ver docs/ROADMAP.md): agrega Vagrant al
# catálogo (category=development, subcategory=virtualization, mismo
# grupo que VirtualBox/virt-manager). Usa el dispatcher compartido, los
# helpers APT (scripts/lib/apt.sh) y los helpers de repositorio de
# proveedor (scripts/lib/apt_vendor_repo.sh) — mismo mecanismo
# `apt-vendor-repo` con clave dearmorada + codename dinámico que
# Terraform: Vagrant es otro producto de HashiCorp, publicado en el mismo
# repositorio APT oficial (`apt.releases.hashicorp.com`), confirmado en
# vivo (`apt-cache policy vagrant`).
#
# Nota de licencia (igual que Terraform, ver install_terraform.sh): desde
# agosto de 2023 HashiCorp relicenció Vagrant bajo BUSL 1.1 (Business
# Source License), que NO es una licencia de código abierto aprobada por
# la OSI — prohíbe usarlo para ofrecer un producto/servicio que compita
# con HashiCorp, pero permite uso normal (personal, interno, de una
# workstation) sin restricción. Se incluye igual en el catálogo, mismo
# precedente que Terraform/Obsidian/Discord/Slack/Steam.

set -Eeuo pipefail

UCI_VAGRANT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_VAGRANT_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_VAGRANT_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_VAGRANT_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Vagrant"
PACKAGE_NAME="vagrant"
VAGRANT_KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
VAGRANT_REPO_LIST=/etc/apt/sources.list.d/hashicorp.list
VAGRANT_KEY_URL="https://apt.releases.hashicorp.com/gpg"
VAGRANT_REPO_URL="https://apt.releases.hashicorp.com"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v vagrant &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${VAGRANT_KEY_URL}" "${VAGRANT_KEYRING}"
    apt_vendor_repo_write_list "${VAGRANT_REPO_LIST}" \
        "deb [arch=$(dpkg --print-architecture) signed-by=${VAGRANT_KEYRING}] ${VAGRANT_REPO_URL} $(. /etc/os-release && echo "${VERSION_CODENAME}") main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${VAGRANT_REPO_LIST}" "${VAGRANT_KEYRING}"
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
