#!/usr/bin/env bash
# tests/docker/test_gh_via_mise.sh
#
# Prueba funcional de scripts/development/install_gh.sh (Hito 16): confirma
# que gh (GitHub CLI) se instala vía Mise, no vía apt (ver
# docs/adr/0033-mise-amplia-su-rol-a-clis-via-registry.md y
# docs/adr/0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md), aunque el
# paquete `gh` también existe en el repositorio oficial de Ubuntu
# (universe). SOLO debe correr dentro de un contenedor Docker desechable
# (instala Mise/gh de verdad).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_gh_via_mise.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/gh de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_GH_SH="${UCI_REPO_ROOT}/scripts/development/install_gh.sh"
readonly INSTALL_GH_SH

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
OUTPUT="$("${INSTALL_GH_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_GH_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía Mise) =="
"${INSTALL_GH_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. status después de instalar =="
OUTPUT="$("${INSTALL_GH_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 5. gh se instaló vía Mise, no vía el paquete apt =="
MISE_GH="$("${HOME}/.local/bin/mise" which gh 2>/dev/null || true)"
check "Mise resuelve un ejecutable de gh" '[[ -n "${MISE_GH}" && -x "${MISE_GH}" ]]'
check "no se instaló el paquete 'gh' de apt" '! dpkg -s gh &>/dev/null'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_GH_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 7. update/reinstall (grupo Mise: migrado al dispatcher compartido) =="
"${INSTALL_GH_SH}" update
UPDATE_CODE=$?
check "'update' sale con código 0" '[[ ${UPDATE_CODE} -eq 0 ]]'
"${INSTALL_GH_SH}" reinstall
REINSTALL_CODE=$?
check "'reinstall' (fallback mecánico del dispatcher) sale con código 0" '[[ ${REINSTALL_CODE} -eq 0 ]]'
OUTPUT="$("${INSTALL_GH_SH}" status 2>&1)"
check "'status' reporta INSTALLED después de 'reinstall'" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
set +e
"${INSTALL_GH_SH}" repair >/dev/null 2>&1
REPAIR_CODE=$?
set -e
check "'repair' se rechaza explícitamente (no implementado a propósito)" '[[ ${REPAIR_CODE} -ne 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: gh se instala vía Mise, nunca vía el paquete apt de Ubuntu."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
