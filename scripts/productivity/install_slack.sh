#!/usr/bin/env bash
# install_slack.sh
#
# Instalador nuevo (Hito 25, ver docs/ROADMAP.md): agrega Slack al
# catálogo. Usa el dispatcher compartido (scripts/lib/installer_cli.sh),
# los helpers APT (scripts/lib/apt.sh) y los helpers de repositorio de
# proveedor (scripts/lib/apt_vendor_repo.sh) — mismo mecanismo
# `apt-vendor-repo` que Docker/VS Code/Cursor/Brave/VirtualBox.
#
# Slack Technologies publica su repositorio oficial hosteado en
# Packagecloud (packagecloud.io/slacktechnologies/slack). Se prioriza
# este repositorio (permite actualizar vía 'apt upgrade') sobre el `.deb`
# de descarga directa que Slack también ofrece — mismo criterio del
# dueño del proyecto de preferir la fuente más "nativa" para
# actualizaciones, no la más simple de descargar una sola vez.
#
# La línea del repositorio usa 'ubuntu trusty' como distro/codename FIJO
# (tal como lo documenta la página oficial de instalación manual de
# Slack/Packagecloud), independiente de la versión real de Ubuntu — no es
# un error ni algo a corregir dinámicamente: Packagecloud sirve los
# mismos paquetes bajo ese path fijo para cualquier versión de Ubuntu.

set -Eeuo pipefail

UCI_SLACK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_SLACK_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_SLACK_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SLACK_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Slack"
PACKAGE_NAME="slack-desktop"
SLACK_KEYRING=/etc/apt/keyrings/slacktechnologies_slack-archive-keyring.gpg
SLACK_REPO_LIST=/etc/apt/sources.list.d/slack.list
SLACK_KEY_URL="https://packagecloud.io/slacktechnologies/slack/gpgkey"
SLACK_REPO_LINE="deb [signed-by=${SLACK_KEYRING}] https://packagecloud.io/slacktechnologies/slack/ubuntu trusty main"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v slack &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "${SLACK_KEY_URL}" "${SLACK_KEYRING}"
    apt_vendor_repo_write_list "${SLACK_REPO_LIST}" "${SLACK_REPO_LINE}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${SLACK_REPO_LIST}" "${SLACK_KEYRING}"
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
