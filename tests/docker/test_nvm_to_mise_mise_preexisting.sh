#!/usr/bin/env bash
# tests/docker/test_nvm_to_mise_mise_preexisting.sh
#
# Caso M06 de docs/TEST_CASES.md: Mise ya está instalado ANTES de correr la
# migración NVM -> Mise (ver tests/docker/Dockerfile.nvm-mise-preexisting).
# Confirma que la migración detecta Mise existente y no lo reinstala, pero
# igual instala vía Mise las versiones de Node detectadas, resuelve el alias
# global, mueve .nvm al backup, limpia las referencias de shell, y que una
# segunda ejecución no vuelve a migrar ni crea otro backup.
#
# SOLO debe correr dentro de un contenedor Docker desechable.
#
# Uso (desde el host):
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test:24.04 -f tests/docker/Dockerfile .
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test-nvm-mise-preexisting:24.04 -f tests/docker/Dockerfile.nvm-mise-preexisting .
#   docker run --rm ubuntu-workstation-test-nvm-mise-preexisting:24.04 bash tests/docker/test_nvm_to_mise_mise_preexisting.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script asume NVM/Node/Mise ya instalados de verdad en la imagen." >&2
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
if [[ ! -x "${HOME}/.local/bin/mise" ]]; then
    echo "No se encontró ${HOME}/.local/bin/mise — esta imagen no parece tener Mise preinstalado." >&2
    exit 1
fi

export NVM_DIR="${HOME}/.nvm"
# shellcheck source=/dev/null
source "${NVM_DIR}/nvm.sh"

echo "== 0. Estado preinstalado en la imagen =="
echo "Versiones de Node vía NVM: $(nvm ls --no-colors 2>/dev/null | tr -s ' \n' ' ')"
DEFAULT_ALIAS_TARGET="$(cat "${NVM_DIR}/alias/default" 2>/dev/null || true)"
echo "Alias 'default' de NVM: ${DEFAULT_ALIAS_TARGET:-<sin resolver>}"
EXPECTED_DEFAULT_VERSION="$(nvm version default 2>/dev/null || true)"
echo "El alias 'default' resuelve a: ${EXPECTED_DEFAULT_VERSION}"

MISE_VERSION_BEFORE="$("${HOME}/.local/bin/mise" --version)"
echo "Mise ya instalado antes de migrar: ${MISE_VERSION_BEFORE}"
if [[ -f "${HOME}/.mise-preexisting-version" ]]; then
    echo "Versión horneada en la imagen: $(cat "${HOME}/.mise-preexisting-version")"
fi

echo ""
echo "== 1. Estado ANTES de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

echo ""
echo "== 2. migrate --list / --dry-run =="
"${SETUP_SH}" migrate --list
DRY_RUN_LOG="$(mktemp)"
"${SETUP_SH}" migrate --dry-run | tee "${DRY_RUN_LOG}"

echo ""
echo "== 3. migrate (apply real) =="
"${SETUP_SH}" migrate

echo ""
echo "== 4. Estado DESPUÉS de migrar (doctor) =="
"${SETUP_SH}" doctor --verbose

MISE_VERSION_AFTER="$("${HOME}/.local/bin/mise" --version)"

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

check "el dry-run avisó que Mise ya está instalado y no se reinstalaría" \
    'grep -qi "Mise ya está instalado" "${DRY_RUN_LOG}"'
check "la versión de Mise no cambió inesperadamente al migrar" \
    '[[ "${MISE_VERSION_BEFORE}" == "${MISE_VERSION_AFTER}" ]]'
check "~/.nvm ya no existe (se movió al backup)" '[[ ! -d "${HOME}/.nvm" ]]'
check "hay una sesión de backup registrada" 'find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .'
check "hay una marca de finalización para 001_nvm_to_mise" '[[ -f "${HOME}/.local/state/ubuntu-workstation/migrations/001_nvm_to_mise.done" ]]'
check "ningún archivo de shell sigue cargando \$NVM_DIR/nvm.sh" '! grep -qF "NVM_DIR/nvm.sh" "${HOME}/.bashrc" 2>/dev/null'

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

rm -f "${DRY_RUN_LOG}"

echo ""
echo "== 6. Correr 'migrate' de nuevo: no debería reaplicarse ni reinstalar Mise =="
"${SETUP_SH}" migrate
session_count_after="$(find "${HOME}/.local/state/ubuntu-workstation/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
check "no se creó una segunda sesión de backup al reaplicar" '[[ "${session_count_after}" -eq 1 ]]'
MISE_VERSION_SECOND_RUN="$("${HOME}/.local/bin/mise" --version)"
check "la versión de Mise sigue sin cambiar tras la segunda corrida" '[[ "${MISE_VERSION_BEFORE}" == "${MISE_VERSION_SECOND_RUN}" ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: migración validada partiendo de un estado con Mise ya instalado."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
