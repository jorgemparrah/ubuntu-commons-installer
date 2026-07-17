#!/usr/bin/env bash
# tests/test_cursor_arch_check.sh
#
# Validación estática (Hito 9, Fase B) de scripts/editors/install_cursor.sh:
# confirma por revisión del código fuente (grep), sin ejecutar el
# instalador, que existe una revisión de arquitectura y que ocurre antes
# de cualquier descarga/escritura — antes este script instalaba el
# AppImage x86_64 sin verificar la arquitectura real, dejando un binario
# incompatible en silencio en cualquier host arm64 (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md). El comportamiento real en tiempo de
# ejecución (rechazo en arm64, instalación completa en x86_64) queda
# pendiente de una prueba funcional en Docker si se agrega esa cobertura
# más adelante — este script nunca se ejecuta, ni siquiera parcialmente,
# fuera de un contenedor Docker desechable.
#
# Uso:
#   bash tests/test_cursor_arch_check.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_CURSOR_SH="${UCI_REPO_ROOT}/scripts/editors/install_cursor.sh"
readonly INSTALL_CURSOR_SH

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

echo "== existe una función que revisa la arquitectura vía 'uname -m' =="
if grep -q 'check_architecture_supported' "${INSTALL_CURSOR_SH}" && grep -q 'uname -m' "${INSTALL_CURSOR_SH}"; then
    pass "install_cursor.sh define una revisión de arquitectura basada en 'uname -m'"
else
    fail "no se encontró una revisión de arquitectura basada en 'uname -m'"
fi

echo ""
echo "== la revisión rechaza explícitamente cualquier arquitectura distinta de x86_64 =="
if grep -q '!= "x86_64"' "${INSTALL_CURSOR_SH}"; then
    pass "la condición de rechazo compara explícitamente contra x86_64"
else
    fail "no se encontró una comparación explícita contra x86_64"
fi

echo ""
echo "== install_tool() llama a la revisión de arquitectura antes de cualquier descarga/mkdir/sudo =="
ARCH_CALL_LINE="$(grep -n '^\s*if ! check_architecture_supported' "${INSTALL_CURSOR_SH}" | head -1 | cut -d: -f1)"
FIRST_WGET_LINE="$(grep -n '\bwget\b' "${INSTALL_CURSOR_SH}" | head -1 | cut -d: -f1)"
FIRST_MKDIR_LINE="$(grep -n '\bmkdir\b' "${INSTALL_CURSOR_SH}" | head -1 | cut -d: -f1)"

if [[ -n "${ARCH_CALL_LINE}" ]]; then
    pass "install_tool() invoca la revisión de arquitectura (línea ${ARCH_CALL_LINE})"
else
    fail "install_tool() no invoca la revisión de arquitectura"
fi

if [[ -n "${ARCH_CALL_LINE}" && -n "${FIRST_WGET_LINE}" && "${ARCH_CALL_LINE}" -lt "${FIRST_WGET_LINE}" ]]; then
    pass "la revisión de arquitectura ocurre antes de la primera descarga (wget en línea ${FIRST_WGET_LINE})"
else
    fail "no se pudo confirmar que la revisión de arquitectura ocurre antes de la descarga (arch=${ARCH_CALL_LINE:-?}, wget=${FIRST_WGET_LINE:-?})"
fi

if [[ -n "${ARCH_CALL_LINE}" && -n "${FIRST_MKDIR_LINE}" && "${ARCH_CALL_LINE}" -lt "${FIRST_MKDIR_LINE}" ]]; then
    pass "la revisión de arquitectura ocurre antes del primer mkdir (línea ${FIRST_MKDIR_LINE})"
else
    fail "no se pudo confirmar que la revisión de arquitectura ocurre antes del primer mkdir (arch=${ARCH_CALL_LINE:-?}, mkdir=${FIRST_MKDIR_LINE:-?})"
fi

echo ""
echo "== el mensaje de rechazo es claro (menciona x86_64) =="
if grep -A3 'check_architecture_supported()' "${INSTALL_CURSOR_SH}" | grep -q 'x86_64'; then
    pass "el mensaje de error menciona x86_64"
else
    fail "no se encontró un mensaje claro mencionando x86_64"
fi

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"
echo "Nota: validación puramente estática (grep), sin ejecutar install_cursor.sh en ningún momento."

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
