#!/usr/bin/env bash
# install_vscode.sh
#
# Instalador migrado en el Hito 11 (grupo vendor-repo) al contrato
# completo de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh, nuevos en esta migración).
#
# Repo APT oficial de Microsoft, con signed-by + keyring (nunca apt-key).
# Hallazgos ya corregidos en el Hito 9, preservados por esta migración:
#   1) gpg --dearmor requiere el paquete gnupg, no se puede asumir presente;
#   2) sin comprobar el resultado, un curl/gpg fallido deja un keyring
#      vacío en silencio (NO_PUBKEY recién en 'apt update');
#   3) 'dpkg -l' con 'ii' distingue el estado "config-files" remanente que
#      deja 'apt purge' de instalado de verdad.

set -Eeuo pipefail

UCI_VSCODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_VSCODE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_VSCODE_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_VSCODE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Visual Studio Code"
PACKAGE_NAME="code"
VSCODE_KEYRING=/etc/apt/keyrings/packages.microsoft.gpg
VSCODE_REPO_LIST=/etc/apt/sources.list.d/vscode.list

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v code &> /dev/null; then
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

    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections

    apt_vendor_repo_ensure_gnupg
    apt_vendor_repo_fetch_key_dearmored "https://packages.microsoft.com/keys/microsoft.asc" "${VSCODE_KEYRING}"
    apt_vendor_repo_write_list "${VSCODE_REPO_LIST}" \
        "deb [arch=amd64,arm64,armhf signed-by=${VSCODE_KEYRING}] https://packages.microsoft.com/repos/code stable main"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${VSCODE_REPO_LIST}" "${VSCODE_KEYRING}"
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
