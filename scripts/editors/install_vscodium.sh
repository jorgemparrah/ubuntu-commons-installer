#!/usr/bin/env bash
# install_vscodium.sh
#
# Instalador nuevo (Hito 34, ver docs/ROADMAP.md): agrega VSCodium al
# catálogo, mismo grupo que Visual Studio Code (category=editors,
# subcategory=gui-editors). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mismo mecanismo `apt-vendor-repo` que
# Brave: publica su clave ya lista para `signed-by` (sin `gpg --dearmor`)
# y un archivo `.sources` completo en formato DEB822
# (`repo.vscodium.dev/vscodium.sources`), confirmado en vivo — endpoint
# moderno recomendado por el propio proyecto para Ubuntu 24.04+, distinto
# del método clásico anterior (gitlab.com/paulcarroty/...).
#
# VSCodium es el mismo binario de VS Code, compilado sin la telemetría ni
# la marca registrada de Microsoft. Paquete: `codium`. Binario resultante:
# `codium` (no `vscodium`, confirmado).

set -Eeuo pipefail

UCI_VSCODIUM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_VSCODIUM_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_VSCODIUM_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_VSCODIUM_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="VSCodium"
PACKAGE_NAME="codium"
VSCODIUM_KEYRING=/usr/share/keyrings/vscodium.gpg
VSCODIUM_SOURCES_LIST=/etc/apt/sources.list.d/vscodium.sources
VSCODIUM_KEY_URL="https://repo.vscodium.dev/vscodium.gpg"
VSCODIUM_SOURCES_URL="https://repo.vscodium.dev/vscodium.sources"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v codium &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${VSCODIUM_KEY_URL}" "${VSCODIUM_KEYRING}"
    apt_vendor_repo_fetch_file_plain "${VSCODIUM_SOURCES_URL}" "${VSCODIUM_SOURCES_LIST}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${VSCODIUM_SOURCES_LIST}" "${VSCODIUM_KEYRING}"
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
