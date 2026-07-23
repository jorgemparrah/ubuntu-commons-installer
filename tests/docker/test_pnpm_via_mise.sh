#!/usr/bin/env bash
# tests/docker/test_pnpm_via_mise.sh
#
# Prueba funcional de scripts/development/install_pnpm.sh (Hito 42): pnpm
# se instala vía Mise, mismo mecanismo que Yarn (ver
# docs/adr/0017-mise-instala-yarn-pnpm-directo.md). SOLO debe correr
# dentro de un contenedor Docker desechable (instala Mise/pnpm de verdad).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_pnpm_via_mise.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/pnpm de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_PNPM_SH="${UCI_REPO_ROOT}/scripts/development/install_pnpm.sh"
readonly INSTALL_PNPM_SH

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

echo "== 1. status antes de instalar =="
set +e
OUTPUT="$("${INSTALL_PNPM_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_PNPM_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía Mise) =="
"${INSTALL_PNPM_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. status después de instalar =="
OUTPUT="$("${INSTALL_PNPM_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 5. pnpm se instaló vía Mise, no es un paquete de apt =="
MISE_PNPM="$("${HOME}/.local/bin/mise" which pnpm 2>/dev/null || true)"
check "Mise resuelve un ejecutable de pnpm" '[[ -n "${MISE_PNPM}" && -x "${MISE_PNPM}" ]]'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_PNPM_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 7. update/reinstall =="
"${INSTALL_PNPM_SH}" update
UPDATE_CODE=$?
check "'update' sale con código 0" '[[ ${UPDATE_CODE} -eq 0 ]]'
"${INSTALL_PNPM_SH}" reinstall
REINSTALL_CODE=$?
check "'reinstall' (fallback mecánico del dispatcher) sale con código 0" '[[ ${REINSTALL_CODE} -eq 0 ]]'
OUTPUT="$("${INSTALL_PNPM_SH}" status 2>&1)"
check "'status' reporta INSTALLED después de 'reinstall'" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
set +e
"${INSTALL_PNPM_SH}" repair >/dev/null 2>&1
REPAIR_CODE=$?
set -e
check "'repair' se rechaza explícitamente (no implementado a propósito)" '[[ ${REPAIR_CODE} -ne 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: pnpm se instala vía Mise."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
