#!/usr/bin/env bash
# scripts/lib/runtime.sh
#
# Gestor de runtimes centralizado (Hito 8, ver docs/ROADMAP.md y
# docs/adr/0002-mise-como-unico-gestor-runtime.md). Mise es el único
# gestor de runtimes soportado; este módulo es la única forma en la que el
# resto del proyecto (instaladores, migraciones) debe instalar/activar
# runtimes, para que todos se gestionen de forma consistente.
#
# Pensado para cargarse con `source`; no declara `set -Eeuo pipefail`
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_RUNTIME_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_RUNTIME_SH_LOADED=1

UCI_RUNTIME_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_RUNTIME_SCRIPT_DIR
# shellcheck source=logging.sh
source "${UCI_RUNTIME_SCRIPT_DIR}/logging.sh"

# runtime_mise_bin <home_dir>
# Ruta CANÓNICA de instalación de Mise (la que usa su instalador oficial,
# https://mise.run, y por lo tanto la ruta destino de runtime_ensure_mise).
# No es necesariamente dónde está el binario real si Mise se instaló por
# otro medio (paquete del sistema, symlink en /usr/local/bin, etc.) — para
# eso usar runtime_resolve_mise_bin.
runtime_mise_bin() {
    echo "$1/.local/bin/mise"
}

# runtime_resolve_mise_bin <home_dir>
# Resuelve el binario de Mise que realmente está disponible, sea en la ruta
# canónica o en PATH. Imprime la ruta y sale 0 si lo encuentra; no imprime
# nada y sale 1 si no. Antes de esto, runtime.sh y scripts/diagnostics/
# doctor.sh detectaban Mise de forma distinta (uno solo miraba la ruta
# canónica, el otro solo PATH), pudiendo contradecirse sobre la misma
# máquina (ver docs/TECHNICAL_REVIEW.md, hallazgo A3).
runtime_resolve_mise_bin() {
    local home_dir="$1"
    local canonical_bin
    canonical_bin="$(runtime_mise_bin "${home_dir}")"
    if [[ -x "${canonical_bin}" ]]; then
        echo "${canonical_bin}"
        return 0
    fi
    if command -v mise &> /dev/null; then
        command -v mise
        return 0
    fi
    return 1
}

# runtime_mise_available <home_dir>
runtime_mise_available() {
    local home_dir="$1"
    runtime_resolve_mise_bin "${home_dir}" &> /dev/null
}

# runtime_ensure_mise <home_dir>
# Instala Mise si falta. No hace nada si ya está instalado (idempotente).
runtime_ensure_mise() {
    local home_dir="$1"
    local mise_bin
    mise_bin="$(runtime_mise_bin "${home_dir}")"

    if [[ -x "${mise_bin}" ]]; then
        log_debug "Mise ya está instalado en ${mise_bin}"
        return 0
    fi

    log_info "Instalando Mise..."
    if ! curl -fsSL https://mise.run | sh >/dev/null; then
        log_error "No se pudo instalar Mise"
        return 1
    fi

    if [[ ! -x "${mise_bin}" ]]; then
        log_error "Mise no quedó instalado en ${mise_bin} tras el intento de instalación"
        return 1
    fi

    return 0
}

# runtime_cmd <home_dir> <args...>
runtime_cmd() {
    local home_dir="$1"
    shift
    "$(runtime_mise_bin "${home_dir}")" "$@"
}

# runtime_install <home_dir> <mise_tool> <version>
# Ejemplo: runtime_install "$HOME" node 22.11.0
runtime_install() {
    local home_dir="$1" tool="$2" version="$3"
    runtime_cmd "${home_dir}" install "${tool}@${version}"
}

# runtime_use_global <home_dir> <mise_tool> <version>
runtime_use_global() {
    local home_dir="$1" tool="$2" version="$3"
    runtime_cmd "${home_dir}" use --global "${tool}@${version}"
}

# Catálogo de runtimes soportados: nombre legible, id de la herramienta en
# Mise, y el binario esperado una vez activada (para runtime_status). Ver
# docs/ARCHITECTURE.md sección 10 y docs/ROADMAP.md Hito 8.
UCI_RUNTIME_CATALOG=(
    "Node.js:node:node"
    "Python:python:python3"
    "Java:java:java"
    "Go:go:go"
    "Rust:rust:cargo"
)
readonly UCI_RUNTIME_CATALOG

# runtime_status_all <home_dir>
# Reporte de solo lectura: para cada runtime del catálogo, si Mise lo tiene
# activo y qué versión/ruta resuelve. Nunca instala ni modifica nada.
runtime_status_all() {
    local home_dir="$1"

    if ! runtime_mise_available "${home_dir}"; then
        log_warn "Mise no está instalado en ${home_dir}/.local/bin/mise; ningún runtime puede estar gestionado todavía"
        return 0
    fi

    local entry label tool bin_name resolved version
    for entry in "${UCI_RUNTIME_CATALOG[@]}"; do
        label="${entry%%:*}"
        local rest="${entry#*:}"
        tool="${rest%%:*}"
        bin_name="${rest#*:}"

        resolved="$(runtime_cmd "${home_dir}" which "${bin_name}" 2>/dev/null || true)"
        if [[ -n "${resolved}" ]]; then
            version="$(runtime_cmd "${home_dir}" current "${tool}" 2>/dev/null | tr '\n' ' ' || true)"
            printf '%-10s %-14s gestionado por Mise (%s) — %s\n' "${label}" "[${tool}]" "${resolved}" "${version:-versión desconocida}"
        else
            printf '%-10s %-14s no gestionado por Mise\n' "${label}" "[${tool}]"
        fi
    done
    return 0
}
