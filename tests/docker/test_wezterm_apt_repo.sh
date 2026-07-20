#!/usr/bin/env bash
# tests/docker/test_wezterm_apt_repo.sh
#
# Prueba funcional de scripts/system/install_wezterm.sh: confirma que el
# repositorio APT propio de WezTerm en Fury.io (signed-by + keyring,
# nunca apt-key) funciona de punta a punta. A diferencia de
# Docker/VS Code/Cursor, este repo es "flat" (usa `* *` en vez del
# codename de Ubuntu como distribución) — la misma línea de repo debería
# funcionar igual en 24.04 y 26.04. SOLO debe correr dentro de un
# contenedor Docker desechable (agrega una clave GPG, un repo APT, e
# instala un paquete real).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_wezterm_apt_repo.sh
#   docker run --rm ubuntu-workstation-test:26.04 bash tests/docker/test_wezterm_apt_repo.sh
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
INSTALL_WEZTERM_SH="${UCI_REPO_ROOT}/scripts/system/install_wezterm.sh"
readonly INSTALL_WEZTERM_SH

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
OUTPUT="$("${INSTALL_WEZTERM_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_WEZTERM_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía el repo APT propio de WezTerm en Fury.io) =="
"${INSTALL_WEZTERM_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. repositorio y keyring válidos: signed-by, nunca apt-key, keyring no vacío =="
check "el keyring quedó en /usr/share/keyrings/wezterm-fury.gpg" '[[ -s /usr/share/keyrings/wezterm-fury.gpg ]]'
check "el archivo de repo declara signed-by" 'grep -q "signed-by=/usr/share/keyrings/wezterm-fury.gpg" /etc/apt/sources.list.d/wezterm.list'
check "el archivo de repo no depende de apt-key" '! grep -qi "apt-key" /etc/apt/sources.list.d/wezterm.list'

echo ""
echo "== 5. status después de instalar =="
OUTPUT="$("${INSTALL_WEZTERM_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'
check "el paquete 'wezterm' quedó instalado" 'dpkg -l wezterm 2>/dev/null | grep -q "^ii"'

echo ""
echo "== 6. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_WEZTERM_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 7. update/reinstall/repair (contrato completo de 6 verbos) =="
"${INSTALL_WEZTERM_SH}" update
UPDATE_CODE=$?
check "'update' sale con código 0" '[[ ${UPDATE_CODE} -eq 0 ]]'
"${INSTALL_WEZTERM_SH}" reinstall
REINSTALL_CODE=$?
check "'reinstall' sale con código 0" '[[ ${REINSTALL_CODE} -eq 0 ]]'
check "el paquete 'wezterm' sigue instalado después de 'reinstall'" 'dpkg -l wezterm 2>/dev/null | grep -q "^ii"'
"${INSTALL_WEZTERM_SH}" repair
REPAIR_CODE=$?
check "'repair' sale con código 0" '[[ ${REPAIR_CODE} -eq 0 ]]'
check "el binario 'wezterm' sigue resolviendo después de 'repair'" 'command -v wezterm &>/dev/null'

echo ""
echo "== 8. uninstall limpia el paquete, el repo y la clave =="
"${INSTALL_WEZTERM_SH}" uninstall
check "el paquete 'wezterm' ya no está instalado" '! dpkg -l wezterm 2>/dev/null | grep -q "^ii"'
check "el archivo de repo se eliminó" '[[ ! -f /etc/apt/sources.list.d/wezterm.list ]]'
check "el keyring se eliminó" '[[ ! -f /usr/share/keyrings/wezterm-fury.gpg ]]'

echo ""
echo "== 9. status final: NOT_INSTALLED =="
set +e
OUTPUT="$("${INSTALL_WEZTERM_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' final reporta NOT_INSTALLED" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: WezTerm se instala vía su repo APT propio (signed-by, sin residuos)."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
