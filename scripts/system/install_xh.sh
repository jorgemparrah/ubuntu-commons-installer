#!/usr/bin/env bash
# install_xh.sh
#
# Instalador nuevo (Hito 38, ver docs/ROADMAP.md): agrega xh al catálogo,
# mismo grupo que fzf/thefuck/jq/yq/HTTPie (category=system,
# subcategory=cli-utils).
#
# xh NO está en los repositorios oficiales de Ubuntu ni publica snap
# oficial (confirmado contra la API de Snapcraft: "No snap named 'xh'
# found"). El release más reciente en GitHub tampoco publica ningún
# `.deb` — solo tarballs `.tar.gz` con un binario estático (musl) para
# Linux x86_64, distinto de todo lo demás gestionado hasta ahora en este
# catálogo (apt/apt-vendor-repo/snap/deb-direct/curl-script). Mecanismo
# nuevo: `manager=archive-direct` — descargar un archivo comprimido
# (`.tar.gz` o `.zip`) de GitHub Releases, extraer un único binario y
# dejarlo en `~/.local/bin`. Originalmente `manager=tarball-direct`
# (Hito 38); renombrado a `archive-direct` en el Hito 39 al aparecer un
# segundo caso real (`procs`, que usa `.zip` en vez de `.tar.gz` — ver
# ADR 0032, "esperar un segundo caso real antes de generalizar"). No se
# abstrae a una biblioteca compartida todavía: la lógica de
# descarga/extracción sigue siendo propia de cada script, solo el NOMBRE
# del mecanismo se generalizó. Reutiliza `github_release_asset_url`
# (scripts/lib/github_release.sh) para resolver la URL del asset, y
# `curl_script_uninstall_local_bin` (scripts/lib/curl_script.sh) para la
# desinstalación: el binario queda en `~/.local/bin/xh`, misma
# convención que el grupo curl-script.

set -Eeuo pipefail

UCI_XH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/github_release.sh
source "${UCI_XH_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/curl_script.sh
source "${UCI_XH_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_XH_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="xh"
XH_REPO="ducaale/xh"
XH_BIN_PATH="${HOME}/.local/bin/xh"

# Function to check status
check_status() {
    if ! command -v xh &> /dev/null; then
        echo "NOT_INSTALLED"
        return 1
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    if command -v xh &> /dev/null; then
        echo "${TOOL_NAME} ya está instalado; usa 'reinstall' si querés reinstalarlo." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    local tarball_url
    if ! tarball_url="$(github_release_asset_url "${XH_REPO}" 'xh-v[^"]*-x86_64-unknown-linux-musl\.tar\.gz"')"; then
        echo "No se pudo resolver la URL del último tarball oficial; revisar https://github.com/${XH_REPO}/releases" >&2
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    echo "Descargando ${TOOL_NAME} (${tarball_url})..."
    if ! curl -fsSL "${tarball_url}" -o "${tmp_dir}/xh.tar.gz"; then
        echo "No se pudo descargar ${tarball_url}" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    if ! tar -xzf "${tmp_dir}/xh.tar.gz" -C "${tmp_dir}"; then
        echo "No se pudo extraer el tarball descargado" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    local extracted_bin
    extracted_bin="$(find "${tmp_dir}" -type f -name xh | head -1)"
    if [[ -z "${extracted_bin}" ]]; then
        echo "El tarball descargado no contiene un binario 'xh'; abortando" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    mkdir -p "$(dirname "${XH_BIN_PATH}")"
    cp "${extracted_bin}" "${XH_BIN_PATH}"
    chmod +x "${XH_BIN_PATH}"
    rm -rf "${tmp_dir}"

    echo "${TOOL_NAME} instalado correctamente en ${XH_BIN_PATH}."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "xh"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a resolver la URL del
# último release y descarga de nuevo — es exactamente el comportamiento
# deseado (siempre la versión más reciente).
#
# 'update'/'repair' no se implementan a propósito: no hay forma barata de
# distinguir una versión desactualizada sin volver a consultar la API
# (mismo criterio que el grupo curl-script) — el dispatcher los rechaza
# explícitamente (código 3).

installer_run_cli "$@"
