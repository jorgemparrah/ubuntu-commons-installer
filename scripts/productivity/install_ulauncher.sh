#!/usr/bin/env bash
# install_ulauncher.sh
#
# Instalador migrado en el Hito 11 (siguiente grupo apt-simple tras la
# Fase 2, ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher y los helpers APT compartidos, mismo patrón que
# scripts/system/install_ranger.sh — con una diferencia real: ULauncher no
# está en los repositorios oficiales de Ubuntu, así que `install`/`uninstall`
# agregan/quitan el PPA oficial del proyecto antes/después de instalar el
# paquete (ver ADR 0027, categoría "solo disponible comunitario"), algo que
# ningún otro instalador apt-simple migrado hasta ahora necesitaba.
#
# ppa:agornostal/ulauncher, mantenido por su autor/maintainer principal,
# documentado en https://ulauncher.io como método de instalación oficial
# para Ubuntu/Debian.
#
# Semántica de los 6 verbos:
#   status    — igual que install_ranger.sh (NOT_INSTALLED/BROKEN/OUTDATED/
#               INSTALLED vía apt_package_installed + 'command -v ulauncher'
#               + 'apt list --upgradable'), sin lógica de PPA: el PPA es un
#               detalle de instalación, no de estado.
#   install   — si `add-apt-repository` no existe, instala primero
#               software-properties-common; agrega 'universe' y el PPA;
#               instala 'ulauncher' vía apt_install_packages. Rechaza sobre
#               BROKEN (pide 'repair').
#   uninstall — apt_purge_packages (purge, no remove — antes de esta
#               migración usaba 'apt remove', que dejaba el paquete en
#               estado residual 'rc') y quita el PPA.
#   reinstall — 'apt-get install --reinstall' directo, sin tocar el PPA (ya
#               debe estar agregado si el paquete está instalado).
#   update    — 'apt-get update' + 'apt-get install --only-upgrade', solo
#               este paquete.
#   repair    — 'dpkg --configure -a' + 'apt-get install -f' + reinstalación
#               forzada, igual que install_ranger.sh. Rechaza sobre
#               NOT_INSTALLED.

set -Eeuo pipefail

UCI_ULAUNCHER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ULAUNCHER_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ULAUNCHER_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="ULauncher"
PACKAGE_NAME="ulauncher"
UCI_ULAUNCHER_PPA="ppa:agornostal/ulauncher"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v ulauncher &> /dev/null; then
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

    if ! command -v add-apt-repository &> /dev/null; then
        apt_install_packages "software-properties-common"
    fi

    sudo add-apt-repository -y universe
    sudo add-apt-repository -y "${UCI_ULAUNCHER_PPA}"
    apt_install_packages "${PACKAGE_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    sudo add-apt-repository -y --remove "${UCI_ULAUNCHER_PPA}"
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
