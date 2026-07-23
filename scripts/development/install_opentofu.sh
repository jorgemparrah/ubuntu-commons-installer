#!/usr/bin/env bash
# install_opentofu.sh
#
# Instalador nuevo (Hito 42, ver docs/ROADMAP.md): agrega OpenTofu al
# catálogo (category=development, subcategory=iac, junto a Terraform) —
# fork FOSS (MPL-2.0) de Terraform mantenido por la Linux Foundation tras
# el cambio de licencia de HashiCorp a BUSL en 2023 (ver
# install_terraform.sh). Mismo mecanismo `apt-vendor-repo` que Terraform,
# pero más simple: se leyó el script oficial de instalación
# (get.opentofu.org/install-opentofu.sh, solo lectura, nunca ejecutado) y
# se confirmó en vivo (`curl` + `file`) que la clave GPG primaria YA está
# en formato binario/dearmorado (a diferencia de Terraform/Azure CLI/
# Google Cloud CLI), así que se usa
# `apt_vendor_repo_fetch_file_plain` (mismo helper que Brave/VSCodium)
# para la clave, no `apt_vendor_repo_fetch_key_dearmored`. La línea de
# repositorio tampoco depende del codename de la distro: el script oficial
# fija distro "any"/componente "main" siempre, para cualquier versión de
# Ubuntu/Debian.

set -Eeuo pipefail

UCI_OPENTOFU_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_OPENTOFU_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_OPENTOFU_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OPENTOFU_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="OpenTofu"
PACKAGE_NAME="tofu"
OPENTOFU_KEYRING=/usr/share/keyrings/opentofu.gpg
OPENTOFU_REPO_LIST=/etc/apt/sources.list.d/opentofu.list
OPENTOFU_KEY_URL="https://packages.opentofu.org/opentofu/tofu/gpgkey"
OPENTOFU_REPO_URL="https://packages.opentofu.org/opentofu/tofu/any/"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v tofu &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${OPENTOFU_KEY_URL}" "${OPENTOFU_KEYRING}"
    apt_vendor_repo_write_list "${OPENTOFU_REPO_LIST}" \
        "deb [signed-by=${OPENTOFU_KEYRING}] ${OPENTOFU_REPO_URL} any main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${OPENTOFU_REPO_LIST}" "${OPENTOFU_KEYRING}"
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
