#!/usr/bin/env bash
# scripts/migrations/001_nvm_to_mise.sh
#
# Migración NVM -> Mise (Hito 7, ver docs/ROADMAP.md).
# Decisiones relacionadas: docs/adr/0002-mise-como-unico-gestor-runtime.md,
# docs/adr/0003-migracion-nvm-sin-borrado-directo.md,
# docs/adr/0007-bloques-gestionados-en-archivos-de-shell.md,
# docs/adr/0016-politica-de-versiones-node-mise.md.
#
# La instalación/activación de Mise usa scripts/lib/runtime.sh (Hito 8), la
# misma librería que usa cualquier otro runtime gestionado por el proyecto.
#
# Esta migración instala software real (Mise) y solo se prueba dentro de
# contenedores Docker desechables (ver docs/TESTING.md), nunca contra el
# $HOME real de una máquina de desarrollo. Por eso usa UCI_HOME_DIR (ver
# docs/adr/0023-variable-uci-home-dir-para-pruebas.md) igual que el resto
# del proyecto, sin necesidad de distinguir un "home simulado" del real:
# dentro del contenedor, ambos son siempre el mismo.
set -Eeuo pipefail

UCI_MIGRATION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_MIGRATION_SCRIPT_DIR
# shellcheck source=../lib/logging.sh
source "${UCI_MIGRATION_SCRIPT_DIR}/../lib/logging.sh"
# shellcheck source=../lib/backup.sh
source "${UCI_MIGRATION_SCRIPT_DIR}/../lib/backup.sh"
# shellcheck source=../lib/runtime.sh
source "${UCI_MIGRATION_SCRIPT_DIR}/../lib/runtime.sh"

UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
readonly UCI_HOME_DIR

UCI_NVM_DIR="${UCI_HOME_DIR}/.nvm"
readonly UCI_NVM_DIR
UCI_MISE_BIN="$(runtime_mise_bin "${UCI_HOME_DIR}")"
readonly UCI_MISE_BIN

UCI_MISE_BLOCK_BEGIN="# >>> ubuntu-workstation: mise >>>"
UCI_MISE_BLOCK_END="# <<< ubuntu-workstation: mise <<<"
readonly UCI_MISE_BLOCK_BEGIN UCI_MISE_BLOCK_END

# Identificador de esta migración (coincide con el nombre del propio
# archivo, sin extensión) y rutas de marcas de estado bajo
# ${UCI_HOME_DIR}/.local/state/ubuntu-workstation/migrations/ — el mismo
# esquema que usa scripts/lib/migrations.sh (migrations_marker_path).
UCI_MIGRATION_ID="$(basename "${BASH_SOURCE[0]}" .sh)"
readonly UCI_MIGRATION_ID
UCI_MIGRATIONS_STATE_DIR="${UCI_HOME_DIR}/.local/state/ubuntu-workstation/migrations"
readonly UCI_MIGRATIONS_STATE_DIR
UCI_MIGRATION_DONE_MARKER="${UCI_MIGRATIONS_STATE_DIR}/${UCI_MIGRATION_ID}.done"
readonly UCI_MIGRATION_DONE_MARKER
# Sentinel PROPIO de esta migración (distinto de la marca ".done" oficial,
# que solo escribe scripts/lib/migrations.sh tras un apply+validate
# exitosos). Se escribe al final de migration_apply(), justo después de
# mover .nvm con éxito. Sirve para distinguir "ya no queda nada que migrar"
# de "esta corrida ya movió todo lo real, pero la validación final falló
# antes de marcar la migración como hecha" (ver UCI_TEST_FAIL_MIGRATION_AT
# más abajo y el checkpoint 'before_done_marker'): en ese segundo caso,
# migration_check() debe seguir diciendo que hay algo pendiente, para que
# un reintento sin fallo inyectado pueda completar la validación y marcar
# la migración como hecha, en vez de quedar huérfana para siempre.
UCI_MIGRATION_APPLY_SENTINEL="${UCI_MIGRATIONS_STATE_DIR}/.${UCI_MIGRATION_ID}.apply-completado"
readonly UCI_MIGRATION_APPLY_SENTINEL

# --- Inyección de fallos exclusiva para pruebas (nunca activa por defecto) -
#
# UCI_TEST_FAIL_MIGRATION_AT: si se define con uno de los checkpoints de
# abajo, migration_test_fail_at() simula que la migración falló justo en
# ese punto, sin depender de cortar Internet de verdad. Vacía por defecto:
# sin efecto alguno en una ejecución normal. Ver docs/TESTING.md y
# docs/TEST_CASES.md (caso M07) para el detalle de cada checkpoint.
UCI_TEST_FAIL_MIGRATION_AT="${UCI_TEST_FAIL_MIGRATION_AT:-}"

# migration_test_fail_at <checkpoint>
# exit 1 si UCI_TEST_FAIL_MIGRATION_AT coincide con <checkpoint>; exit 0 en
# cualquier otro caso (incluida la variable vacía/no definida).
migration_test_fail_at() {
    local checkpoint="$1"
    if [[ -n "${UCI_TEST_FAIL_MIGRATION_AT}" && "${UCI_TEST_FAIL_MIGRATION_AT}" == "${checkpoint}" ]]; then
        log_error "[UCI_TEST_FAIL_MIGRATION_AT] Fallo inyectado deliberadamente en el checkpoint '${checkpoint}' (solo pruebas)"
        return 1
    fi
    return 0
}

# mise_cmd <args...>
mise_cmd() {
    runtime_cmd "${UCI_HOME_DIR}" "$@"
}

nvm_installed_versions() {
    if [[ -d "${UCI_NVM_DIR}/versions/node" ]]; then
        find "${UCI_NVM_DIR}/versions/node" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -V
    fi
}

nvm_default_alias() {
    local alias_file="${UCI_NVM_DIR}/alias/default"
    if [[ -f "${alias_file}" ]]; then
        cat "${alias_file}"
    fi
}

# nvm_resolve_version_spec <spec> <versions_multilinea>
# Resuelve un "spec" de versión (como los que guarda alias/default: puede
# ser una versión exacta "v18.20.8", un major "18", o un alias especial que
# no podemos resolver sin invocar nvm, como "lts/*"/"node"/"stable") contra
# la lista de versiones realmente instaladas. Si no se puede resolver,
# retorna != 0 y no imprime nada — quien llama decide el fallback.
nvm_resolve_version_spec() {
    local spec="$1" versions="$2"

    if echo "${versions}" | grep -qxF "${spec}"; then
        echo "${spec}"
        return 0
    fi
    if echo "${versions}" | grep -qxF "v${spec}"; then
        echo "v${spec}"
        return 0
    fi

    local major="${spec#v}"
    if [[ "${major}" =~ ^[0-9]+$ ]]; then
        local match
        match="$(echo "${versions}" | grep -E "^v${major}\." | sort -V | tail -n1)"
        if [[ -n "${match}" ]]; then
            echo "${match}"
            return 0
        fi
    fi

    return 1
}

# nvm_global_packages <version>
# Solo inventaría (para el reporte); no se reinstalan automáticamente.
nvm_global_packages() {
    local version="$1"
    local modules_dir="${UCI_NVM_DIR}/versions/node/${version}/lib/node_modules"
    if [[ -d "${modules_dir}" ]]; then
        find "${modules_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | grep -v '^npm$' | sort || true
    fi
}

# nvm_package_version <version> <paquete>
# Versión del paquete global, leída de su propio package.json. "desconocida"
# si no se puede determinar (nunca es un error: es solo para el reporte).
nvm_package_version() {
    local version="$1" package="$2"
    local pkg_json="${UCI_NVM_DIR}/versions/node/${version}/lib/node_modules/${package}/package.json"
    if [[ -f "${pkg_json}" ]]; then
        local pkg_version
        pkg_version="$(grep -m1 '"version"' "${pkg_json}" 2>/dev/null | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*/\1/')"
        [[ -n "${pkg_version}" ]] && echo "${pkg_version}" && return 0
    fi
    echo "desconocida"
}

# nvm_write_versions_report <report_file> <versions_multilinea> <default_alias> <default_version_mise>
nvm_write_versions_report() {
    local report_file="$1" versions="$2" default_alias="$3" default_version="$4"
    local v

    printf 'version_node\truta_original\talias_default_nvm\tversion_global_mise\n' > "${report_file}"
    if [[ -n "${versions}" ]]; then
        while IFS= read -r v; do
            [[ -z "${v}" ]] && continue
            printf '%s\t%s\t%s\t%s\n' \
                "${v}" "${UCI_NVM_DIR}/versions/node/${v}" "${default_alias:--}" "${default_version:--}" \
                >> "${report_file}"
        done <<< "${versions}"
    fi
}

# nvm_write_global_packages_report <report_file> <versions_multilinea>
# No reinstala nada; es puramente informativo (ver ADR 0024).
nvm_write_global_packages_report() {
    local report_file="$1" versions="$2"
    local v pkg pkgs

    printf 'version_node\tpaquete\tversion_paquete\truta_original\n' > "${report_file}"
    if [[ -z "${versions}" ]]; then
        return 0
    fi

    while IFS= read -r v; do
        [[ -z "${v}" ]] && continue
        pkgs="$(nvm_global_packages "${v}")"
        [[ -z "${pkgs}" ]] && continue
        while IFS= read -r pkg; do
            [[ -z "${pkg}" ]] && continue
            printf '%s\t%s\t%s\t%s\n' \
                "${v}" "${pkg}" "$(nvm_package_version "${v}" "${pkg}")" \
                "${UCI_NVM_DIR}/versions/node/${v}/lib/node_modules/${pkg}" \
                >> "${report_file}"
        done <<< "${pkgs}"
    done <<< "${versions}"
}

# --- Limpieza de referencias conocidas de NVM en archivos de shell -------
#
# Solo se eliminan líneas que calcen EXACTO (normalizando espacios) con las
# que agrega el instalador oficial de NVM o nuestro propio
# scripts/development/install_nodejs.sh (legado). Nunca se usa un patrón
# amplio tipo "cualquier línea que contenga nvm" (ver ADR 0007/HI-04).
# Cualquier otra línea que mencione "nvm" se deja intacta y se reporta como
# ambigua para revisión manual.

# nvm_normalize_line <línea>
# Colapsa espacios/tabs repetidos y quita espacios al final, para comparar
# con las líneas conocidas sin ser tan frágil como una comparación byte a
# byte (por ejemplo, un espacio de más antes de un comentario).
nvm_normalize_line() {
    printf '%s' "$1" | sed -E 's/[[:space:]]+/ /g; s/[[:space:]]+$//'
}

# nvm_is_known_shell_line <línea>
# exit 0 si la línea es un patrón exacto y reconocido del instalador de
# NVM (oficial o el legado de este repo); exit 1 en cualquier otro caso.
nvm_is_known_shell_line() {
    local normalized
    normalized="$(nvm_normalize_line "$1")"
    case "${normalized}" in
        'export NVM_DIR="$HOME/.nvm"')
            return 0
            ;;
        'export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"')
            return 0
            ;;
        '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm')
            return 0
            ;;
        '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"')
            return 0
            ;;
        '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion')
            return 0
            ;;
        '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"')
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# nvm_scan_shell_file <rc_file>
# De solo lectura: imprime, separadas por tab, cuántas líneas conocidas se
# eliminarían y cuántas ambiguas quedarían sin tocar. Usado por dry-run.
nvm_scan_shell_file() {
    local rc_file="$1"
    local known=0 ambiguous=0 line

    if [[ ! -f "${rc_file}" ]]; then
        printf '0\t0\n'
        return 0
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if nvm_is_known_shell_line "${line}"; then
            known=$((known + 1))
        elif printf '%s' "${line}" | grep -qi 'nvm'; then
            ambiguous=$((ambiguous + 1))
        fi
    done < "${rc_file}"

    printf '%s\t%s\n' "${known}" "${ambiguous}"
}

# nvm_cleanup_shell_file <rc_file> <report_file>
# Reescribe <rc_file> eliminando solo las líneas exactas reconocidas.
# Cualquier línea ambigua (menciona "nvm" pero no calza con un patrón
# conocido) se conserva intacta y se registra en <report_file>. Maneja
# archivos sin salto de línea final. No es un no-op seguro para dry-run:
# para eso usar nvm_scan_shell_file.
nvm_cleanup_shell_file() {
    local rc_file="$1" report_file="$2"
    local tmp_file line removed=0

    if [[ ! -f "${rc_file}" ]]; then
        return 0
    fi

    tmp_file="$(mktemp)"

    while IFS= read -r line || [[ -n "${line}" ]]; do
        if nvm_is_known_shell_line "${line}"; then
            removed=$((removed + 1))
            printf '%s\t%s\t%s\n' "${rc_file}" "eliminada: patrón conocido de NVM" "${line}" >> "${report_file}"
            continue
        fi

        if printf '%s' "${line}" | grep -qi 'nvm'; then
            printf '%s\t%s\t%s\n' "${rc_file}" "ambigua: se deja sin tocar, revisar manualmente" "${line}" >> "${report_file}"
        fi

        printf '%s\n' "${line}" >> "${tmp_file}"
    done < "${rc_file}"

    if [[ "${removed}" -gt 0 ]]; then
        mv "${tmp_file}" "${rc_file}"
        log_success "Se limpiaron ${removed} línea(s) conocida(s) de NVM en ${rc_file}"
    else
        rm -f "${tmp_file}"
    fi

    return 0
}

# nvm_shell_files_still_reference_nvm_sh
# exit 0 (verdadero) si algún archivo de shell todavía intenta cargar
# $NVM_DIR/nvm.sh — señal de que la limpieza no funcionó o de que queda un
# patrón no reconocido apuntando a una ruta ya inexistente.
nvm_shell_files_still_reference_nvm_sh() {
    local rc_file
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc" "${UCI_HOME_DIR}/.profile"; do
        if [[ -f "${rc_file}" ]] && grep -qF 'NVM_DIR/nvm.sh' "${rc_file}"; then
            return 0
        fi
    done
    return 1
}

migration_describe() {
    echo "Migra Node.js de NVM a Mise: instala Mise, reinstala las versiones de Node detectadas, limpia las referencias conocidas de NVM en los archivos de shell, activa Mise vía un bloque gestionado del shell, y mueve ~/.nvm a un backup (no lo borra)"
}

migration_check() {
    if [[ -d "${UCI_NVM_DIR}" ]]; then
        return 0
    fi

    # .nvm ya no existe, pero esta migración nunca se marcó como hecha: es
    # el estado que deja una corrida anterior que llegó a mover .nvm de
    # verdad (ver UCI_MIGRATION_APPLY_SENTINEL) y luego falló en la
    # validación final. Se permite reintentar apply/validate — son
    # idempotentes (backup_move_dir no falla si el origen ya no existe,
    # Mise/Node ya instalados se omiten) — en vez de omitir la migración
    # silenciosamente para siempre.
    if [[ -f "${UCI_MIGRATION_APPLY_SENTINEL}" && ! -f "${UCI_MIGRATION_DONE_MARKER}" ]]; then
        return 0
    fi

    return 1
}

migration_dry_run() {
    local versions default_alias
    versions="$(nvm_installed_versions)"
    default_alias="$(nvm_default_alias)"

    log_info "[dry-run] NVM detectado en ${UCI_NVM_DIR}"
    if [[ -n "${versions}" ]]; then
        log_info "[dry-run] Versiones de Node instaladas vía NVM:"
        local v
        while IFS= read -r v; do
            [[ -z "${v}" ]] && continue
            echo "  - ${v}"
            local pkgs
            pkgs="$(nvm_global_packages "${v}")"
            if [[ -n "${pkgs}" ]]; then
                echo "      paquetes globales detectados: $(echo "${pkgs}" | tr '\n' ' ')"
            fi
        done <<< "${versions}"
    else
        log_info "[dry-run] No se detectaron versiones de Node bajo NVM"
    fi
    if [[ -n "${default_alias}" ]]; then
        log_info "[dry-run] Alias 'default' de NVM: ${default_alias}"
    fi

    if [[ -x "${UCI_MISE_BIN}" ]]; then
        log_info "[dry-run] Mise ya está instalado en ${UCI_MISE_BIN}, no se reinstalaría"
    else
        log_info "[dry-run] Instalaría Mise en ${UCI_HOME_DIR}/.local/bin/mise"
    fi

    log_info "[dry-run] Respaldaría .bashrc/.zshrc/.profile y movería ${UCI_NVM_DIR} a un backup (copiar + verificar + recién ahí eliminar el origen)"

    local rc_file scan known ambiguous
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc" "${UCI_HOME_DIR}/.profile"; do
        [[ -f "${rc_file}" ]] || continue
        scan="$(nvm_scan_shell_file "${rc_file}")"
        known="$(echo "${scan}" | cut -f1)"
        ambiguous="$(echo "${scan}" | cut -f2)"
        if [[ "${known}" -gt 0 || "${ambiguous}" -gt 0 ]]; then
            log_info "[dry-run] ${rc_file}: eliminaría ${known} línea(s) conocida(s) de NVM, dejaría ${ambiguous} línea(s) ambigua(s) sin tocar"
        fi
    done

    log_info "[dry-run] Agregaría/actualizaría el bloque gestionado de Mise en los archivos de shell presentes"
    if [[ -n "${versions}" ]]; then
        log_info "[dry-run] Instalaría vía Mise cada versión detectada: $(echo "${versions}" | tr '\n' ' ')"
    fi
}

# mise_shell_block_upsert <rc_file>
# Agrega o reemplaza (nunca duplica) el bloque gestionado de Mise en el
# archivo de shell indicado. Solo toca las líneas entre los marcadores
# exactos (ver ADR 0007); el resto del archivo queda intacto.
mise_shell_block_upsert() {
    local rc_file="$1"
    local shell_name
    shell_name="$(basename "${rc_file}" | sed 's/^\.//; s/rc$//')"
    [[ "${shell_name}" == "profile" ]] && shell_name="bash"

    # Las pruebas de esta migración corren solo dentro de contenedores
    # Docker desechables (ver docs/TESTING.md), donde UCI_HOME_DIR siempre
    # coincide con el $HOME real del contenedor. El bloque queda entonces
    # igual al ejemplo canónico de la ADR 0007, sin necesidad de anteponer
    # HOME=... .
    local activate_line="eval \"\$(${UCI_MISE_BIN} activate ${shell_name})\""

    local block
    block="$(printf '%s\n%s\n%s' "${UCI_MISE_BLOCK_BEGIN}" "${activate_line}" "${UCI_MISE_BLOCK_END}")"

    if [[ ! -f "${rc_file}" ]]; then
        printf '%s\n' "${block}" > "${rc_file}"
        return 0
    fi

    if grep -qF "${UCI_MISE_BLOCK_BEGIN}" "${rc_file}"; then
        awk -v begin="${UCI_MISE_BLOCK_BEGIN}" -v end="${UCI_MISE_BLOCK_END}" -v block="${block}" '
            $0 == begin { print block; skip=1; next }
            $0 == end { skip=0; next }
            skip == 1 { next }
            { print }
        ' "${rc_file}" > "${rc_file}.uci_tmp"
        mv "${rc_file}.uci_tmp" "${rc_file}"
    else
        {
            echo ""
            printf '%s\n' "${block}"
        } >> "${rc_file}"
    fi
}

migration_apply() {
    if [[ -n "${UCI_TEST_FAIL_MIGRATION_AT}" ]]; then
        log_warn "Modo de inyección de fallos de prueba activo: UCI_TEST_FAIL_MIGRATION_AT=${UCI_TEST_FAIL_MIGRATION_AT} (nunca debe estar definida en una ejecución real)"
    fi

    local session_dir
    session_dir="$(backup_init_session "${UCI_HOME_DIR}" "0")" || return 1

    # 1) Respaldar configuración de shell ANTES de tocarla.
    local rc_file
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc" "${UCI_HOME_DIR}/.profile"; do
        backup_copy_file "${session_dir}" "${UCI_HOME_DIR}" "${rc_file}" "0" || return 1
    done

    migration_test_fail_at "after_shell_backup" || return 1

    # 1.5) Limpiar referencias conocidas de NVM en los archivos de shell ya
    # respaldados. Solo patrones exactos reconocidos (ver ADR 0007); las
    # líneas ambiguas se dejan intactas y quedan reportadas.
    mkdir -p "${session_dir}/reports"
    local shell_changes_report="${session_dir}/reports/shell-changes.tsv"
    printf 'archivo\taccion\tlinea\n' > "${shell_changes_report}"
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc" "${UCI_HOME_DIR}/.profile"; do
        nvm_cleanup_shell_file "${rc_file}" "${shell_changes_report}"
    done

    # 2) Inventariar (no reinstalar) paquetes globales, solo para el reporte.
    local versions
    versions="$(nvm_installed_versions)"
    if [[ -n "${versions}" ]]; then
        log_info "Versiones de Node detectadas en NVM: $(echo "${versions}" | tr '\n' ' ')"
    fi
    nvm_write_global_packages_report "${session_dir}/reports/nvm-global-packages.tsv" "${versions}"

    migration_test_fail_at "before_mise_install" || return 1

    # 3) Instalar Mise si falta (scripts/lib/runtime.sh, Hito 8).
    if ! runtime_ensure_mise "${UCI_HOME_DIR}"; then
        return 1
    fi

    migration_test_fail_at "after_mise_before_node" || return 1

    # 4) Bloque gestionado de activación (ADR 0007), solo en los archivos
    # que ya existan.
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc"; do
        if [[ -f "${rc_file}" ]]; then
            mise_shell_block_upsert "${rc_file}"
        fi
    done

    # 5) Instalar cada versión de Node detectada, vía Mise.
    local v install_failed=0
    if [[ -n "${versions}" ]]; then
        while IFS= read -r v; do
            [[ -z "${v}" ]] && continue
            local plain_version="${v#v}"
            log_info "Instalando Node ${plain_version} vía Mise..."
            if ! runtime_install "${UCI_HOME_DIR}" node "${plain_version}"; then
                log_error "No se pudo instalar Node ${plain_version} vía Mise"
                install_failed=1
            fi
        done <<< "${versions}"
    fi

    if [[ "${install_failed}" == "1" ]]; then
        return 1
    fi

    # 6) Definir la versión global: la que resuelva el alias 'default' de
    # NVM entre las versiones instaladas; si no se puede resolver (alias
    # especial como 'lts/*', 'node', 'stable', u otro alias anidado), la
    # más alta detectada. El archivo alias/default de NVM guarda el valor
    # tal cual se pasó a `nvm alias default <valor>` (por ejemplo "18"),
    # NO la versión ya resuelta (por ejemplo "v18.20.8") — hay que
    # resolverlo nosotros mismos contra las versiones instaladas.
    local default_alias default_version
    default_alias="$(nvm_default_alias)"
    default_version=""
    if [[ -n "${default_alias}" && -n "${versions}" ]]; then
        default_version="$(nvm_resolve_version_spec "${default_alias}" "${versions}")" || true
    fi
    if [[ -z "${default_version}" && -n "${versions}" ]]; then
        default_version="$(echo "${versions}" | tail -n1)"
    fi
    default_version="${default_version#v}"

    if [[ -n "${default_version}" ]]; then
        log_info "Fijando Node ${default_version} como versión global de Mise..."
        if ! runtime_use_global "${UCI_HOME_DIR}" node "${default_version}"; then
            log_error "No se pudo fijar la versión global de Node en Mise"
            return 1
        fi
    fi

    nvm_write_versions_report "${session_dir}/reports/nvm-versions.tsv" "${versions}" "${default_alias}" "${default_version}"

    migration_test_fail_at "after_node_before_move" || return 1

    # 7) Mover .nvm al backup (copiar + verificar + recién ahí eliminar el
    # origen). Nunca se borra directamente (ADR 0003).
    if ! backup_move_dir "${session_dir}" "${UCI_HOME_DIR}" "${UCI_NVM_DIR}" "0"; then
        log_error "No se pudo mover ${UCI_NVM_DIR} al backup; se detiene antes de darlo por completado"
        return 1
    fi

    # Sentinel de reanudación: el trabajo real de esta migración ya
    # terminó (Mise instalado, Node vía Mise, .nvm movido). Si lo que
    # sigue (validate(), o el propio marcado de ".done" en
    # scripts/lib/migrations.sh) falla, migration_check() seguirá
    # detectando que falta completar esta migración.
    mkdir -p "$(dirname "${UCI_MIGRATION_APPLY_SENTINEL}")"
    date -Iseconds > "${UCI_MIGRATION_APPLY_SENTINEL}"

    log_success "Migración NVM -> Mise aplicada. Backup en: ${session_dir}"
    log_info "Reportes: ${session_dir}/reports/ (nvm-versions.tsv, nvm-global-packages.tsv, shell-changes.tsv)"
    return 0
}

migration_validate() {
    migration_test_fail_at "before_done_marker" || return 1

    if [[ ! -x "${UCI_MISE_BIN}" ]]; then
        log_error "Validación: Mise no está instalado en ${UCI_MISE_BIN}"
        return 1
    fi

    if nvm_shell_files_still_reference_nvm_sh; then
        log_error "Validación: algún archivo de shell todavía intenta cargar \$NVM_DIR/nvm.sh, una ruta que ya no existe"
        return 1
    fi

    if [[ -d "${UCI_NVM_DIR}" ]]; then
        log_error "Validación: ${UCI_NVM_DIR} todavía existe (debería haberse movido al backup)"
        return 1
    fi

    local node_path
    node_path="$(mise_cmd which node 2>/dev/null || true)"
    if [[ -z "${node_path}" || ! -x "${node_path}" ]]; then
        log_error "Validación: Mise no resuelve un ejecutable de node"
        return 1
    fi

    if ! "${node_path}" --version >/dev/null 2>&1; then
        log_error "Validación: el node gestionado por Mise no se ejecuta correctamente"
        return 1
    fi

    return 0
}

migration_rollback_notes() {
    cat <<EOF
Para revertir manualmente esta migración:
1. Ubicar la sesión de backup más reciente en ${UCI_HOME_DIR}/.local/state/ubuntu-workstation/backups/
2. Mover de vuelta <sesión>/home/.nvm a ${UCI_NVM_DIR}
3. Restaurar <sesión>/home/.bashrc, .zshrc y .profile a sus ubicaciones originales (esto también deshace la limpieza de líneas de NVM; ver <sesión>/reports/shell-changes.tsv para el detalle de qué se quitó)
4. Eliminar el bloque gestionado de Mise (entre '${UCI_MISE_BLOCK_BEGIN}' y '${UCI_MISE_BLOCK_END}') de los archivos de shell restaurados, si quedó alguno agregado por una corrida parcial
5. Opcionalmente, desinstalar Mise eliminando ${UCI_HOME_DIR}/.local/bin/mise, ${UCI_HOME_DIR}/.config/mise y ${UCI_HOME_DIR}/.local/share/mise
EOF
}

main() {
    case "${1:-}" in
        describe)
            migration_describe
            ;;
        check)
            migration_check
            ;;
        dry-run)
            migration_dry_run
            ;;
        apply)
            migration_apply
            ;;
        validate)
            migration_validate
            ;;
        rollback-notes)
            migration_rollback_notes
            ;;
        *)
            echo "Uso: $0 {describe|check|dry-run|apply|validate|rollback-notes}"
            exit 1
            ;;
    esac
}

main "$@"
