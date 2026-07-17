#!/usr/bin/env bash
# tests/docker/test_cursor_apt_repo.sh
#
# Prueba funcional de scripts/editors/install_cursor.sh (Hito 9, Fase B):
# Cursor pasó de un AppImage descargado directamente (fijo a x86_64, sin
# checksum) a su repositorio APT oficial (downloads.cursor.com/aptrepo),
# con clave GPG moderna (signed-by + keyring, nunca apt-key) y soporte
# amd64/arm64. SOLO debe correr dentro de un contenedor Docker desechable
# (agrega una clave GPG, un repo APT, e instala un paquete real).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_cursor_apt_repo.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script agrega un repo APT e instala un paquete real. Solo debe" >&2
    echo "correr dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_CURSOR_SH="${UCI_REPO_ROOT}/scripts/editors/install_cursor.sh"
readonly INSTALL_CURSOR_SH

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
OUTPUT="$("${INSTALL_CURSOR_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_CURSOR_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía el repo APT oficial de Cursor) =="
"${INSTALL_CURSOR_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. el mecanismo es moderno: signed-by + keyring, nunca apt-key =="
# El propio paquete de Cursor puede tomar el control de su entrada de
# repositorio después de instalarse (ver nota en install_cursor.sh), así
# que no se asume que el archivo que agregamos a mano siga existiendo
# igual — se busca la evidencia de 'signed-by' en cualquier archivo de
# sources.list.d que mencione el repo de Cursor, no en uno específico.
CURSOR_SOURCE_FILES="$(grep -rl "downloads.cursor.com/aptrepo" /etc/apt/sources.list.d/ 2>/dev/null || true)"
check "queda al menos un archivo de repo apuntando a Cursor" '[[ -n "${CURSOR_SOURCE_FILES}" ]]'
check "el/los archivo(s) de repo de Cursor usan 'signed-by' (nunca apt-key)" 'echo "${CURSOR_SOURCE_FILES}" | xargs -r grep -l "signed-by=" | grep -q .'
check "ningún archivo de repo de Cursor depende de una clave gestionada por apt-key" '! echo "${CURSOR_SOURCE_FILES}" | xargs -r grep -qi "apt-key"'

echo ""
echo "== 5. status después de instalar =="
OUTPUT="$("${INSTALL_CURSOR_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'
check "el paquete 'cursor' quedó instalado" 'dpkg -s cursor &>/dev/null'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_CURSOR_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 7. uninstall limpia el paquete, el repo y la clave =="
"${INSTALL_CURSOR_SH}" uninstall
check "el paquete 'cursor' ya no está instalado" '! dpkg -s cursor &>/dev/null'
check "el archivo de repo se eliminó" '[[ ! -f /etc/apt/sources.list.d/cursor.list ]]'
check "el keyring se eliminó" '[[ ! -f /etc/apt/keyrings/cursor.gpg ]]'
check "no queda ningún archivo de repo apuntando a Cursor" '! grep -rl "downloads.cursor.com/aptrepo" /etc/apt/sources.list.d/ 2>/dev/null | grep -q .'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: Cursor se instala vía su repo APT oficial (signed-by, amd64+arm64)."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
