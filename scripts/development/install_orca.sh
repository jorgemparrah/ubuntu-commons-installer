#!/usr/bin/env bash
# install_orca.sh
#
# Instalador nuevo (Hito 55, ver docs/ROADMAP.md): agrega Orca al
# catálogo (category=ai, subcategory=ai-ide, mismo grupo que Cursor y
# Antigravity IDE). ADE (Agent Development Environment) de escritorio
# para orquestar varios agentes de codificación en paralelo, cada uno en
# su propio git worktree.
#
# Mecanismo `deb-direct` con la URL resuelta dinámicamente contra el
# último release del repo oficial (stablyai/orca), mismo patrón que
# LocalSend/Lutris/Heroic/DbGate: el nombre del asset trae la versión
# embebida (`orca-ide_1.4.159_amd64.deb`), así que no hay una URL
# "latest" estable y hay que consultar la API de GitHub Releases.
#
# Verificado en vivo el 2026-07-28 sobre el `.deb` real del release
# v1.4.159 (descargado e inspeccionado con `dpkg-deb`, sin instalarlo):
#
#   * Licencia MIT (archivo LICENSE real del repo, Lovecast Inc.), repo
#     activo. Se prefiere el `.deb` sobre el AppImage que también publica,
#     por integración con el sistema (menú de aplicaciones y PATH).
#   * El paquete se llama `orca-ide`, NO `orca`: Ubuntu ya tiene un
#     paquete `orca` en sus repos oficiales (el lector de pantalla de
#     GNOME, presente tanto en 24.04 como en 26.04). Upstream renombró el
#     ejecutable a propósito por esa razón — el comentario está en su
#     propio shim ("avoids Ubuntu GNOME Orca conflict"). Por eso acá el
#     paquete, el binario y el id del catálogo hablan siempre de
#     `orca-ide`/`orca_ide`: instalar esto NO pisa ni desinstala el lector
#     de pantalla, que es software de accesibilidad y podría estar en uso.
#   * El binario en el PATH (`/usr/bin/orca-ide`) NO viene dentro del
#     paquete: lo crea el `postinst` como symlink hacia
#     `/opt/Orca/resources/bin/orca-ide`. Por eso `check_status` lo trata
#     como parte de la instalación sana y `repair` reinstala el paquete
#     (que vuelve a correr el `postinst`) en vez de intentar recrear el
#     symlink a mano. El `postrm` lo elimina, pero solo si sigue
#     apuntando dentro del directorio de Orca.
#   * No necesita ningún runtime externo no gestionado: es una app
#     Electron y su CLI corre con `ELECTRON_RUN_AS_NODE` sobre el propio
#     binario empaquetado, sin depender del Node del sistema ni de Mise.
#   * Depende de paquetes de los repos de Ubuntu (`python3`,
#     `python3-gi`, `gir1.2-atspi-2.0`, `at-spi2-core`, `xdotool`,
#     `xclip`, `xvfb`), todos publicados en 24.04 y 26.04 (varios en
#     `universe`). Los resuelve APT al instalar el `.deb` local, no hace
#     falta declararlos acá.

set -Eeuo pipefail

UCI_ORCA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_ORCA_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_ORCA_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_ORCA_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_ORCA_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Orca"
PACKAGE_NAME="orca-ide"
UCI_ORCA_REPO="stablyai/orca"
UCI_ORCA_BIN="orca-ide"
UCI_ORCA_DEB_NAME="orca-ide.deb"
# Solo el asset amd64: el release publica también arm64 (.deb y .rpm) y
# el patrón debe excluirlos. Confirmado en vivo que matchea exactamente
# un asset en el último release.
UCI_ORCA_ASSET_PATTERN='_amd64\.deb"'

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    # El symlink en el PATH lo crea el postinst, no el paquete: si falta,
    # el paquete está instalado pero la CLI es inalcanzable.
    if ! command -v "${UCI_ORCA_BIN}" &> /dev/null; then
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

    local deb_url
    if ! deb_url="$(github_release_asset_url "${UCI_ORCA_REPO}" "${UCI_ORCA_ASSET_PATTERN}")"; then
        echo "No se pudo resolver la URL del último .deb oficial; revisar https://github.com/${UCI_ORCA_REPO}/releases" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${UCI_ORCA_DEB_NAME}"; then
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${UCI_ORCA_DEB_NAME}"; then
        rm -f "${UCI_ORCA_DEB_NAME}"
        return 1
    fi

    rm -f "${UCI_ORCA_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
# Purga únicamente 'orca-ide'. El paquete 'orca' de Ubuntu (lector de
# pantalla de GNOME) es otra herramienta y no se toca.
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a resolver la URL del
# último release y descarga de nuevo — es exactamente el comportamiento
# deseado (siempre la versión más reciente disponible).

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
# Reinstala el paquete en vez de recrear el symlink a mano: el postinst
# es el dueño de '/usr/bin/orca-ide' y volver a correrlo es la forma
# soportada de restaurarlo.
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
