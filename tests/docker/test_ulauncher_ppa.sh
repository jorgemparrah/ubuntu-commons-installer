#!/usr/bin/env bash
# tests/docker/test_ulauncher_ppa.sh
#
# Prueba funcional de scripts/productivity/install_ulauncher.sh (Hito 9,
# Fase B): antes nunca agregaba el PPA que ulauncher necesita y
# 'apt install ulauncher' fallaba siempre (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md). Confirma que ahora agrega el PPA oficial
# y el paquete se instala de verdad. SOLO debe correr dentro de un
# contenedor Docker desechable (agrega un PPA e instala paquetes reales).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_ulauncher_ppa.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script agrega un PPA e instala paquetes de verdad. Solo debe" >&2
    echo "correr dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_ULAUNCHER_SH="${UCI_REPO_ROOT}/scripts/productivity/install_ulauncher.sh"
readonly INSTALL_ULAUNCHER_SH

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
OUTPUT="$("${INSTALL_ULAUNCHER_SH}" status 2>&1)" || true
CODE=$?
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_ULAUNCHER_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, agrega el PPA oficial) =="
"${INSTALL_ULAUNCHER_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'
check "el PPA de ulauncher quedó agregado" 'grep -rq "agornostal/ulauncher" /etc/apt/sources.list.d/ 2>/dev/null'

echo ""
echo "== 4. status después de instalar =="
OUTPUT="$("${INSTALL_ULAUNCHER_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'
check "el binario 'ulauncher' quedó disponible" 'command -v ulauncher &>/dev/null'

echo ""
echo "== 5. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_ULAUNCHER_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: ulauncher se instala correctamente agregando su PPA oficial."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
