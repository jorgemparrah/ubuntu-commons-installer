#!/usr/bin/env bash
# scripts/migrations/001_nvm_to_mise.sh
#
# Migración NVM -> Mise (Hito 7, ver docs/ROADMAP.md).
# Decisiones relacionadas: docs/adr/0002-mise-como-unico-gestor-runtime.md,
# docs/adr/0003-migracion-nvm-sin-borrado-directo.md,
# docs/adr/0007-bloques-gestionados-en-archivos-de-shell.md,
# docs/adr/0016-politica-de-versiones-node-mise.md.
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

UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
readonly UCI_HOME_DIR

UCI_NVM_DIR="${UCI_HOME_DIR}/.nvm"
readonly UCI_NVM_DIR
UCI_MISE_BIN="${UCI_HOME_DIR}/.local/bin/mise"
readonly UCI_MISE_BIN

UCI_MISE_BLOCK_BEGIN="# >>> ubuntu-workstation: mise >>>"
UCI_MISE_BLOCK_END="# <<< ubuntu-workstation: mise <<<"
readonly UCI_MISE_BLOCK_BEGIN UCI_MISE_BLOCK_END

# mise_cmd <args...>
mise_cmd() {
    "${UCI_MISE_BIN}" "$@"
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

migration_describe() {
    echo "Migra Node.js de NVM a Mise: instala Mise, reinstala las versiones de Node detectadas, activa Mise vía un bloque gestionado del shell, y mueve ~/.nvm a un backup (no lo borra)"
}

migration_check() {
    [[ -d "${UCI_NVM_DIR}" ]]
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
    local session_dir
    session_dir="$(backup_init_session "${UCI_HOME_DIR}" "0")" || return 1

    # 1) Respaldar configuración de shell ANTES de tocarla.
    local rc_file
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc" "${UCI_HOME_DIR}/.profile"; do
        backup_copy_file "${session_dir}" "${UCI_HOME_DIR}" "${rc_file}" "0" || return 1
    done

    # 2) Inventariar (no reinstalar) paquetes globales, solo para el reporte.
    local versions
    versions="$(nvm_installed_versions)"
    if [[ -n "${versions}" ]]; then
        log_info "Versiones de Node detectadas en NVM: $(echo "${versions}" | tr '\n' ' ')"
    fi

    # 3) Instalar Mise si falta.
    if [[ ! -x "${UCI_MISE_BIN}" ]]; then
        log_info "Instalando Mise..."
        if ! curl -fsSL https://mise.run | sh >/dev/null; then
            log_error "No se pudo instalar Mise"
            return 1
        fi
    fi

    if [[ ! -x "${UCI_MISE_BIN}" ]]; then
        log_error "Mise no quedó instalado en ${UCI_MISE_BIN} tras el intento de instalación"
        return 1
    fi

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
            if ! mise_cmd install "node@${plain_version}"; then
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
        if ! mise_cmd use --global "node@${default_version}"; then
            log_error "No se pudo fijar la versión global de Node en Mise"
            return 1
        fi
    fi

    # 7) Mover .nvm al backup (copiar + verificar + recién ahí eliminar el
    # origen). Nunca se borra directamente (ADR 0003).
    if ! backup_move_dir "${session_dir}" "${UCI_HOME_DIR}" "${UCI_NVM_DIR}" "0"; then
        log_error "No se pudo mover ${UCI_NVM_DIR} al backup; se detiene antes de darlo por completado"
        return 1
    fi

    log_success "Migración NVM -> Mise aplicada. Backup en: ${session_dir}"
    return 0
}

migration_validate() {
    if [[ ! -x "${UCI_MISE_BIN}" ]]; then
        log_error "Validación: Mise no está instalado en ${UCI_MISE_BIN}"
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
3. Restaurar <sesión>/home/.bashrc, .zshrc y .profile a sus ubicaciones originales
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
