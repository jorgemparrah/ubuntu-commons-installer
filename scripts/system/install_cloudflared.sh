#!/usr/bin/env bash
# install_cloudflared.sh
#
# Instalador nuevo (Hito 46, ver docs/ROADMAP.md): agrega Cloudflare
# Tunnel (`cloudflared`) al catálogo (category=system,
# subcategory=networking). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mecanismo `apt-vendor-repo`.
#
# cloudflared (túneles salientes sin abrir puertos; cliente open-source
# Apache-2.0/BSD según el componente, aunque depende del servicio de
# Cloudflare) no está en los repositorios oficiales de Ubuntu. Confirmado
# en vivo (`pkg.cloudflare.com/cloudflare-main.gpg`, con `curl` + `file`):
# la clave YA es binaria (`apt_vendor_repo_fetch_file_plain`, sin
# `gpg --dearmor`, igual que Tailscale/OpenTofu). Distro fija `any`/
# componente `main` (documentación oficial recomienda explícitamente la
# variante "Any Debian Based Distribution" sobre las variantes por
# codename) — más simple que Tailscale, sin depender del codename.

set -Eeuo pipefail

UCI_CLOUDFLARED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_CLOUDFLARED_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_CLOUDFLARED_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CLOUDFLARED_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Cloudflare Tunnel"
PACKAGE_NAME="cloudflared"
CLOUDFLARED_KEYRING=/usr/share/keyrings/cloudflare-main.gpg
CLOUDFLARED_REPO_LIST=/etc/apt/sources.list.d/cloudflared.list
CLOUDFLARED_KEY_URL="https://pkg.cloudflare.com/cloudflare-main.gpg"
CLOUDFLARED_REPO_URL="https://pkg.cloudflare.com/cloudflared"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v cloudflared &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${CLOUDFLARED_KEY_URL}" "${CLOUDFLARED_KEYRING}"
    apt_vendor_repo_write_list "${CLOUDFLARED_REPO_LIST}" \
        "deb [signed-by=${CLOUDFLARED_KEYRING}] ${CLOUDFLARED_REPO_URL} any main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${CLOUDFLARED_REPO_LIST}" "${CLOUDFLARED_KEYRING}"
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
