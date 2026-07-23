#!/usr/bin/env bash
# install_eza.sh
#
# Instalador nuevo (Hito 45, ver docs/ROADMAP.md): agrega eza al
# catálogo (category=system, subcategory=cli-utils). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh) y los helpers de
# repositorio de proveedor (scripts/lib/apt_vendor_repo.sh) — mecanismo
# `apt-vendor-repo`, igual que VirtualBox/Terraform: clave dearmorada +
# línea 'deb' construida a mano, con distro fija (sin depender del
# codename).
#
# eza (fork mantenido de exa, sin actividad desde 2023) no está en los
# repositorios oficiales de Ubuntu; el propio proyecto (INSTALL.md
# oficial) publica un repositorio APT de terceros (`deb.gierens.de`,
# mantenido por un colaborador del proyecto, referenciado como fuente
# oficial en su propia documentación). Clave confirmada en vivo como
# ASCII-armored (requiere 'gpg --dearmor'). Distro fija `stable`/
# componente `main` (sin codename).

set -Eeuo pipefail

UCI_EZA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_EZA_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_EZA_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_EZA_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="eza"
PACKAGE_NAME="eza"
EZA_KEYRING=/etc/apt/keyrings/gierens.gpg
EZA_REPO_LIST=/etc/apt/sources.list.d/gierens.list
EZA_KEY_URL="https://raw.githubusercontent.com/eza-community/eza/main/deb.asc"
EZA_REPO_URL="http://deb.gierens.de"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v eza &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${EZA_KEY_URL}" "${EZA_KEYRING}"
    apt_vendor_repo_write_list "${EZA_REPO_LIST}" \
        "deb [signed-by=${EZA_KEYRING}] ${EZA_REPO_URL} stable main"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${EZA_REPO_LIST}" "${EZA_KEYRING}"
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
