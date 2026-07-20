#!/usr/bin/env bash
# install_cursor.sh
#
# Instalador migrado en el Hito 11 (grupo vendor-repo) al contrato
# completo de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh, nuevos en esta migración).
#
# Cursor tiene un repositorio APT oficial (downloads.cursor.com/aptrepo),
# con el mecanismo moderno de clave GPG (signed-by + keyring, nunca
# apt-key) y soporte para amd64 y arm64 (ver ADR 0027).
#
# El propio paquete 'cursor' gestiona, en su postinst, su propia entrada
# de repositorio con signed-by=/usr/share/keyrings/anysphere.gpg
# (encontrado al validar en CI: si nuestra entrada manual usa una ruta de
# keyring distinta, apt detecta 'Conflicting values set for option
# Signed-By' para la misma URL/suite y se niega a leer la lista de
# fuentes en CUALQUIER operación posterior, incluido 'apt update' fuera de
# este script). Por eso la clave se escribe directamente en esa misma
# ruta que el paquete espera, en vez de una ruta propia — así, aunque el
# postinst repita la misma entrada, coincide exactamente y no hay
# conflicto.

set -Eeuo pipefail

UCI_CURSOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_CURSOR_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_CURSOR_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CURSOR_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Cursor AI IDE"
PACKAGE_NAME="cursor"
CURSOR_KEYRING=/usr/share/keyrings/anysphere.gpg
CURSOR_REPO_LIST=/etc/apt/sources.list.d/cursor.list

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v cursor &> /dev/null; then
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
    apt_vendor_repo_fetch_key_dearmored "https://downloads.cursor.com/keys/anysphere.asc" "${CURSOR_KEYRING}"
    apt_vendor_repo_write_list "${CURSOR_REPO_LIST}" \
        "deb [arch=amd64,arm64 signed-by=${CURSOR_KEYRING}] https://downloads.cursor.com/aptrepo stable main"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${CURSOR_REPO_LIST}" "${CURSOR_KEYRING}"

    # Limpia también cualquier entrada que el propio paquete pudo haber
    # agregado con un nombre de archivo distinto al nuestro (se confirmó en
    # CI: crea /etc/apt/sources.list.d/cursor.sources en formato Deb822).
    sudo rm -f /etc/apt/sources.list.d/anysphere.list
    sudo rm -f /etc/apt/sources.list.d/cursor.sources

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
