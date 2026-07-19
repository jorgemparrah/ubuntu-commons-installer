#!/usr/bin/env bash
# tests/test_router.sh
#
# Pruebas no destructivas del router de comandos y el preflight introducidos
# en el Hito 2 (Bootstrap, ver docs/ROADMAP.md). No instalan nada, no editan
# archivos dentro de $HOME y no ejecutan instaladores reales.
#
# Uso:
#   bash tests/test_router.sh
#
# Salida: imprime OK/FALLO por cada caso y termina con código 0 si todo pasó,
# o 1 si algo falló.
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
    local description="$1" output="$2" exit_code="$3" expected_substring="${4:-}"

    if [[ "${exit_code}" -eq 0 ]]; then
        fail "${description} (código de salida 0, se esperaba distinto de cero)"
        return
    fi
    if [[ -n "${expected_substring}" && "${output}" != *"${expected_substring}"* ]]; then
        fail "${description} (no se encontró '${expected_substring}' en la salida)"
        return
    fi
    pass "${description}"
}

test_syntax() {
    local file="$1"
    local rel="${file#"${UCI_REPO_ROOT}"/}"
    local err
    if err="$(bash -n "${file}" 2>&1)"; then
        pass "sintaxis válida: ${rel}"
    else
        fail "sintaxis inválida: ${rel} -> ${err}"
    fi
}

# Ejecuta setup.sh con los argumentos dados, en el directorio y con el PATH
# indicados, y deja el resultado en las variables globales RUN_OUTPUT y
# RUN_CODE. Aísla `set +e`/`set -e` alrededor de la captura: bajo el modo
# estricto de este script de pruebas, `var=$(cmd)` con `cmd` fallando (por
# ejemplo, el caso de comando desconocido, que debe salir con código != 0)
# dispararía `set -e` y cortaría las pruebas antes de poder revisarlo.
RUN_OUTPUT=""
RUN_CODE=0
run_setup() {
    local dir="$1" path_value="$2"
    shift 2
    set +e
    RUN_OUTPUT="$(cd "${dir}" && PATH="${path_value}" bash "${SETUP_SH}" "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== Sintaxis =="
test_syntax "${SETUP_SH}"
while IFS= read -r -d '' script; do
    test_syntax "${script}"
done < <(find "${UCI_REPO_ROOT}/scripts" -type f -name '*.sh' -print0)

echo ""
if command -v shellcheck >/dev/null 2>&1; then
    echo "== ShellCheck (disponible en esta máquina) =="
    if shellcheck "${SETUP_SH}" "${UCI_REPO_ROOT}/scripts/lib/logging.sh" "${UCI_REPO_ROOT}/scripts/bootstrap/preflight.sh"; then
        pass "shellcheck sin hallazgos en setup.sh, scripts/lib/logging.sh y scripts/bootstrap/preflight.sh"
    else
        fail "shellcheck reportó hallazgos (ver salida arriba)"
    fi
else
    echo "ShellCheck no está disponible; se omite (no se instala automáticamente)."
fi

echo ""
echo "== Router de comandos =="

run_setup "${UCI_REPO_ROOT}" "${PATH}" help
assert_success "'help' sale con código 0 y muestra el uso" "${RUN_OUTPUT}" "${RUN_CODE}" "Uso:"

run_setup "${UCI_REPO_ROOT}" "${PATH}" --help
assert_success "'--help' sale con código 0 y muestra el uso" "${RUN_OUTPUT}" "${RUN_CODE}" "Uso:"

run_setup "${UCI_REPO_ROOT}" "${PATH}" version
assert_success "'version' sale con código 0 y muestra el nombre del proyecto" "${RUN_OUTPUT}" "${RUN_CODE}" "Ubuntu Workstation"

run_setup "${UCI_REPO_ROOT}" "${PATH}" esto-no-existe
assert_failure "comando desconocido sale con código distinto de cero" "${RUN_OUTPUT}" "${RUN_CODE}" "Comando desconocido"

echo ""
echo "== Ejecución desde otro directorio =="

run_setup "/tmp" "${PATH}" help
assert_success "'help' funciona ejecutado desde /tmp" "${RUN_OUTPUT}" "${RUN_CODE}" "Uso:"

echo ""
echo "== Ayuda y versión sin Node.js disponible en PATH =="
# PATH mínimo (solo /usr/bin y /bin) para simular una sesión de shell donde
# Node.js todavía no está disponible (por ejemplo, antes de inicializar
# NVM/Mise). Si en tu máquina Node.js vive directamente en /usr/bin o /bin,
# ajusta este PATH antes de correr la prueba.
run_setup "${UCI_REPO_ROOT}" "/usr/bin:/bin" help
assert_success "'help' funciona con un PATH sin Node.js" "${RUN_OUTPUT}" "${RUN_CODE}" "Uso:"

run_setup "${UCI_REPO_ROOT}" "/usr/bin:/bin" version
assert_success "'version' funciona con un PATH sin Node.js" "${RUN_OUTPUT}" "${RUN_CODE}" "Ubuntu Workstation"

print_test_summary

exit_with_test_summary
