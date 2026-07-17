#!/usr/bin/env bash
# tests/docker/test_yarn_via_mise.sh
#
# Prueba funcional de scripts/development/install_yarn.sh (Hito 9, Fase B):
# confirma que Yarn se instala vía Mise (ver
# docs/adr/0017-mise-instala-yarn-pnpm-directo.md), no vía apt (el paquete
# `yarn` de Ubuntu es en realidad `cmdtest`, un bug preexistente detectado
# en docs/UBUNTU_COMPATIBILITY.md). SOLO debe correr dentro de un
# contenedor Docker desechable (instala Mise/Yarn de verdad).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_yarn_via_mise.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/Yarn de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_YARN_SH="${UCI_REPO_ROOT}/scripts/development/install_yarn.sh"
readonly INSTALL_YARN_SH

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
OUTPUT="$("${INSTALL_YARN_SH}" status 2>&1)" || true
CODE=$?
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_YARN_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía Mise) =="
"${INSTALL_YARN_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. status después de instalar =="
OUTPUT="$("${INSTALL_YARN_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'

echo ""
echo "== 5. Yarn se instaló vía Mise, no es el paquete 'cmdtest' de apt =="
MISE_YARN="$("${HOME}/.local/bin/mise" which yarn 2>/dev/null || true)"
check "Mise resuelve un ejecutable de yarn" '[[ -n "${MISE_YARN}" && -x "${MISE_YARN}" ]]'
check "no se instaló el paquete 'yarn' de apt (que en Ubuntu es cmdtest)" '! dpkg -s yarn &>/dev/null'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_YARN_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: Yarn se instala vía Mise, nunca vía el paquete apt equivocado."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
