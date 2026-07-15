#!/usr/bin/env bash
# scripts/bootstrap/preflight.sh
#
# Verificaciones de preflight de solo lectura: no instalan ni modifican nada.
# Ver docs/ROADMAP.md (Hito 2: Bootstrap) y docs/adr/0001-bootstrap-bash-sin-node.md.
#
# Distingue dos categorías de requisitos:
#   1. preflight_core        -> necesarios para los comandos Bash (help, version,
#                                y a futuro doctor/status/backup/migrate).
#   2. preflight_interactive -> necesarios únicamente para el modo interactivo
#                                (setup.js). La ausencia de Node.js NUNCA debe
#                                bloquear preflight_core, `help` ni `version`.
#
# Pensada para cargarse con `source`; no declara `set -Eeuo pipefail` por el
# mismo motivo que scripts/lib/logging.sh: quien controla el modo estricto es
# el script que se ejecuta (setup.sh).

if [[ "${UCI_PREFLIGHT_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_PREFLIGHT_SH_LOADED=1

UCI_PREFLIGHT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_PREFLIGHT_SCRIPT_DIR
# shellcheck source=../lib/logging.sh
source "${UCI_PREFLIGHT_SCRIPT_DIR}/../lib/logging.sh"

preflight_check_os() {
    local os
    os="$(uname -s)"
    if [[ "${os}" != "Linux" ]]; then
        log_error "Sistema operativo no soportado: ${os} (se requiere Linux)"
        return 1
    fi
    log_debug "Sistema operativo: ${os}"
    return 0
}

preflight_check_bash() {
    if [[ -z "${BASH_VERSION:-}" ]]; then
        log_error "Este proyecto requiere Bash"
        return 1
    fi
    log_debug "Bash: ${BASH_VERSION}"
    return 0
}

preflight_check_apt() {
    if command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
        log_debug "Gestor de paquetes apt/apt-get disponible"
        return 0
    fi
    log_error "No se encontró apt-get ni apt (se requiere Ubuntu/Debian)"
    return 1
}

preflight_check_sudo() {
    if command -v sudo >/dev/null 2>&1; then
        log_debug "sudo disponible"
        return 0
    fi
    log_error "No se encontró sudo"
    return 1
}

# Requisitos necesarios para los comandos Bash. No comprueba ni requiere Node.js.
preflight_core() {
    local failed=0
    preflight_check_os || failed=1
    preflight_check_bash || failed=1
    preflight_check_apt || failed=1
    preflight_check_sudo || failed=1
    return "${failed}"
}

preflight_check_repo_files() {
    local repo_root="$1"
    local missing=()

    [[ -f "${repo_root}/package.json" ]] || missing+=("package.json")
    [[ -f "${repo_root}/setup.js" ]] || missing+=("setup.js")
    [[ -d "${repo_root}/scripts" ]] || missing+=("scripts/")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Faltan archivos esperados para el modo interactivo: ${missing[*]}"
        return 1
    fi
    log_debug "Archivos del modo interactivo presentes"
    return 0
}

preflight_check_node() {
    local failed=0
    command -v node >/dev/null 2>&1 || { log_warn "Node.js no está disponible todavía"; failed=1; }
    command -v npm >/dev/null 2>&1 || { log_warn "npm no está disponible todavía"; failed=1; }
    return "${failed}"
}

# Requisitos necesarios únicamente para el modo interactivo (setup.js).
# Deliberadamente NO es una compuerta dura: el flujo histórico
# (check_and_install_nodejs en setup.sh) ya le ofrece a la persona usuaria
# instalar Node.js si falta, así que esto es diagnóstico/informativo, no un
# `exit` automático. Quien llama decide qué hacer con el resultado.
preflight_interactive() {
    local repo_root="$1"
    local failed=0
    preflight_check_repo_files "${repo_root}" || failed=1
    preflight_check_node || failed=1
    return "${failed}"
}
