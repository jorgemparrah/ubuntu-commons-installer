#!/usr/bin/env bash
# tests/docker/test_nvm_to_mise_prebaked.sh
#
# Igual que test_nvm_to_mise_apply.sh, pero asume que NVM y sus versiones de
# Node YA están instaladas en la imagen (ver Dockerfile.nvm-single y
# Dockerfile.nvm-multi) — no instala NVM en tiempo de ejecución. Sirve para
# probar la migración partiendo de un estado "ya migrado a medias"/reutilizado
# realista, y en particular que la versión global de Mise queda tomada del
# alias 'default' de NVM (ver docs/adr/0024-alcance-migracion-nvm-a-mise.md),
# no simplemente la versión más alta detectada.
#
# SOLO debe correr dentro de un contenedor Docker desechable.
#
# Uso (desde el host):
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test:24.04 -f tests/docker/Dockerfile .
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test-nvm-multi:24.04 -f tests/docker/Dockerfile.nvm-multi .
#   docker run --rm ubuntu-workstation-test-nvm-multi:24.04 bash tests/docker/test_nvm_to_mise_prebaked.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script asume NVM/Node ya instalados de verdad en la imagen." >&2
    echo "Solo debe correr dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

if [[ ! -d "${HOME}/.nvm" ]]; then
    echo "No se encontró ${HOME}/.nvm — esta imagen no parece tener NVM preinstalado." >&2
    exit 1
fi

export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh"

echo "== 0. Estado preinstalado en la imagen =="
echo "Versiones de Node vía NVM: $(nvm ls --no-colors 2>/dev/null | tr -s ' \n' ' ')"
DEFAULT_ALIAS_TARGET="$(cat "${NVM_DIR}/alias/default" 2>/dev/null || true)"
echo "Alias 'default' de NVM: ${DEFAULT_ALIAS_TARGET:-<sin resolver>}"

# Versión real (con 'v') a la que resuelve el alias 'default', para comparar
# después de migrar.
EXPECTED_DEFAULT_VERSION="$(nvm version default 2>/dev/null || true)"
echo "El alias 'default' resuelve a: ${EXPECTED_DEFAULT_VERSION}"

echo ""
echo "== 1. Estado ANTES de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

echo ""
echo "== 2. migrate --list / --dry-run =="
"${SETUP_SH}" migrate --list
"${SETUP_SH}" migrate --dry-run

echo ""
echo "== 3. migrate (apply real) =="
"${SETUP_SH}" migrate

echo ""
echo "== 4. Estado DESPUÉS de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

echo ""
echo "== 5. Verificaciones =="
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
check "hay una marca de finalización para 001_nvm_to_mise" '[[ -f "${HOME}/.local/state/ubuntu-workstation/migrations/001_nvm_to_mise.done" ]]'

MISE_CONFIG="${HOME}/.config/mise/config.toml"
if [[ -f "${MISE_CONFIG}" ]]; then
    EXPECTED_PLAIN_VERSION="${EXPECTED_DEFAULT_VERSION#v}"
    check "la versión global de Mise coincide con el alias 'default' de NVM (${EXPECTED_PLAIN_VERSION})" \
        'grep -q "${EXPECTED_PLAIN_VERSION}" "${MISE_CONFIG}"'
else
    echo "FALLO - no existe ${MISE_CONFIG}"
    FAILED=1
fi

MISE_NODE_VERSION="$("${HOME}/.local/bin/mise" which node 2>/dev/null || true)"
check "Mise resuelve un ejecutable de node" '[[ -n "${MISE_NODE_VERSION}" && -x "${MISE_NODE_VERSION}" ]]'

echo ""
echo "== 6. Correr 'migrate' de nuevo: no debería reaplicarse =="
"${SETUP_SH}" migrate
session_count_after="$(find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
check "no se creó una segunda sesión de backup al reaplicar" '[[ "${session_count_after}" -eq 1 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: migración validada partiendo de un estado NVM preinstalado."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
