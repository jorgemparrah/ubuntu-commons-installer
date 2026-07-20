#!/usr/bin/env bash
# tests/test_doctor.sh
#
# Pruebas no destructivas del comando `doctor` (Hito 4, ver docs/ROADMAP.md).
# No instala nada, no modifica el $HOME real: las corridas que sí podrían
# tocar el filesystem se ejecutan contra un $HOME temporal y vacío, y se
# verifica que quede exactamente igual después de correr doctor.
#
# Uso:
#   bash tests/test_doctor.sh
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

# Ejecuta `setup.sh doctor <args...>` con un $HOME temporal y vacío, y deja
# el resultado en RUN_OUTPUT/RUN_CODE. Aísla `set +e`/`set -e` alrededor de
# la captura (ver tests/test_router.sh para la justificación).
RUN_OUTPUT=""
RUN_CODE=0
UCI_TMP_HOME=""

run_doctor() {
    run_doctor_in_home "${UCI_TMP_HOME}" "$@"
}

# run_doctor_in_home <home_dir> <args...>
# Igual que run_doctor, pero contra un home distinto de UCI_TMP_HOME (que
# es readonly) — usado para probar el chequeo de symlinks rotos con un
# $HOME temporal propio, sin reasignar la variable readonly.
run_doctor_in_home() {
    local home_dir="$1"
    shift
    set +e
    RUN_OUTPUT="$(UCI_HOME_DIR="${home_dir}" bash "${SETUP_SH}" doctor "$@" 2>&1)"
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

echo "== doctor: ejecución básica =="

run_doctor
assert_success "'doctor' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "Ubuntu Workstation - Doctor"
assert_success "'doctor' reporta el sistema operativo" "${RUN_OUTPUT}" "${RUN_CODE}" "Sistema operativo:"
assert_success "'doctor' reporta indicadores de home retenido" "${RUN_OUTPUT}" "${RUN_CODE}" "Indicadores de home retenido:"

echo ""
echo "== doctor --verbose =="

run_doctor --verbose
assert_success "'doctor --verbose' sale con código 0" "${RUN_OUTPUT}" "${RUN_CODE}" "Ubuntu Workstation - Doctor"
if [[ "${RUN_OUTPUT}" == *"${UCI_TMP_HOME}/.nvm"* ]]; then
    pass "'doctor --verbose' detalla las rutas individuales de home retenido"
else
    fail "'doctor --verbose' no mostró el detalle de rutas de home retenido"
fi

echo ""
echo "== doctor: Framework de validación (Hito 12) =="

run_doctor
assert_success "'doctor' reporta el chequeo de PATH" "${RUN_OUTPUT}" "${RUN_CODE}" "PATH:"
assert_success "'doctor' reporta el chequeo de ejecutables del catálogo" "${RUN_OUTPUT}" "${RUN_CODE}" "Ejecutables (catálogo):"
assert_success "'doctor' reporta el chequeo de dependencias compartidas" "${RUN_OUTPUT}" "${RUN_CODE}" "Dependencias compartidas:"
assert_success "'doctor' reporta el chequeo de symlinks rotos" "${RUN_OUTPUT}" "${RUN_CODE}" "Symlinks rotos en \$HOME:"
assert_success "'doctor' reporta versiones de runtime vía Mise" "${RUN_OUTPUT}" "${RUN_CODE}" "Versiones de runtime (Mise):"

if [[ "${RUN_OUTPUT}" =~ Ejecutables\ \(catálogo\):[[:space:]]+([0-9]+)/([0-9]+)\ scripts ]]; then
    if [[ "${BASH_REMATCH[1]}" == "${BASH_REMATCH[2]}" ]]; then
        pass "todos los scripts registrados en tools_catalog.sh existen y son ejecutables (${BASH_REMATCH[1]}/${BASH_REMATCH[2]})"
    else
        fail "hay scripts registrados en tools_catalog.sh sin +x o inexistentes (${BASH_REMATCH[1]}/${BASH_REMATCH[2]})"
    fi
else
    fail "no se pudo parsear el resultado del chequeo de ejecutables"
fi

echo ""
echo "== doctor --verbose detalla symlinks rotos si los hay =="

UCI_SYMLINK_HOME="$(mktemp -d)"
ln -s "${UCI_SYMLINK_HOME}/no-existe" "${UCI_SYMLINK_HOME}/roto"
run_doctor_in_home "${UCI_SYMLINK_HOME}" --verbose
rm -rf "${UCI_SYMLINK_HOME}"

if [[ "${RUN_OUTPUT}" =~ Symlinks\ rotos\ en\ \$HOME:[[:space:]]+([0-9]+)\ detectado ]] && [[ "${BASH_REMATCH[1]}" -ge 1 ]]; then
    pass "'doctor --verbose' detecta al menos 1 symlink roto en un \$HOME con uno (${BASH_REMATCH[1]})"
else
    fail "'doctor --verbose' no detectó el symlink roto esperado"
fi
assert_success "'doctor --verbose' detalla la ruta del symlink roto" "${RUN_OUTPUT}" "${RUN_CODE}" "✗"

echo ""
echo "== doctor con opción inválida =="

run_doctor --esto-no-existe
assert_failure "'doctor --esto-no-existe' sale con código distinto de cero" "${RUN_CODE}"

echo ""
echo "== doctor no modifica \$HOME =="

before="$(find "${UCI_TMP_HOME}" | sort)"
run_doctor --verbose
after="$(find "${UCI_TMP_HOME}" | sort)"

if [[ "${before}" == "${after}" ]]; then
    pass "el contenido de \$HOME es idéntico antes y después de 'doctor --verbose'"
else
    fail "el contenido de \$HOME cambió después de correr 'doctor --verbose'"
fi

print_test_summary

exit_with_test_summary
