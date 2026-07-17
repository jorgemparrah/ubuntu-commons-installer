#!/usr/bin/env bash
# tests/docker/test_kubectl_via_mise.sh
#
# Prueba funcional de scripts/development/install_kubectl.sh (Hito 9, Fase
# B): confirma que kubectl se instala vía Mise (ver
# docs/adr/0018-kubectl-via-mise.md), no vía Snap, cerrando la deuda de
# implementación detectada en docs/UBUNTU_COMPATIBILITY.md. SOLO debe
# correr dentro de un contenedor Docker desechable (instala Mise/kubectl
# de verdad).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_kubectl_via_mise.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/kubectl de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_KUBECTL_SH="${UCI_REPO_ROOT}/scripts/development/install_kubectl.sh"
readonly INSTALL_KUBECTL_SH

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
OUTPUT="$("${INSTALL_KUBECTL_SH}" status 2>&1)" || true
CODE=$?
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_KUBECTL_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía Mise) =="
"${INSTALL_KUBECTL_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. status después de instalar =="
OUTPUT="$("${INSTALL_KUBECTL_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 5. kubectl se instaló vía Mise, no vía Snap (ADR 0018) =="
MISE_KUBECTL="$("${HOME}/.local/bin/mise" which kubectl 2>/dev/null || true)"
check "Mise resuelve un ejecutable de kubectl" '[[ -n "${MISE_KUBECTL}" && -x "${MISE_KUBECTL}" ]]'
check "no se usó snap para instalar kubectl (no aparece en 'snap list')" '! snap list 2>/dev/null | grep -q "^kubectl "'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_KUBECTL_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: kubectl se instala vía Mise, nunca vía Snap."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
