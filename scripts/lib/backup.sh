#!/usr/bin/env bash
# scripts/lib/backup.sh
#
# Gestor de backups centralizado (Hito 5, ver docs/ROADMAP.md y
# docs/adr/0005-gestor-de-backups-centralizado.md). Estructura de estado:
#
#   ${home_dir}/.local/state/ubuntu-workstation/backups/<sesion>/
#   ├── manifest.tsv
#   └── home/...   (copias, con la misma ruta relativa al home)
#
# Propiedades: con timestamp, nunca sobrescribe una sesión existente, origen
# y destino quedan en el manifiesto, permisos preservados, soporta dry-run.
#
# Pensado para cargarse con `source`; no declara `set -Eeuo pipefail`
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_BACKUP_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_BACKUP_SH_LOADED=1

UCI_BACKUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_BACKUP_SCRIPT_DIR
# shellcheck source=logging.sh
source "${UCI_BACKUP_SCRIPT_DIR}/logging.sh"

# Archivos que `setup.sh backup` respalda por defecto (configuración del
# shell y de runtime). Deliberadamente NO incluye directorios grandes como
# .nvm o .local/share/mise: eso es trabajo de una migración específica
# (ver docs/adr/0003-migracion-nvm-sin-borrado-directo.md), no de un backup
# genérico de configuración.
UCI_BACKUP_DEFAULT_FILES=(
    ".bashrc"
    ".zshrc"
    ".profile"
    ".gitconfig"
    ".config/mise/config.toml"
)
readonly UCI_BACKUP_DEFAULT_FILES

backup_timestamp() {
    echo "$(date +%Y%m%dT%H%M%S)-$$"
}

# backup_init_session <home_dir> <dry_run:0|1>
# En modo real, crea ${home_dir}/.local/state/ubuntu-workstation/backups/<ts>/
# y ${ts}/home/, y un manifest.tsv vacío (con encabezado). Nunca sobrescribe
# una sesión existente. En dry-run, solo calcula e imprime la ruta, sin tocar
# el filesystem. Imprime la ruta de la sesión por stdout.
backup_init_session() {
    local home_dir="$1" dry_run="$2"
    local session_id
    session_id="$(backup_timestamp)"
    local session_dir="${home_dir}/.local/state/ubuntu-workstation/backups/${session_id}"

    if [[ "${dry_run}" == "1" ]]; then
        log_info "[dry-run] se crearía la sesión de backup en ${session_dir}"
        echo "${session_dir}"
        return 0
    fi

    if [[ -e "${session_dir}" ]]; then
        log_error "La sesión de backup '${session_dir}' ya existe; no se sobrescribe"
        return 1
    fi

    mkdir -p "${session_dir}/home"
    printf 'origen\tdestino\ttipo\ttimestamp\n' > "${session_dir}/manifest.tsv"

    echo "${session_dir}"
    return 0
}

# backup_write_manifest <session_dir> <origin> <destination> <type>
backup_write_manifest() {
    local session_dir="$1" origin="$2" destination="$3" type="$4"
    printf '%s\t%s\t%s\t%s\n' "${origin}" "${destination}" "${type}" "$(date -Iseconds)" \
        >> "${session_dir}/manifest.tsv"
}

# backup_copy_file <session_dir> <home_dir> <source_path> <dry_run:0|1>
# Copia un archivo preservando permisos/timestamps. No es un error que el
# origen no exista (se omite, es lo esperado para configuración opcional).
# Rechaza sobrescribir un destino ya backupeado en esta sesión.
backup_copy_file() {
    local session_dir="$1" home_dir="$2" source_path="$3" dry_run="$4"

    if [[ ! -e "${source_path}" ]]; then
        log_debug "No existe ${source_path}, se omite"
        return 0
    fi

    local rel_path="${source_path#"${home_dir}"/}"
    local dest_path="${session_dir}/home/${rel_path}"

    if [[ "${dry_run}" == "1" ]]; then
        log_info "[dry-run] copiaría ${source_path} -> ${dest_path}"
        return 0
    fi

    if [[ -e "${dest_path}" ]]; then
        log_error "Ya existe un backup de '${source_path}' en esta sesión, no se sobrescribe"
        return 1
    fi

    mkdir -p "$(dirname "${dest_path}")"
    cp -p "${source_path}" "${dest_path}"
    backup_write_manifest "${session_dir}" "${source_path}" "${dest_path}" "file"
    log_success "Respaldado ${source_path}"
    return 0
}

# backup_copy_dir <session_dir> <home_dir> <source_dir> <dry_run:0|1>
# Copia un directorio completo preservando permisos/timestamps (cp -a).
backup_copy_dir() {
    local session_dir="$1" home_dir="$2" source_dir="$3" dry_run="$4"

    if [[ ! -e "${source_dir}" ]]; then
        log_debug "No existe ${source_dir}, se omite"
        return 0
    fi

    local rel_path="${source_dir#"${home_dir}"/}"
    local dest_path="${session_dir}/home/${rel_path}"

    if [[ "${dry_run}" == "1" ]]; then
        log_info "[dry-run] copiaría el directorio ${source_dir} -> ${dest_path}"
        return 0
    fi

    if [[ -e "${dest_path}" ]]; then
        log_error "Ya existe un backup de '${source_dir}' en esta sesión, no se sobrescribe"
        return 1
    fi

    mkdir -p "$(dirname "${dest_path}")"
    cp -a "${source_dir}" "${dest_path}"
    backup_write_manifest "${session_dir}" "${source_dir}" "${dest_path}" "dir"
    log_success "Respaldado el directorio ${source_dir}"
    return 0
}

# backup_move_dir <session_dir> <home_dir> <source_dir> <dry_run:0|1>
#
# NO se usa todavía en ningún flujo de este hito: es la primitiva que
# necesitará la migración NVM->Mise (Hito 7, ver ADR 0003) para mover .nvm
# en vez de borrarlo. Copia primero, verifica que la cantidad de archivos
# coincida, y solo entonces elimina el origen. Si algo no calza, no borra
# nada y reporta error.
backup_move_dir() {
    local session_dir="$1" home_dir="$2" source_dir="$3" dry_run="$4"

    if [[ ! -e "${source_dir}" ]]; then
        log_debug "No existe ${source_dir}, se omite"
        return 0
    fi

    if [[ "${dry_run}" == "1" ]]; then
        local rel_path="${source_dir#"${home_dir}"/}"
        log_info "[dry-run] movería ${source_dir} -> ${session_dir}/home/${rel_path} (copiar + verificar + eliminar origen)"
        return 0
    fi

    if ! backup_copy_dir "${session_dir}" "${home_dir}" "${source_dir}" "0"; then
        return 1
    fi

    local rel_path="${source_dir#"${home_dir}"/}"
    local dest_path="${session_dir}/home/${rel_path}"

    local source_count dest_count
    source_count="$(find "${source_dir}" -type f 2>/dev/null | wc -l || true)"
    dest_count="$(find "${dest_path}" -type f 2>/dev/null | wc -l || true)"

    if [[ "${source_count}" != "${dest_count}" ]]; then
        log_error "La copia de ${source_dir} no coincide en cantidad de archivos (origen: ${source_count}, backup: ${dest_count}); no se elimina el origen"
        return 1
    fi

    rm -rf "${source_dir}"
    log_success "Movido ${source_dir} al backup (origen eliminado tras verificar la copia)"
    return 0
}

# backup_run <home_dir> <dry_run:0|1>
# Respalda la configuración conocida de shell/runtime (UCI_BACKUP_DEFAULT_FILES).
backup_run() {
    local home_dir="$1" dry_run="$2"

    local session_dir
    session_dir="$(backup_init_session "${home_dir}" "${dry_run}")" || return 1

    local rel_path
    local any_failed=0
    for rel_path in "${UCI_BACKUP_DEFAULT_FILES[@]}"; do
        if ! backup_copy_file "${session_dir}" "${home_dir}" "${home_dir}/${rel_path}" "${dry_run}"; then
            any_failed=1
        fi
    done

    echo ""
    if [[ "${dry_run}" == "1" ]]; then
        log_info "Dry-run: no se creó ningún archivo. Sesión que se habría usado: ${session_dir}"
    else
        log_success "Sesión de backup: ${session_dir}"
        log_info "Manifiesto: ${session_dir}/manifest.tsv"
    fi

    return "${any_failed}"
}
