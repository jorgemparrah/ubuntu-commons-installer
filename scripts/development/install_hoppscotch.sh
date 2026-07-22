#!/usr/bin/env bash
# install_hoppscotch.sh
#
# Instalador nuevo (Hito 31, ver docs/ROADMAP.md): agrega Hoppscotch al
# catálogo, mismo grupo que Postman/Insomnia/SoapUI/Bruno
# (category=development, subcategory=api-clients). Usa el dispatcher
# compartido, los helpers APT (scripts/lib/apt.sh) y los helpers de
# descarga directa de `.deb` (scripts/lib/deb_direct.sh).
#
# App de escritorio oficial basada en Tauri (repo separado
# github.com/hoppscotch/releases, distinto del repo principal
# hoppscotch/hoppscotch).
#
# NO se usa `scripts/lib/github_release.sh` (que solo consulta
# 'releases/latest'), ni el endpoint fijo
# ".../releases/latest/download/Hoppscotch_linux_x64.deb" que documenta
# el propio proyecto: se confirmó en vivo (2026-07-22) que el release
# "latest" en ese momento (v26.6.1-0) es un hotfix que solo publica el
# asset "SelfHost" (para autohospedar el backend, un producto distinto),
# sin el `.deb` de la app de escritorio normal — el endpoint fijo
# devuelve 404 en ese caso. Por eso 'hoppscotch_resolve_deb_url' recorre
# la lista completa de releases (`/releases`, no `/releases/latest`) y
# toma el primero (más reciente primero, orden por defecto de la API)
# que sí publique el asset de escritorio, evitando explícitamente
# cualquier asset "SelfHost". Caso único hasta ahora — no se abstrae a
# scripts/lib/github_release.sh (ver criterio de ADR 0032, "esperar un
# segundo caso real").
#
# El paquete .deb se llama "hoppscotch" (confirmado inspeccionando
# metadata del .deb real, dpkg-deb -f), pero el binario que instala es
# "hoppscotch-desktop", no "hoppscotch" — verificado inspeccionando el
# contenido del paquete (dpkg-deb -c).

set -Eeuo pipefail

UCI_HOPPSCOTCH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_HOPPSCOTCH_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/deb_direct.sh
source "${UCI_HOPPSCOTCH_SCRIPT_DIR}/../lib/deb_direct.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_HOPPSCOTCH_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Hoppscotch"
PACKAGE_NAME="hoppscotch"
HOPPSCOTCH_DEB_NAME="hoppscotch.deb"
HOPPSCOTCH_REPO="hoppscotch/releases"

# hoppscotch_resolve_deb_url
# Recorre los releases recientes de HOPPSCOTCH_REPO (no solo el
# "latest") y devuelve la browser_download_url del primer
# Hoppscotch_linux_x64.deb que encuentre, saltando releases que solo
# publican el asset "SelfHost" (cuyo nombre de archivo es
# "Hoppscotch_SelfHost_linux_x64.deb" — no matchea el patrón porque
# exige que "/Hoppscotch_linux_x64.deb" sea el final exacto de la URL).
hoppscotch_resolve_deb_url() {
    local json
    if ! json="$(curl -fsSL "https://api.github.com/repos/${HOPPSCOTCH_REPO}/releases?per_page=10")"; then
        echo "No se pudo consultar la API de GitHub Releases para ${HOPPSCOTCH_REPO}" >&2
        return 1
    fi

    local url
    url="$(echo "${json}" \
        | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*/Hoppscotch_linux_x64\.deb"' \
        | head -1 \
        | sed -E 's/.*"(https:[^"]+)"$/\1/')"

    if [[ -z "${url}" ]]; then
        echo "No se encontró ningún release reciente de ${HOPPSCOTCH_REPO} con el asset de escritorio (Hoppscotch_linux_x64.deb)" >&2
        return 1
    fi

    echo "${url}"
}

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v hoppscotch-desktop &> /dev/null; then
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
    if ! deb_url="$(hoppscotch_resolve_deb_url)"; then
        echo "No se pudo resolver la URL del .deb oficial; revisar https://hoppscotch.io/download" >&2
        return 1
    fi

    echo "Descargando ${TOOL_NAME} (${deb_url})..."
    if ! deb_direct_download "${deb_url}" "${HOPPSCOTCH_DEB_NAME}"; then
        echo "No se pudo descargar el .deb oficial desde ${deb_url}" >&2
        return 1
    fi

    echo "Instalando el paquete descargado..."
    if ! apt_install_packages "./${HOPPSCOTCH_DEB_NAME}"; then
        rm -f "${HOPPSCOTCH_DEB_NAME}"
        return 1
    fi

    rm -f "${HOPPSCOTCH_DEB_NAME}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) resuelve y descarga de
# nuevo el .deb más reciente, que es exactamente el comportamiento
# deseado.

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
