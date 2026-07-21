#!/usr/bin/env bash
# tests/test_dependencies_lib.sh
#
# Pruebas no destructivas de scripts/lib/dependencies.sh (Hito 17, ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md). No
# instala nada real: usa fixtures (scripts temporales que solo imprimen un
# estado fijo ante 'status') en vez de instaladores reales.
#
# Uso:
#   bash tests/test_dependencies_lib.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
DEPENDENCIES_SH="${UCI_REPO_ROOT}/scripts/lib/dependencies.sh"
readonly DEPENDENCIES_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
# shellcheck source=../scripts/lib/dependencies.sh
source "${DEPENDENCIES_SH}"

UCI_FIXTURE_DIR="$(mktemp -d)"
readonly UCI_FIXTURE_DIR
cleanup() {
    rm -rf "${UCI_FIXTURE_DIR}"
}
trap cleanup EXIT

# make_status_fixture <estado>
# Escribe un script falso cuyo único subcomando ('status') imprime
# <estado> y sale con 0 si es INSTALLED/OUTDATED, 1 en cualquier otro caso
# (mismo contrato de docs/adr/0012-modelo-de-estado-enriquecido.md).
make_status_fixture() {
    local status="$1"
    local fixture="${UCI_FIXTURE_DIR}/fixture_${RANDOM}.sh"
    {
        echo "#!/usr/bin/env bash"
        echo "echo '${status}'"
        if [[ "${status}" == "INSTALLED" || "${status}" == "OUTDATED" ]]; then
            echo "exit 0"
        else
            echo "exit 1"
        fi
    } > "${fixture}"
    chmod +x "${fixture}"
    echo "${fixture}"
}

echo "== dependency_is_installed =="
for status in INSTALLED OUTDATED; do
    fixture="$(make_status_fixture "${status}")"
    if dependency_is_installed "${fixture}"; then
        pass "dependency_is_installed reporta instalado para '${status}'"
    else
        fail "dependency_is_installed debería reportar instalado para '${status}'"
    fi
done
for status in NOT_INSTALLED BROKEN UNSUPPORTED UNKNOWN; do
    fixture="$(make_status_fixture "${status}")"
    if ! dependency_is_installed "${fixture}"; then
        pass "dependency_is_installed reporta NO instalado para '${status}'"
    else
        fail "dependency_is_installed debería reportar NO instalado para '${status}'"
    fi
done

echo ""
echo "== dependency_is_installed nunca confunde NOT_INSTALLED con INSTALLED (bug de subcadena, ver Hito 13) =="
fixture="$(make_status_fixture "NOT_INSTALLED")"
if ! dependency_is_installed "${fixture}"; then
    pass "'NOT_INSTALLED' (que contiene la subcadena 'INSTALLED') se reporta correctamente como NO instalado"
else
    fail "'NOT_INSTALLED' se confundió con instalado (mismo bug ya corregido en setup.sh)"
fi

echo ""
echo "== dependency_require_installed =="
fixture_ok="$(make_status_fixture "INSTALLED")"
if dependency_require_installed "${fixture_ok}" "Dependencia de Prueba"; then
    pass "dependency_require_installed no rechaza cuando la dependencia está instalada"
else
    fail "dependency_require_installed no debería rechazar cuando la dependencia está instalada"
fi

fixture_missing="$(make_status_fixture "NOT_INSTALLED")"
set +e
OUTPUT="$(dependency_require_installed "${fixture_missing}" "Dependencia de Prueba" 2>&1)"
code=$?
set -e
if [[ "${code}" -ne 0 ]]; then
    pass "dependency_require_installed rechaza (código distinto de cero) cuando falta la dependencia"
else
    fail "dependency_require_installed debería rechazar cuando falta la dependencia"
fi
if [[ "${OUTPUT}" == *"Dependencia de Prueba"* ]] && [[ "${OUTPUT}" == *"0042"* ]]; then
    pass "el mensaje de rechazo nombra la dependencia faltante y cita ADR 0042"
else
    fail "el mensaje de rechazo no fue lo bastante explícito. Salida: ${OUTPUT}"
fi

print_test_summary
exit_with_test_summary
