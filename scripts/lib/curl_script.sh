#!/usr/bin/env bash
# scripts/lib/curl_script.sh
#
# Helpers compartidos para instaladores que corren el script oficial de
# instalación de una CLI vía 'curl | bash/sh' (Hito 16: Claude Code, Codex
# CLI, OpenCode, OpenClaw, Hermes Agent, Antigravity CLI — ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md). Hermano de
# scripts/lib/apt.sh/snap.sh/apt_vendor_repo.sh/deb_direct.sh/git_clone.sh
# para este mecanismo.
#
# Descarga a un archivo temporal y lo ejecuta después, en vez de un pipe
# directo ('curl ... | bash'): funcionalmente equivalente para estos
# instaladores no interactivos, pero permite mockear 'curl' en las
# pruebas sin invocar un intérprete real contra una URL falsa.
#
# Convención asumida para 'uninstall' (documentada en cada instalador que
# la usa, no una API oficial de estos proyectos): estos instaladores no
# publican un 'uninstall' oficial propio, así que se remueve el binario
# instalado en la ruta ya conocida (~/.local/bin/<binario>) — limitación
# honesta, no una desinstalación completa garantizada por el proveedor.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_CURL_SCRIPT_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_CURL_SCRIPT_SH_LOADED=1

# curl_script_installed <binario>
# 0 si <binario> resuelve en PATH.
curl_script_installed() {
    local binario="$1"
    command -v "${binario}" >/dev/null 2>&1
}

# curl_script_run <url> <interprete: bash|sh>
# Descarga <url> a un archivo temporal y lo corre con <interprete>.
# Limpia el archivo temporal en cualquier caso (éxito o error).
curl_script_run() {
    local url="$1" interprete="$2"
    local tmp_script
    tmp_script="$(mktemp)"

    if ! curl -fsSL "${url}" -o "${tmp_script}"; then
        echo "No se pudo descargar el script de instalación desde ${url}" >&2
        rm -f "${tmp_script}"
        return 1
    fi
    if [[ ! -s "${tmp_script}" ]]; then
        echo "El script descargado desde ${url} quedó vacío; abortando" >&2
        rm -f "${tmp_script}"
        return 1
    fi

    "${interprete}" "${tmp_script}"
    local exit_code=$?
    rm -f "${tmp_script}"
    return "${exit_code}"
}

# curl_script_uninstall_local_bin <home_dir> <binario>
# Remueve <home_dir>/.local/bin/<binario> si existe. Ver nota de
# "uninstall" arriba: es la única ruta de desinstalación documentada,
# ya que estos proyectos no publican un 'uninstall' oficial propio.
curl_script_uninstall_local_bin() {
    local home_dir="$1" binario="$2"
    local bin_path="${home_dir}/.local/bin/${binario}"

    if [[ -e "${bin_path}" ]]; then
        rm -f "${bin_path}"
    fi
}
