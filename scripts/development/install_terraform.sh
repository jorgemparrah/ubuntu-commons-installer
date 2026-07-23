#!/usr/bin/env bash
# install_terraform.sh
#
# Instalador nuevo (Hito 42, ver docs/ROADMAP.md): agrega Terraform al
# catálogo (category=development, subcategory=iac, junto a OpenTofu).
# Usa el dispatcher compartido, los helpers APT (scripts/lib/apt.sh) y los
# helpers de repositorio de proveedor (scripts/lib/apt_vendor_repo.sh) —
# mismo mecanismo `apt-vendor-repo` con clave dearmorada + línea 'deb'
# construida a mano con codename dinámico que VirtualBox/Azure CLI (no un
# `.sources` ya armado como Brave/VSCodium/Signal Desktop): confirmado en
# vivo que developer.hashicorp.com/terraform/install publica la clave en
# formato ASCII-armored (requiere 'gpg --dearmor') y una línea de
# repositorio que depende del codename de la distro.
#
# Nota de licencia (confirmada por investigación, no asumida): desde
# agosto de 2023 HashiCorp relicenció Terraform bajo BUSL 1.1 (Business
# Source License), que NO es una licencia de código abierto aprobada por
# la OSI — prohíbe usarlo para ofrecer un producto/servicio que compita
# con HashiCorp, pero permite uso normal (personal, interno, de una
# workstation) sin restricción. Se incluye igual en el catálogo, junto a
# OpenTofu (fork FOSS bajo MPL-2.0, ver install_opentofu.sh), consistente
# con el precedente ya existente de otras herramientas no-FOSS-pero-
# gratuitas en este catálogo (Obsidian, Discord, Slack, Steam).

set -Eeuo pipefail

UCI_TERRAFORM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_TERRAFORM_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_TERRAFORM_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_TERRAFORM_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Terraform"
PACKAGE_NAME="terraform"
TERRAFORM_KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
TERRAFORM_REPO_LIST=/etc/apt/sources.list.d/hashicorp.list
TERRAFORM_KEY_URL="https://apt.releases.hashicorp.com/gpg"
TERRAFORM_REPO_URL="https://apt.releases.hashicorp.com"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v terraform &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${TERRAFORM_KEY_URL}" "${TERRAFORM_KEYRING}"
    apt_vendor_repo_write_list "${TERRAFORM_REPO_LIST}" \
        "deb [arch=$(dpkg --print-architecture) signed-by=${TERRAFORM_KEYRING}] ${TERRAFORM_REPO_URL} $(. /etc/os-release && echo "${VERSION_CODENAME}") main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${TERRAFORM_REPO_LIST}" "${TERRAFORM_KEYRING}"
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
