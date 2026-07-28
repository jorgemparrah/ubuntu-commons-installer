#!/usr/bin/env bash
# install_albert.sh
#
# Instalador nuevo (Hito 51, ver docs/ROADMAP.md): agrega Albert al
# catálogo (category=productivity, subcategory=launchers — nueva,
# compartida con ULauncher que se recategoriza en este mismo hito). Usa
# el dispatcher compartido, los helpers APT (scripts/lib/apt.sh) y los
# helpers de repositorio de proveedor (scripts/lib/apt_vendor_repo.sh) —
# mecanismo `apt-vendor-repo` con clave dearmorada + línea 'deb'
# construida a mano.
#
# Albert no está en los repositorios de Ubuntu. El PPA histórico
# (`ppa:nilarimogard/webupd8`) que mencionaba el objetivo del Hito está
# descontinuado; el método oficial actual (albertlauncher.github.io) es
# el repositorio del proyecto en openSUSE Build Service
# (`home:manuelschneid3r`), con URLs versionadas por release de Ubuntu.
# Confirmado en vivo: existen `xUbuntu_24.04` y `xUbuntu_26.04`, la clave
# es ASCII-armored (requiere `gpg --dearmor`) y el repo publica el
# paquete `albert` para amd64 y arm64.
#
# A diferencia de la mayoría de los repos de proveedor de este catálogo,
# la URL del repositorio depende de la versión de Ubuntu (no solo la
# línea 'deb'), así que se construye con el VERSION_ID de /etc/os-release
# — mismo criterio de resolución dinámica que el codename de
# VirtualBox/Terraform, pero sobre el número de versión.

set -Eeuo pipefail

UCI_ALBERT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ALBERT_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_ALBERT_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ALBERT_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Albert"
PACKAGE_NAME="albert"
ALBERT_KEYRING=/usr/share/keyrings/albert-manuelschneid3r.gpg
ALBERT_REPO_LIST=/etc/apt/sources.list.d/albert.list
ALBERT_OBS_BASE="https://download.opensuse.org/repositories/home:manuelschneid3r"

# albert_repo_url
# La URL del repositorio OBS depende de la versión de Ubuntu
# (xUbuntu_24.04 / xUbuntu_26.04), no solo del codename.
albert_repo_url() {
    local version_id
    version_id="$(. /etc/os-release && echo "${VERSION_ID}")"
    echo "${ALBERT_OBS_BASE}/xUbuntu_${version_id}/"
}

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v albert &> /dev/null; then
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

    local repo_url
    repo_url="$(albert_repo_url)"

    apt_vendor_repo_ensure_gnupg
    apt_vendor_repo_fetch_key_dearmored "${repo_url}Release.key" "${ALBERT_KEYRING}"
    apt_vendor_repo_write_list "${ALBERT_REPO_LIST}" \
        "deb [arch=$(dpkg --print-architecture) signed-by=${ALBERT_KEYRING}] ${repo_url} /"

    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo rm -f "${ALBERT_REPO_LIST}" "${ALBERT_KEYRING}"
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
