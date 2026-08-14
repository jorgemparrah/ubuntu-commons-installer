#!/usr/bin/env bash
# install_claude_desktop.sh
#
# Claude Desktop (Anthropic), incluye Cowork — agente de propósito
# general con app de escritorio (ver
# docs/adr/0036-candidatas-de-ia-en-categorias-existentes.md). Repositorio
# APT propio de Anthropic (downloads.claude.ai/claude-desktop/apt/stable),
# mismo mecanismo moderno de clave GPG (signed-by + keyring, nunca
# apt-key) que Docker/VS Code/Cursor (scripts/lib/apt_vendor_repo.sh, ver
# ADR 0027). Cowork requiere KVM, ~25 GB de disco y 8 GB de RAM — este
# instalador no valida esos requisitos, solo instala el paquete; si
# faltan, la propia app es responsable de advertirlo al abrir Cowork.
# Clasificación `optional` confirmada con el dueño del proyecto (Hito 16).

set -Eeuo pipefail

UCI_CLAUDE_DESKTOP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_CLAUDE_DESKTOP_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_CLAUDE_DESKTOP_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CLAUDE_DESKTOP_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Claude Desktop"
PACKAGE_NAME="claude-desktop"
CLAUDE_DESKTOP_KEYRING=/usr/share/keyrings/claude-desktop.gpg
# La ruta anterior (apt/keys/claude-desktop.asc) empezó a devolver 404:
# detectado en la primera ejecución real (2026-08-14, ver docs/ROADMAP.md
# Hito 19), donde el instalador fallaba con "no se han encontrados datos
# OpenPGP válidos". Esta es la que documenta Anthropic hoy; se verificó en
# vivo que responde 200 y que la huella de la clave es
# 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE, la publicada oficialmente.
CLAUDE_DESKTOP_KEY_URL="https://downloads.claude.ai/claude-desktop/key.asc"
CLAUDE_DESKTOP_REPO_LIST=/etc/apt/sources.list.d/claude-desktop.list

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
    apt_vendor_repo_fetch_key_dearmored "${CLAUDE_DESKTOP_KEY_URL}" "${CLAUDE_DESKTOP_KEYRING}"
    apt_vendor_repo_write_list "${CLAUDE_DESKTOP_REPO_LIST}" \
        "deb [arch=amd64,arm64 signed-by=${CLAUDE_DESKTOP_KEYRING}] https://downloads.claude.ai/claude-desktop/apt/stable stable main"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${CLAUDE_DESKTOP_REPO_LIST}" "${CLAUDE_DESKTOP_KEYRING}"

    echo "${TOOL_NAME} desinstalado correctamente."
}

update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    apt_update || true
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
