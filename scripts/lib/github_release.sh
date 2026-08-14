#!/usr/bin/env bash
# scripts/lib/github_release.sh
#
# Helper compartido para instaladores que descargan un asset directo
# desde el último release de GitHub de un proyecto (Hito 28/29: SoapUI,
# LocalSend), cuando el nombre del asset trae la versión embebida (sin
# alias "latest" estable en la URL de descarga directa) — a diferencia
# de Discord (que sí publica un endpoint "siempre la última versión") o
# MongoDB Compass (que fija una versión exacta, riesgo aceptado
# documentado ahí). Segundo caso real de este patrón (ver ADR 0032:
# "esperar un segundo caso real antes de abstraerlo"), justifica
# extraerlo en vez de duplicarlo en cada instalador.
#
# No requiere `jq`: la API de GitHub Releases entrega cada par
# clave/valor en su propia coincidencia de 'grep -oE', sin importar si la
# respuesta viene minificada o "pretty" — suficiente para este caso (no
# se necesita un parser JSON completo).
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_GITHUB_RELEASE_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_GITHUB_RELEASE_SH_LOADED=1

# github_release_asset_url <owner/repo> <patrón_nombre_asset>
# Consulta 'releases/latest' de la API de GitHub y devuelve la
# 'browser_download_url' del primer asset cuyo nombre matchea
# <patrón_nombre_asset> (grep -E). Vacío (y código de error) si no
# encuentra ninguno o la API no responde.
github_release_asset_url() {
    local repo="$1" name_pattern="$2"
    local json

    if ! json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"; then
        echo "No se pudo consultar la API de GitHub Releases para ${repo}" >&2
        return 1
    fi

    local url
    url="$(echo "${json}" | grep -oE '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' | grep -E "${name_pattern}" | head -1 | sed -E 's/.*"(https:[^"]+)"$/\1/')"

    if [[ -z "${url}" ]]; then
        echo "No se encontró ningún asset que coincida con '${name_pattern}' en el último release de ${repo}" >&2
        return 1
    fi

    echo "${url}"
}
