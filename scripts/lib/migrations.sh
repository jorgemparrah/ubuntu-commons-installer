#!/usr/bin/env bash
# scripts/lib/migrations.sh
#
# Framework de migraciones versionado (Hito 6, ver docs/ROADMAP.md y
# docs/adr/0006-framework-de-migraciones-versionado.md).
#
# Cada migración es un script ejecutable en scripts/migrations/NNN_slug.sh
# (ver scripts/migrations/README.md para el contrato completo) que responde
# a estas acciones:
#   describe        -> imprime una descripción de una línea (para --list)
#   check           -> de solo lectura; exit 0 si aplica y hay que migrarla,
#                      exit != 0 si no aplica (nada que hacer, no es un error)
#   dry-run         -> imprime qué haría, sin tocar nada
#   apply           -> aplica la migración de verdad
#   validate        -> de solo lectura; exit 0 si el resultado quedó bien
#   rollback-notes  -> imprime notas de cómo revertir manualmente
#
# Las marcas de finalización quedan en
# ${home_dir}/.local/state/ubuntu-workstation/migrations/<id>.done
#
# Pensado para cargarse con `source`; no declara `set -Eeuo pipefail`
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_MIGRATIONS_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_MIGRATIONS_SH_LOADED=1

UCI_MIGRATIONS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_MIGRATIONS_SCRIPT_DIR
# shellcheck source=logging.sh
source "${UCI_MIGRATIONS_SCRIPT_DIR}/logging.sh"

UCI_MIGRATIONS_DIR="$(cd "${UCI_MIGRATIONS_SCRIPT_DIR}/../migrations" && pwd)"
readonly UCI_MIGRATIONS_DIR

# migrations_discover
# Imprime, una ruta por línea, cada script de migración disponible,
# ordenados por nombre (y por lo tanto por su prefijo numérico).
migrations_discover() {
    find "${UCI_MIGRATIONS_DIR}" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort
}

# migrations_id <path>
migrations_id() {
    basename "$1" .sh
}

# migrations_marker_path <home_dir> <id>
migrations_marker_path() {
    local home_dir="$1" id="$2"
    echo "${home_dir}/.local/state/ubuntu-workstation/migrations/${id}.done"
}

# migrations_is_done <home_dir> <id>
migrations_is_done() {
    local home_dir="$1" id="$2"
    [[ -f "$(migrations_marker_path "${home_dir}" "${id}")" ]]
}

# migrations_mark_done <home_dir> <id>
migrations_mark_done() {
    local home_dir="$1" id="$2"
    local marker
    marker="$(migrations_marker_path "${home_dir}" "${id}")"
    mkdir -p "$(dirname "${marker}")"
    date -Iseconds > "${marker}"
}

# migrations_list <home_dir>
migrations_list() {
    local home_dir="$1"
    local path id description status

    echo "ID                       ESTADO      DESCRIPCIÓN"
    while IFS= read -r path; do
        [[ -z "${path}" ]] && continue
        id="$(migrations_id "${path}")"
        description="$("${path}" describe 2>/dev/null || echo "(sin descripción)")"
        if migrations_is_done "${home_dir}" "${id}"; then
            status="hecha"
        else
            status="pendiente"
        fi
        printf '%-24s %-11s %s\n' "${id}" "${status}" "${description}"
    done < <(migrations_discover)
}

# migrations_run <home_dir> <dry_run:0|1>
# Ejecuta las migraciones pendientes en orden. Se detiene ante la primera
# migración que falle (apply o validate), sin marcarla como hecha. Las
# migraciones ya hechas se omiten (ejecución repetible: no se reaplican).
migrations_run() {
    local home_dir="$1" dry_run="$2"
    local path id description

    while IFS= read -r path; do
        [[ -z "${path}" ]] && continue
        id="$(migrations_id "${path}")"

        if migrations_is_done "${home_dir}" "${id}"; then
            log_debug "Migración '${id}' ya está hecha, se omite"
            continue
        fi

        description="$("${path}" describe 2>/dev/null || echo "(sin descripción)")"

        if ! "${path}" check >/dev/null 2>&1; then
            log_info "Migración '${id}' (${description}): no aplica en este sistema, se omite"
            continue
        fi

        if [[ "${dry_run}" == "1" ]]; then
            log_info "Migración '${id}' (${description}) — dry-run:"
            "${path}" dry-run || true
            continue
        fi

        log_info "Aplicando migración '${id}' (${description})..."
        if ! "${path}" apply; then
            log_error "La migración '${id}' falló al aplicarse. No se marca como hecha."
            log_info "Notas de rollback para '${id}':"
            "${path}" rollback-notes || true
            return 1
        fi

        if ! "${path}" validate; then
            log_error "La migración '${id}' se aplicó pero no pasó la validación. No se marca como hecha."
            log_info "Notas de rollback para '${id}':"
            "${path}" rollback-notes || true
            return 1
        fi

        migrations_mark_done "${home_dir}" "${id}"
        log_success "Migración '${id}' completada y validada."
    done < <(migrations_discover)

    return 0
}
