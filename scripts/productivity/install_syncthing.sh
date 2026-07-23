#!/usr/bin/env bash
# install_syncthing.sh
#
# Instalador nuevo (Hito 44, ver docs/ROADMAP.md): agrega Syncthing al
# catálogo (category=productivity, subcategory=file-sharing, mismo grupo
# que LocalSend). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mecanismo `apt-vendor-repo`.
#
# El paquete `syncthing` de los repositorios oficiales de Ubuntu queda
# muy desactualizado (1.27.x, Syncthing 1.x) frente al repositorio APT
# oficial del propio proyecto (`apt.syncthing.net`), que confirmado en
# vivo publica Syncthing 2.x (`v2.1.2` al momento de esta investigación)
# — brecha de versión MAYOR, no menor, así que se prioriza la fuente más
# actualizada (mismo criterio que VirtualBox/Neovim). La clave GPG oficial
# YA viene en formato binario (confirmado en vivo con `curl` + `file`,
# igual que OpenTofu) — usa `apt_vendor_repo_fetch_file_plain`, sin
# `gpg --dearmor`. Línea de repositorio con distro fija `syncthing`/
# componente `stable-v2` (sin depender del codename de Ubuntu, mismo
# patrón que OpenTofu/Google Cloud CLI).

set -Eeuo pipefail

UCI_SYNCTHING_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_SYNCTHING_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_SYNCTHING_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SYNCTHING_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Syncthing"
PACKAGE_NAME="syncthing"
SYNCTHING_KEYRING=/etc/apt/keyrings/syncthing-archive-keyring.gpg
SYNCTHING_REPO_LIST=/etc/apt/sources.list.d/syncthing.list
SYNCTHING_KEY_URL="https://syncthing.net/release-key.gpg"
SYNCTHING_REPO_URL="https://apt.syncthing.net/"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v syncthing &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${SYNCTHING_KEY_URL}" "${SYNCTHING_KEYRING}"
    apt_vendor_repo_write_list "${SYNCTHING_REPO_LIST}" \
        "deb [signed-by=${SYNCTHING_KEYRING}] ${SYNCTHING_REPO_URL} syncthing stable-v2"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${SYNCTHING_REPO_LIST}" "${SYNCTHING_KEYRING}"
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
