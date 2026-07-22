#!/usr/bin/env bash
# install_discord.sh
#
# Instalador nuevo (Hito 25, ver docs/ROADMAP.md): agrega Discord al
# catálogo. Usa el dispatcher compartido (scripts/lib/installer_cli.sh),
# los helpers APT (scripts/lib/apt.sh) y los helpers de descarga directa
# de `.deb` (scripts/lib/deb_direct.sh) — mismo mecanismo `deb-direct` que
# Chrome/MongoDB Compass.
#
# Discord Inc. no publica un repositorio APT oficial, solo un `.deb` de
# descarga directa. A diferencia de MongoDB Compass (que fija una versión
# exacta en la URL, con el riesgo aceptado documentado ahí), Discord sí
# publica un endpoint estable que siempre resuelve a la última versión
# (https://discord.com/api/download?platform=linux&format=deb) — no hace
# falta fijar ni scrapear ningún número de versión.

set -Eeuo pipefail

UCI_DISCORD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_DISCORD_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_DISCORD_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_DISCORD_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Discord"
PACKAGE_NAME="discord"
DISCORD_DEB_NAME="discord.deb"
DISCORD_DEB_URL="https://discord.com/api/download?platform=linux&format=deb"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v discord &> /dev/null; then
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

    echo "Descargando ${TOOL_NAME}..."
    if ! deb_direct_download "${DISCORD_DEB_URL}" "${DISCORD_DEB_NAME}"; then
        echo "No se pudo descargar el .deb oficial; revisar https://discord.com/download" >&2
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${DISCORD_DEB_NAME}"; then
        rm -f "${DISCORD_DEB_NAME}"
        return 1
    fi

    rm -f "${DISCORD_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) descarga de nuevo el .deb
# más reciente, que es exactamente el comportamiento deseado (a
# diferencia de un 'apt-get install --reinstall' que reinstalaría la
# misma versión ya presente).

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
