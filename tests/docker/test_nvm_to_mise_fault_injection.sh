#!/usr/bin/env bash
# tests/docker/test_nvm_to_mise_fault_injection.sh
#
# Caso M07 de docs/TEST_CASES.md: `apply` de la migración NVM -> Mise falla
# a mitad de camino. En vez de depender de cortar Internet de verdad, usa
# UCI_TEST_FAIL_MIGRATION_AT (variable exclusiva de pruebas, ver
# scripts/migrations/001_nvm_to_mise.sh) para inyectar el fallo en 5
# checkpoints distintos, y verifica en cada uno:
#
#   - la migración devuelve código distinto de cero;
#   - no se crea la marca .done;
#   - ~/.nvm no se pierde (intacto, o ya movido de forma segura al backup
#     si el fallo es el último checkpoint, después de moverlo);
#   - la sesión de backup del intento fallido se conserva;
#   - los archivos de shell quedan recuperables (originales intactos, o
#     limpiados pero con copia de respaldo de la versión original);
#   - una corrida posterior SIN la variable completa la migración, marca
#     .done, y no duplica el bloque gestionado de Mise en los archivos de
#     shell.
#
# Modelo de recuperación: reanudación idempotente, no rollback automático.
# Cada intento fallido deja su propia sesión de backup (nunca se
# sobreescribe ni se borra); `rollback-notes` sigue disponible para quien
# prefiera revertir manualmente.
#
# SOLO debe correr dentro de un contenedor Docker desechable: instala NVM y
# Node real varias veces, y esta migración instala Mise de verdad.
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_nvm_to_mise_fault_injection.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala NVM/Node/Mise de verdad varias veces. Solo debe" >&2
    echo "correr dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH
NVM_INSTALL_VERSION="v0.40.1"
readonly NVM_INSTALL_VERSION

FAILED=0
check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        echo "  OK  - ${description}"
    else
        echo "FALLO - ${description}"
        FAILED=1
    fi
}

backup_session_count() {
    find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l
}

mise_block_count() {
    grep -cF "# >>> ubuntu-workstation: mise >>>" "${HOME}/.bashrc" 2>/dev/null || true
}

# reset_environment
# Deja el $HOME del contenedor como si nunca se hubiera migrado ni
# instalado nada: sin NVM, sin Mise, sin backups ni marcas de migración
# previas. Instala NVM + una versión de Node reales, para partir del mismo
# estado inicial ("NVM instalado, sin Mise") en cada checkpoint.
reset_environment() {
    rm -rf "${HOME}/.nvm" "${HOME}/.local/bin/mise" "${HOME}/.local/share/mise" \
        "${HOME}/.config/mise" "${HOME}/.local/state/ubuntu-workstation"

    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash >/dev/null 2>&1
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck source=/dev/null
    source "${NVM_DIR}/nvm.sh"
    nvm install --lts >/dev/null 2>&1
}

# run_checkpoint <checkpoint> <descripcion>
run_checkpoint() {
    local checkpoint="$1" description="$2"

    echo ""
    echo "=========================================================="
    echo "== Checkpoint: ${checkpoint} — ${description}"
    echo "=========================================================="

    reset_environment

    echo "-- Estado antes de fallar: NVM instalado, sin Mise, sin backups --"
    check "~/.nvm existe antes de migrar" '[[ -d "${HOME}/.nvm" ]]'
    check "Mise NO existe antes de migrar" '[[ ! -x "${HOME}/.local/bin/mise" ]]'

    echo ""
    echo "-- 1. Corriendo 'migrate' con el fallo inyectado en '${checkpoint}' --"
    set +e
    UCI_TEST_FAIL_MIGRATION_AT="${checkpoint}" "${SETUP_SH}" migrate
    local first_run_code=$?
    set -e

    check "'migrate' devuelve código distinto de cero" '[[ ${first_run_code} -ne 0 ]]'
    check "no se creó la marca .done para 001_nvm_to_mise" '[[ ! -f "${HOME}/.local/state/ubuntu-workstation/migrations/001_nvm_to_mise.done" ]]'

    if [[ "${checkpoint}" == "before_done_marker" ]]; then
        # Este checkpoint falla en validate(), DESPUÉS de que apply() ya
        # movió .nvm de verdad: no está "perdido", quedó dentro del backup.
        check "~/.nvm ya no está en su ubicación original (apply alcanzó a moverlo)" '[[ ! -d "${HOME}/.nvm" ]]'
        check "~/.nvm quedó recuperable dentro de la sesión de backup" \
            'find "${HOME}/.local/state/ubuntu-workstation/backups" -maxdepth 3 -type d -name ".nvm" 2>/dev/null | grep -q .'
    else
        check "~/.nvm sigue intacto en su ubicación original (no se llegó a mover)" '[[ -d "${HOME}/.nvm" ]]'
    fi

    check "la sesión de backup del intento fallido se conserva (al menos 1)" '[[ "$(backup_session_count)" -ge 1 ]]'

    local rc_backup
    rc_backup="$(find "${HOME}/.local/state/ubuntu-workstation/backups" -maxdepth 3 -type f -name '.bashrc' 2>/dev/null | head -n1)"
    check "el .bashrc original quedó respaldado y es recuperable" '[[ -n "${rc_backup}" && -f "${rc_backup}" ]]'

    echo ""
    echo "-- 2. Reintentando SIN la variable de inyección de fallos --"
    set +e
    "${SETUP_SH}" migrate
    local retry_code=$?
    set -e

    check "el reintento sin fallo inyectado termina en código 0" '[[ ${retry_code} -eq 0 ]]'
    check "ahora sí existe la marca .done" '[[ -f "${HOME}/.local/state/ubuntu-workstation/migrations/001_nvm_to_mise.done" ]]'
    check "~/.nvm ya no existe (migración completada)" '[[ ! -d "${HOME}/.nvm" ]]'
    check "Mise resuelve un ejecutable de node tras completar" \
        '[[ -n "$("${HOME}/.local/bin/mise" which node 2>/dev/null)" ]]'
    check "el bloque gestionado de Mise no quedó duplicado en .bashrc" '[[ "$(mise_block_count)" -eq 1 ]]'
    check "quedaron al menos 2 sesiones de backup (intento fallido + intento exitoso), ninguna borrada" '[[ "$(backup_session_count)" -ge 2 ]]'
}

run_checkpoint "after_shell_backup" "falla justo después de respaldar .bashrc/.zshrc/.profile"
run_checkpoint "before_mise_install" "falla antes de instalar Mise"
run_checkpoint "after_mise_before_node" "falla después de instalar Mise, antes de instalar Node"
run_checkpoint "after_node_before_move" "falla después de instalar Node, antes de mover .nvm"
run_checkpoint "before_done_marker" "falla en la validación final, antes de marcar .done (apply ya movió .nvm)"

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: la migración se recupera correctamente en los 5 checkpoints de fallo parcial."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
