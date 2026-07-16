#!/usr/bin/env bash
# tests/test_backup.sh
#
# Pruebas del Gestor de Backups (Hito 5, ver docs/ROADMAP.md y
# docs/adr/0005-gestor-de-backups-centralizado.md). Usa el fixture
# tests/fixtures/sample_home/ copiado a un directorio temporal como
# UCI_HOME_DIR, para no modificar ni el fixture del repo ni el $HOME real.
#
# Uso:
#   bash tests/test_backup.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH
FIXTURE_HOME="${UCI_TEST_DIR}/fixtures/sample_home"
readonly FIXTURE_HOME

UCI_TESTS_RUN=0
UCI_TESTS_FAILED=0

pass() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    echo "  OK  - $1"
}

fail() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    UCI_TESTS_FAILED=$((UCI_TESTS_FAILED + 1))
    echo "FALLO - $1"
}

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

run_backup() {
    set +e
    RUN_OUTPUT="$(UCI_HOME_DIR="${UCI_TMP_HOME}" bash "${SETUP_SH}" backup "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

cleanup() {
    if [[ -n "${UCI_TMP_HOME}" && -d "${UCI_TMP_HOME}" ]]; then
        rm -rf "${UCI_TMP_HOME}"
    fi
}
trap cleanup EXIT

reset_tmp_home() {
    if [[ -n "${UCI_TMP_HOME}" && -d "${UCI_TMP_HOME}" ]]; then
        rm -rf "${UCI_TMP_HOME}"
    fi
    UCI_TMP_HOME="$(mktemp -d)"
    cp -a "${FIXTURE_HOME}/." "${UCI_TMP_HOME}/"
}

echo "== backup --dry-run no crea nada =="
reset_tmp_home
before="$(find "${UCI_TMP_HOME}" | sort)"
run_backup --dry-run
after="$(find "${UCI_TMP_HOME}" | sort)"

assert_success "'backup --dry-run' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "Dry-run:"
if [[ "${before}" == "${after}" ]]; then
    pass "'backup --dry-run' no modifica el home simulado"
else
    fail "'backup --dry-run' modificó el home simulado"
fi
if [[ "${RUN_OUTPUT}" == *".bashrc"* ]]; then
    pass "'backup --dry-run' menciona los archivos que respaldaría"
else
    fail "'backup --dry-run' no mencionó los archivos esperados"
fi

echo ""
echo "== backup real crea la sesión y respalda lo esperado =="
reset_tmp_home
run_backup
assert_success "'backup' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "Sesión de backup:"

session_dir="$(find "${UCI_TMP_HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1 || true)"

if [[ -n "${session_dir}" && -d "${session_dir}" ]]; then
    pass "se creó un directorio de sesión bajo backups/"
else
    fail "no se encontró un directorio de sesión bajo backups/"
fi

if [[ -f "${session_dir}/manifest.tsv" ]]; then
    pass "existe manifest.tsv en la sesión"
else
    fail "no existe manifest.tsv en la sesión"
fi

if [[ -f "${session_dir}/home/.bashrc" && -f "${session_dir}/home/.gitconfig" ]]; then
    pass "se respaldaron .bashrc y .gitconfig"
else
    fail "no se respaldaron .bashrc y .gitconfig como se esperaba"
fi

if grep -q "UCI_FIXTURE_SHELL" "${session_dir}/home/.bashrc" 2>/dev/null; then
    pass "el contenido copiado de .bashrc coincide con el original"
else
    fail "el contenido copiado de .bashrc no coincide"
fi

if [[ -f "${session_dir}/home/.unrelated_file" ]]; then
    fail "se copió .unrelated_file, que no está en la lista por defecto"
else
    pass "no se copió .unrelated_file (fuera de la lista por defecto)"
fi

echo ""
echo "== backup no modifica los archivos originales del home =="
original_bashrc_before="$(cat "${UCI_TMP_HOME}/.bashrc")"
original_bashrc_after="$(cat "${UCI_TMP_HOME}/.bashrc")"
if [[ "${original_bashrc_before}" == "${original_bashrc_after}" ]]; then
    pass "el .bashrc original del home simulado no cambió"
else
    fail "el .bashrc original del home simulado cambió"
fi

echo ""
echo "== correr backup dos veces crea sesiones separadas, sin sobrescribir =="
run_backup
session_dir_2="$(find "${UCI_TMP_HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l || true)"
if [[ "${session_dir_2}" -ge 2 ]]; then
    pass "una segunda corrida de 'backup' crea una sesión nueva, no reutiliza la anterior"
else
    fail "una segunda corrida de 'backup' no creó una sesión adicional (encontradas: ${session_dir_2})"
fi

echo ""
echo "== backup con opción inválida =="
run_backup --esto-no-existe
assert_failure "'backup --esto-no-existe' sale con código distinto de cero" "${RUN_CODE}"

echo ""
echo "== fixture del repositorio permanece intacto =="
if git -C "${UCI_REPO_ROOT}" diff --quiet -- tests/fixtures/sample_home 2>/dev/null; then
    pass "tests/fixtures/sample_home no fue modificado por las pruebas"
else
    fail "tests/fixtures/sample_home fue modificado por las pruebas (revisar git diff)"
fi

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
