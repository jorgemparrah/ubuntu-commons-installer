#!/usr/bin/env bash
# tests/test_migrations.sh
#
# Pruebas del framework de migraciones (Hito 6, ver docs/ROADMAP.md y
# docs/adr/0006-framework-de-migraciones-versionado.md). Usa la migración de
# referencia scripts/migrations/000_example_noop.sh, que no toca nada real,
# y corre siempre contra un UCI_HOME_DIR temporal, nunca contra el $HOME real.
#
# Uso:
#   bash tests/test_migrations.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
assert_success() {
    local description="$1" output="$2" exit_code="$3" expected_substring="${4:-}"

    if [[ "${exit_code}" -ne 0 ]]; then
        fail "${description} (código de salida ${exit_code}, se esperaba 0)"
        return
    fi
    if [[ -n "${expected_substring}" && "${output}" != *"${expected_substring}"* ]]; then
        fail "${description} (no se encontró '${expected_substring}' en la salida)"
        return
    fi
    pass "${description}"
}

assert_failure() {
    local description="$1" exit_code="$2"

    if [[ "${exit_code}" -eq 0 ]]; then
        fail "${description} (código de salida 0, se esperaba distinto de cero)"
        return
    fi
    pass "${description}"
}

RUN_OUTPUT=""
RUN_CODE=0
UCI_TMP_HOME=""

run_migrate() {
    set +e
    RUN_OUTPUT="$(UCI_HOME_DIR="${UCI_TMP_HOME}" bash "${SETUP_SH}" migrate "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

cleanup() {
    if [[ -n "${UCI_TMP_HOME}" && -d "${UCI_TMP_HOME}" ]]; then
        rm -rf "${UCI_TMP_HOME}"
    fi
}
trap cleanup EXIT

UCI_TMP_HOME="$(mktemp -d)"
readonly UCI_TMP_HOME
MARKER="${UCI_TMP_HOME}/.local/state/ubuntu-workstation/migrations/000_example_noop.done"
INFO_FILE="${UCI_TMP_HOME}/.local/state/ubuntu-workstation/migrations/000_example_noop.info"

echo "== migrate --list antes de aplicar nada =="
run_migrate --list
assert_success "'migrate --list' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "000_example_noop"
if [[ "${RUN_OUTPUT}" == *"pendiente"* ]]; then
    pass "la migración de referencia aparece como 'pendiente'"
else
    fail "la migración de referencia no aparece como 'pendiente'"
fi

echo ""
echo "== migrate --dry-run no modifica nada =="
before="$(find "${UCI_TMP_HOME}" | sort)"
run_migrate --dry-run
after="$(find "${UCI_TMP_HOME}" | sort)"
assert_success "'migrate --dry-run' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "dry-run"
if [[ "${before}" == "${after}" ]]; then
    pass "'migrate --dry-run' no creó ni modificó nada en el home simulado"
else
    fail "'migrate --dry-run' modificó el home simulado"
fi
if [[ -f "${MARKER}" ]]; then
    fail "'migrate --dry-run' dejó una marca de finalización (no debería)"
else
    pass "'migrate --dry-run' no dejó marca de finalización"
fi

echo ""
echo "== migrate (apply) aplica y valida la migración de referencia =="
run_migrate
assert_success "'migrate' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "completada y validada"

if [[ -f "${MARKER}" ]]; then
    pass "se creó la marca de finalización tras aplicar"
else
    fail "no se creó la marca de finalización tras aplicar"
fi

if [[ -f "${INFO_FILE}" ]]; then
    pass "la migración de referencia escribió su archivo informativo"
else
    fail "la migración de referencia no escribió su archivo informativo"
fi

echo ""
echo "== migrate --list después de aplicar =="
run_migrate --list
if [[ "${RUN_OUTPUT}" == *"hecha"* ]]; then
    pass "la migración de referencia ahora aparece como 'hecha'"
else
    fail "la migración de referencia no aparece como 'hecha' tras aplicarla"
fi

echo ""
echo "== correr migrate de nuevo no reaplica (idempotencia) =="
info_before="$(cat "${INFO_FILE}")"
run_migrate
info_after="$(cat "${INFO_FILE}")"
assert_success "correr 'migrate' de nuevo sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" ""
if [[ "${info_before}" == "${info_after}" ]]; then
    pass "el contenido del archivo informativo no cambió (no se reaplicó)"
else
    fail "el archivo informativo cambió: la migración se reaplicó"
fi

echo ""
echo "== migrate con opción inválida =="
run_migrate --esto-no-existe
assert_failure "'migrate --esto-no-existe' sale con código distinto de cero" "${RUN_CODE}"

print_test_summary

exit_with_test_summary
