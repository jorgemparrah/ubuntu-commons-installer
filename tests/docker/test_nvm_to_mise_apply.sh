#!/usr/bin/env bash
# tests/docker/test_nvm_to_mise_apply.sh
#
# Prueba de punta a punta de la migración NVM -> Mise (Hito 7) instalando
# NVM y Node de verdad. SOLO debe correr dentro de un contenedor Docker
# desechable (ver tests/docker/Dockerfile y docs/TESTING.md) — nunca en una
# máquina de desarrollo real, ni siquiera con UCI_HOME_DIR/HOME
# redirigidas: instala software real (NVM, Node, Mise) vía internet.
#
# Uso (desde el host):
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test:24.04 -f tests/docker/Dockerfile .
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_nvm_to_mise_apply.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala NVM/Node/Mise de verdad. Solo debe correr dentro" >&2
    echo "de un contenedor Docker desechable (ver docs/TESTING.md). Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

NVM_INSTALL_VERSION="v0.40.1"
readonly NVM_INSTALL_VERSION

echo "== 1. Instalando NVM real (dentro del contenedor) =="
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_INSTALL_VERSION}/install.sh" | bash
export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh"

echo ""
echo "== 2. Instalando una versión de Node vía NVM =="
nvm install --lts
NVM_NODE_VERSION="$(nvm current)"
echo "Node instalado vía NVM: ${NVM_NODE_VERSION}"

echo ""
echo "== 3. Estado ANTES de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

echo ""
echo "== 4. migrate --list (antes) =="
"${SETUP_SH}" migrate --list

echo ""
echo "== 5. migrate --dry-run =="
"${SETUP_SH}" migrate --dry-run

echo ""
echo "== 6. migrate (apply real) =="
"${SETUP_SH}" migrate

echo ""
echo "== 7. Estado DESPUÉS de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

echo ""
echo "== 8. migrate --list (después) =="
"${SETUP_SH}" migrate --list

echo ""
echo "== 9. Verificaciones =="
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

check "~/.nvm ya no existe (se movió al backup)" '[[ ! -d "${HOME}/.nvm" ]]'
check "Mise quedó instalado" '[[ -x "${HOME}/.local/bin/mise" ]]'
check "hay una sesión de backup registrada" 'find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .'
check "el .nvm original quedó dentro del backup" 'find "${HOME}/.local/state/ubuntu-workstation/backups" -maxdepth 3 -type d -name ".nvm" 2>/dev/null | grep -q .'
check "hay una marca de finalización para 001_nvm_to_mise" '[[ -f "${HOME}/.local/state/ubuntu-workstation/migrations/001_nvm_to_mise.done" ]]'

MISE_NODE_VERSION="$(HOME="${HOME}" "${HOME}/.local/bin/mise" which node 2>/dev/null || true)"
check "Mise resuelve un ejecutable de node" '[[ -n "${MISE_NODE_VERSION}" && -x "${MISE_NODE_VERSION}" ]]'

echo ""
echo "== 10. Correr 'migrate' de nuevo: no debería reaplicarse =="
"${SETUP_SH}" migrate
if [[ -d "${HOME}/.local/state/ubuntu-workstation/backups" ]]; then
    session_count_after="$(find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    check "no se creó una segunda sesión de backup al reaplicar" '[[ "${session_count_after}" -eq 1 ]]'
fi

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: la migración NVM -> Mise funcionó de punta a punta dentro del contenedor."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
