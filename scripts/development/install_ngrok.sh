#!/usr/bin/env bash
# install_ngrok.sh
#
# Instalador nuevo (Hito 28, ver docs/ROADMAP.md): agrega ngrok al
# catálogo. Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh) — mecanismo `apt-vendor-repo`, mismo
# patrón que Brave (clave ya lista para 'signed-by', sin 'gpg --dearmor').
#
# ngrok Inc. publica su repositorio oficial directamente
# (ngrok-agent.s3.amazonaws.com). La línea del repositorio usa
# 'bookworm' (codename de Debian, no de Ubuntu) como distro/codename FIJO
# — mismo patrón ya visto con Slack ('ubuntu trusty') y OnlyOffice
# ('debian squeeze'), no es un error ni algo a corregir dinámicamente. La
# documentación oficial usa /etc/apt/trusted.gpg.d/ sin 'signed-by'
# explícito; acá se adapta al patrón ya establecido en este proyecto
# (keyring propio en /usr/share/keyrings/ + 'signed-by' explícito), sin
# cambiar la fuente real de la clave/repo.

set -Eeuo pipefail

UCI_NGROK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_NGROK_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_NGROK_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_NGROK_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="ngrok"
PACKAGE_NAME="ngrok"
NGROK_KEYRING=/usr/share/keyrings/ngrok-archive-keyring.gpg
NGROK_REPO_LIST=/etc/apt/sources.list.d/ngrok.list
NGROK_KEY_URL="https://ngrok-agent.s3.amazonaws.com/ngrok.asc"
NGROK_REPO_LINE="deb [signed-by=${NGROK_KEYRING}] https://ngrok-agent.s3.amazonaws.com bookworm main"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v ngrok &> /dev/null; then
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

    apt_vendor_repo_fetch_file_plain "${NGROK_KEY_URL}" "${NGROK_KEYRING}"
    apt_vendor_repo_write_list "${NGROK_REPO_LIST}" "${NGROK_REPO_LINE}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${NGROK_REPO_LIST}" "${NGROK_KEYRING}"
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
