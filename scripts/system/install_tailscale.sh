#!/usr/bin/env bash
# install_tailscale.sh
#
# Instalador nuevo (Hito 46, ver docs/ROADMAP.md): agrega Tailscale al
# catálogo (category=system, subcategory=networking). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh) y los helpers de
# repositorio de proveedor (scripts/lib/apt_vendor_repo.sh) — mecanismo
# `apt-vendor-repo`.
#
# Tailscale (mesh VPN basada en WireGuard; cliente open-source BSD-3-
# Clause, aunque el servicio de coordinación es propietario con capa
# gratuita) no está en los repositorios oficiales de Ubuntu. Confirmado
# en vivo (`pkgs.tailscale.com/stable/ubuntu/<codename>.noarmor.gpg`,
# nombre "noarmor" ya indica formato binario, confirmado también con
# `file`): la clave YA es binaria (`apt_vendor_repo_fetch_file_plain`,
# sin `gpg --dearmor`), pero la línea de repositorio SÍ depende del
# codename de la distro (a diferencia de OpenTofu/Google Cloud CLI) —
# mismo patrón de codename dinámico que Terraform/Azure CLI, pero sin
# dearmorar la clave.

set -Eeuo pipefail

UCI_TAILSCALE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_TAILSCALE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_TAILSCALE_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_TAILSCALE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Tailscale"
PACKAGE_NAME="tailscale"
TAILSCALE_KEYRING=/usr/share/keyrings/tailscale-archive-keyring.gpg
TAILSCALE_REPO_LIST=/etc/apt/sources.list.d/tailscale.list

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v tailscale &> /dev/null; then
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

    local codename
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

    apt_vendor_repo_fetch_file_plain \
        "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
        "${TAILSCALE_KEYRING}"
    apt_vendor_repo_write_list "${TAILSCALE_REPO_LIST}" \
        "deb [signed-by=${TAILSCALE_KEYRING}] https://pkgs.tailscale.com/stable/ubuntu ${codename} main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${TAILSCALE_REPO_LIST}" "${TAILSCALE_KEYRING}"
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
