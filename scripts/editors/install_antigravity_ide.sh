#!/usr/bin/env bash
# install_antigravity_ide.sh
#
# Antigravity IDE (Google) — editor de código con IA integrada. Repositorio
# APT propio de Google (us-central1-apt.pkg.dev), mismo mecanismo moderno
# de clave GPG (signed-by + keyring, nunca apt-key) que Docker/VS
# Code/Cursor/Claude Desktop (scripts/lib/apt_vendor_repo.sh, ver ADR
# 0027). Investigado y confirmado en el Hito 16 (2026-07-21): a
# diferencia de lo que se había investigado originalmente (solo tarball
# manual sin checksum/firma, ver ADR 0037), Google sí publica un
# repositorio APT oficial verificable — se descarta la alternativa de
# tarball sin firma en favor de este mecanismo, consistente con el
# estándar de seguridad del proyecto (AGENT.md §16).
#
# Distinto de scripts/development/install_antigravity.sh (el CLI 'agy',
# manager=curl-script, category=development/ai-cli): este instalador es
# solo el IDE/Desktop (category=editors), un producto separado con su
# propio mecanismo de instalación.

set -Eeuo pipefail

UCI_ANTIGRAVITY_IDE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ANTIGRAVITY_IDE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_ANTIGRAVITY_IDE_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ANTIGRAVITY_IDE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Antigravity IDE"
PACKAGE_NAME="antigravity"
ANTIGRAVITY_IDE_KEYRING=/usr/share/keyrings/antigravity.gpg
ANTIGRAVITY_IDE_REPO_LIST=/etc/apt/sources.list.d/antigravity.list

check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

install_tool() {
    echo "Instalando ${TOOL_NAME}..."

    apt_vendor_repo_ensure_gnupg
    apt_vendor_repo_fetch_key_dearmored "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" "${ANTIGRAVITY_IDE_KEYRING}"
    apt_vendor_repo_write_list "${ANTIGRAVITY_IDE_REPO_LIST}" \
        "deb [signed-by=${ANTIGRAVITY_IDE_KEYRING}] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${ANTIGRAVITY_IDE_REPO_LIST}" "${ANTIGRAVITY_IDE_KEYRING}"

    echo "${TOOL_NAME} desinstalado correctamente."
}

update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
