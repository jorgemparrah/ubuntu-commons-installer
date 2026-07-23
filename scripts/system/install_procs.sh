#!/usr/bin/env bash
# install_procs.sh
#
# Instalador nuevo (Hito 39, ver docs/ROADMAP.md): agrega procs al
# catálogo, mismo grupo que fzf/thefuck/jq/yq/HTTPie/xh/duf/btop/zoxide/
# tealdeer/dust (category=system, subcategory=cli-utils).
#
# procs NO está en apt/snap de Ubuntu ni publica un `.deb` (confirmado en
# vivo: solo `.rpm` y archivos `.zip` en GitHub Releases, ningún
# `.tar.gz`). Segundo caso real del mecanismo `manager=archive-direct`
# (el primero fue xh, con `.tar.gz` — ver install_xh.sh): descarga un
# `.zip` con un único binario suelto en la raíz (a diferencia del
# tarball de xh, que trae el binario dentro de un subdirectorio con
# nombre versionado), lo extrae con `unzip` (instalado primero si no
# está presente — no viene por defecto en todas las instalaciones) y lo
# deja en `~/.local/bin/procs`. Reutiliza `github_release_asset_url`
# (scripts/lib/github_release.sh) para resolver la URL y
# `curl_script_uninstall_local_bin` (scripts/lib/curl_script.sh) para la
# desinstalación, mismo criterio que xh.

set -Eeuo pipefail

UCI_PROCS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_PROCS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/github_release.sh
source "${UCI_PROCS_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/curl_script.sh
source "${UCI_PROCS_SCRIPT_DIR}/../lib/curl_script.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_PROCS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="procs"
PROCS_REPO="dalance/procs"
PROCS_BIN_PATH="${HOME}/.local/bin/procs"

# Function to check status
check_status() {
    if ! command -v procs &> /dev/null; then
        echo "NOT_INSTALLED"
        return 1
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    if command -v procs &> /dev/null; then
        echo "${TOOL_NAME} ya está instalado; usa 'reinstall' si querés reinstalarlo." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    if ! command -v unzip &> /dev/null; then
        apt_install_packages unzip
    fi

    local zip_url
    if ! zip_url="$(github_release_asset_url "${PROCS_REPO}" 'procs-v[^"]*-x86_64-linux\.zip"')"; then
        echo "No se pudo resolver la URL del último .zip oficial; revisar https://github.com/${PROCS_REPO}/releases" >&2
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    echo "Descargando ${TOOL_NAME} (${zip_url})..."
    if ! curl -fsSL "${zip_url}" -o "${tmp_dir}/procs.zip"; then
        echo "No se pudo descargar ${zip_url}" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    if ! unzip -oq "${tmp_dir}/procs.zip" -d "${tmp_dir}"; then
        echo "No se pudo extraer el zip descargado" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    if [[ ! -f "${tmp_dir}/procs" ]]; then
        echo "El zip descargado no contiene un binario 'procs' en la raíz; abortando" >&2
        rm -rf "${tmp_dir}"
        return 1
    fi

    mkdir -p "$(dirname "${PROCS_BIN_PATH}")"
    cp "${tmp_dir}/procs" "${PROCS_BIN_PATH}"
    chmod +x "${PROCS_BIN_PATH}"
    rm -rf "${tmp_dir}"

    echo "${TOOL_NAME} instalado correctamente en ${PROCS_BIN_PATH}."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    curl_script_uninstall_local_bin "${HOME}" "procs"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# 'reinstall' no define función propia: el fallback mecánico del
# dispatcher (uninstall_tool + install_tool) vuelve a resolver la URL del
# último release y descarga de nuevo — es exactamente el comportamiento
# deseado.
#
# 'update'/'repair' no se implementan a propósito, mismo criterio que xh
# (el dispatcher los rechaza explícitamente, código 3).

installer_run_cli "$@"
