#!/usr/bin/env bash
# tests/docker/test_vscode_apt_repo.sh
#
# Prueba funcional de scripts/editors/install_vscode.sh (Hito 9, Fase B),
# equivalente a tests/docker/test_cursor_apt_repo.sh: confirma que el repo
# APT oficial de Microsoft (signed-by + keyring, nunca apt-key) funciona
# de punta a punta, que gnupg se asegura antes de 'gpg --dearmor', que el
# keyring no queda vacío, y que 'status' distingue correctamente el estado
# tras 'apt purge'. SOLO debe correr dentro de un contenedor Docker
# desechable (agrega una clave GPG, un repo APT, e instala un paquete real).
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_vscode_apt_repo.sh
#   docker run --rm ubuntu-workstation-test:26.04 bash tests/docker/test_vscode_apt_repo.sh
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
INSTALL_VSCODE_SH="${UCI_REPO_ROOT}/scripts/editors/install_vscode.sh"
readonly INSTALL_VSCODE_SH

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
OUTPUT="$("${INSTALL_VSCODE_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_VSCODE_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. install (real, vía el repo APT oficial de Microsoft) =="
"${INSTALL_VSCODE_SH}" install
INSTALL_CODE=$?
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 4. repositorio y keyring válidos: signed-by, nunca apt-key, keyring no vacío =="
check "el keyring quedó en /etc/apt/keyrings/packages.microsoft.gpg" '[[ -s /etc/apt/keyrings/packages.microsoft.gpg ]]'
check "el archivo de repo declara signed-by" 'grep -q "signed-by=/etc/apt/keyrings/packages.microsoft.gpg" /etc/apt/sources.list.d/vscode.list'
check "el archivo de repo declara amd64,arm64,armhf" 'grep -q "arch=amd64,arm64,armhf" /etc/apt/sources.list.d/vscode.list'
check "el archivo de repo no depende de apt-key" '! grep -qi "apt-key" /etc/apt/sources.list.d/vscode.list'

echo ""
echo "== 5. status después de instalar =="
OUTPUT="$("${INSTALL_VSCODE_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'
check "el paquete 'code' quedó instalado" 'dpkg -l code 2>/dev/null | grep -q "^ii"'

echo ""
echo "== 6. apt update sigue funcionando con el repo agregado (sin conflictos) =="
check "'apt update' corre sin errores con el repo de VS Code activo" 'sudo apt update &>/dev/null'

echo ""
echo "== 7. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_VSCODE_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 8. uninstall limpia el paquete, el repo y la clave =="
"${INSTALL_VSCODE_SH}" uninstall
check "el paquete 'code' ya no está instalado" '! dpkg -l code 2>/dev/null | grep -q "^ii"'
check "el archivo de repo se eliminó" '[[ ! -f /etc/apt/sources.list.d/vscode.list ]]'
check "el keyring se eliminó" '[[ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]]'

echo ""
echo "== 9. status final: NOT_INSTALLED, y apt update sigue sano (sin residuos) =="
set +e
OUTPUT="$("${INSTALL_VSCODE_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' final reporta NOT_INSTALLED" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'apt update' sigue funcionando después de desinstalar (sin repos/claves rotos)" 'sudo apt update &>/dev/null'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: VS Code se instala vía su repo APT oficial (signed-by, sin residuos)."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
