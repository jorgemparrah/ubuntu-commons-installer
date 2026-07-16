#!/usr/bin/env bash
# scripts/migrations/000_example_noop.sh
#
# Migración de ejemplo/referencia para validar el framework de migraciones
# (Hito 6, ver scripts/migrations/README.md para el contrato). No toca
# ninguna configuración real del usuario: solo escribe un archivo
# informativo dentro de su propio directorio de estado
# (.local/state/ubuntu-workstation/migrations/), para poder probar el ciclo
# completo (check/dry-run/apply/validate/rollback-notes) sin riesgo.
#
# La migración real NVM -> Mise (Hito 7) seguirá este mismo contrato, ver
# docs/adr/0003-migracion-nvm-sin-borrado-directo.md.
set -Eeuo pipefail

UCI_MIGRATION_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_MIGRATION_SCRIPT_DIR
# shellcheck source=../lib/logging.sh
source "${UCI_MIGRATION_SCRIPT_DIR}/../lib/logging.sh"

# UCI_HOME_DIR la exporta setup.sh; si esta migración se ejecuta suelta,
# se usa $HOME como default (ver docs/adr/0023-variable-uci-home-dir-para-pruebas.md).
UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
readonly UCI_HOME_DIR

UCI_MIGRATION_INFO_FILE="${UCI_HOME_DIR}/.local/state/ubuntu-workstation/migrations/000_example_noop.info"
readonly UCI_MIGRATION_INFO_FILE

migration_describe() {
    echo "Migración de ejemplo (no-op): no modifica nada real, valida el framework"
}

migration_check() {
    # Siempre "aplica": es una migración de demostración, no depende de que
    # exista ningún estado previo real del sistema.
    return 0
}

migration_dry_run() {
    log_info "[dry-run] escribiría ${UCI_MIGRATION_INFO_FILE}"
}

migration_apply() {
    mkdir -p "$(dirname "${UCI_MIGRATION_INFO_FILE}")"
    echo "Migración de ejemplo aplicada el $(date -Iseconds)" > "${UCI_MIGRATION_INFO_FILE}"
}

migration_validate() {
    [[ -f "${UCI_MIGRATION_INFO_FILE}" ]]
}

migration_rollback_notes() {
    echo "Para revertir: eliminar manualmente ${UCI_MIGRATION_INFO_FILE}"
    echo "(y, si quieres que vuelva a aparecer como pendiente, borrar también su marca .done)"
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
