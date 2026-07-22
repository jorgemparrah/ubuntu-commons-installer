#!/usr/bin/env bash
# install_libreoffice.sh
#
# Instalador nuevo (Hito 26, ver docs/ROADMAP.md): agrega LibreOffice al
# catálogo. Usa el dispatcher y los helpers APT compartidos, mismo patrón
# apt-simple que install_ranger.sh.
#
# The Document Foundation mantiene un PPA propio ("Fresh PPA",
# ppa:libreoffice/ppa), pero su propia documentación lo describe
# explícitamente como testing/bleeding edge, "no recomendado para el
# usuario promedio sin revisar antes" — excepción consciente al criterio
# de priorizar siempre la fuente más actualizada (acá "más fresco"
# significa menos estable, por diseño del propio mantenedor, no por
# desactualización). LibreOffice ya viene preinstalado en casi todas las
# imágenes Desktop de Ubuntu vía el repositorio oficial; para una suite
# ofimática, la estabilidad de formatos pesa más que la última función.
# Se usa el paquete `libreoffice` de los repositorios oficiales de
# Ubuntu.

set -Eeuo pipefail

UCI_LIBREOFFICE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_LIBREOFFICE_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_LIBREOFFICE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="LibreOffice"
PACKAGE_NAME="libreoffice"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v libreoffice &> /dev/null; then
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
    apt_install_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
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
