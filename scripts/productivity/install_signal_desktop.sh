#!/usr/bin/env bash
# install_signal_desktop.sh
#
# Instalador nuevo (Hito 36, ver docs/ROADMAP.md): agrega Signal Desktop
# al catálogo, mismo grupo que Slack/Discord/Telegram Desktop/Zoom/Element
# (category=productivity, subcategory=communication). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh) y los helpers de
# repositorio de proveedor (scripts/lib/apt_vendor_repo.sh).
#
# Primer instalador de este proyecto que combina AMBOS sub-mecanismos de
# apt_vendor_repo.sh en un mismo instalador: la clave GPG oficial viene en
# formato ASCII-armored y requiere 'gpg --dearmor'
# (apt_vendor_repo_fetch_key_dearmored, mismo que VirtualBox/Slack), pero
# el archivo de repositorio SÍ viene completo en formato DEB822
# (apt_vendor_repo_fetch_file_plain, mismo que Brave/VSCodium) — no hace
# falta construir una línea 'deb [...]' a mano. El propio `.sources`
# oficial fija la ruta del keyring en
# `/usr/share/keyrings/signal-desktop-keyring.gpg` (confirmado en vivo),
# así que ese es el path exacto donde este instalador debe dejar la clave
# para que coincidan.

set -Eeuo pipefail

UCI_SIGNAL_DESKTOP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_SIGNAL_DESKTOP_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_SIGNAL_DESKTOP_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SIGNAL_DESKTOP_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Signal Desktop"
PACKAGE_NAME="signal-desktop"
SIGNAL_KEYRING=/usr/share/keyrings/signal-desktop-keyring.gpg
SIGNAL_SOURCES_LIST=/etc/apt/sources.list.d/signal-desktop.sources
SIGNAL_KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
SIGNAL_SOURCES_URL="https://updates.signal.org/static/desktop/apt/signal-desktop.sources"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v signal-desktop &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${SIGNAL_KEY_URL}" "${SIGNAL_KEYRING}"
    apt_vendor_repo_fetch_file_plain "${SIGNAL_SOURCES_URL}" "${SIGNAL_SOURCES_LIST}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${SIGNAL_SOURCES_LIST}" "${SIGNAL_KEYRING}"
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
