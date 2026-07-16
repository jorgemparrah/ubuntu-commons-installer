#!/usr/bin/env bash
# tests/docker/test_bootstrap_mise_no_nvm.sh
#
# Confirma que el flujo interactivo (`./setup.sh` sin argumentos) en una
# workstation limpia instala Node.js vía Mise y NUNCA instala NVM. Fase de
# estabilización de los Hitos 2-7 (ver docs/ROADMAP.md, punto 3 del pedido
# de auditoría). SOLO debe correr dentro de un contenedor Docker desechable.
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_bootstrap_mise_no_nvm.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/Node de verdad. Solo debe correr dentro" >&2
    echo "de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

cd "${UCI_REPO_ROOT}"

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

# La imagen base trae Node.js vía apt (para poder correr otras pruebas,
# como tests/test_status_mapping.js). Para simular de verdad una
# workstation limpia sin Node, se inhabilitan esos binarios dentro de este
# contenedor desechable — no afecta nada fuera de él.
if command -v node >/dev/null 2>&1; then
    sudo mv "$(command -v node)" "$(command -v node).disabled_por_test" 2>/dev/null || true
fi
if command -v npm >/dev/null 2>&1; then
    sudo mv "$(command -v npm)" "$(command -v npm).disabled_por_test" 2>/dev/null || true
fi

echo "== Estado antes: sin Node, sin NVM, sin Mise =="
check "no hay Node.js en PATH" '! command -v node >/dev/null 2>&1'
check "no existe ~/.nvm" '[[ ! -d "${HOME}/.nvm" ]]'
check "no existe ~/.local/bin/mise" '[[ ! -x "${HOME}/.local/bin/mise" ]]'

echo ""
echo "== Corriendo ./setup.sh (sin argumentos) con respuestas simuladas =="
# Se responden hasta 6 prompts con "y" (instalar dependencias básicas si
# faltan, instalar Mise, "presiona ENTER" en cualquiera de los pasos
# intermedios) en vez de un guion fijo: el orden/cantidad exacto de
# prompts depende de qué falte en la imagen (por ejemplo, si falta snapd,
# aparece una confirmación extra antes de llegar a la de Mise). Se cierra
# stdin después de esas 6 líneas a propósito: si el flujo llega a lanzar
# el menú interactivo de Node (inquirer), debe recibir EOF y fallar rápido
# en vez de recibir "y" sueltas que podrían disparar instaladores reales
# sin querer.
LOG_FILE="$(mktemp)"
printf 'y\ny\ny\ny\ny\ny\n' | TERM=xterm timeout 180 bash setup.sh > "${LOG_FILE}" 2>&1 || true

echo "--- salida (últimas 20 líneas) ---"
tail -20 "${LOG_FILE}"
echo "--- fin salida ---"

echo ""
echo "== Verificaciones =="
check "el log NO menciona instalar NVM" '! grep -qi "nvm-sh\|NVM_DIR\|Instalando NVM" "${LOG_FILE}"'
check "el log menciona instalar Mise" 'grep -qi "Instalando Mise" "${LOG_FILE}"'
check "el log confirma Node.js/npm disponibles vía Mise" 'grep -q "disponibles vía Mise" "${LOG_FILE}"'
check "~/.nvm NO existe después de correr el bootstrap" '[[ ! -d "${HOME}/.nvm" ]]'
check "~/.local/bin/mise SÍ existe después de correr el bootstrap" '[[ -x "${HOME}/.local/bin/mise" ]]'

MISE_NODE="$("${HOME}/.local/bin/mise" which node 2>/dev/null || true)"
check "Mise resuelve un ejecutable de node" '[[ -n "${MISE_NODE}" && -x "${MISE_NODE}" ]]'

check "el bloque gestionado de Mise quedó en .bashrc" 'grep -qF "ubuntu-workstation: mise" "${HOME}/.bashrc" 2>/dev/null'

rm -f "${LOG_FILE}"

echo ""
echo "== install_nodejs.sh (legado) rechaza ejecutarse sin confirmación explícita =="
set +e
./scripts/development/install_nodejs.sh install >/tmp/legacy_output.log 2>&1
LEGACY_CODE=$?
set -e
check "'install_nodejs.sh install' sin UCI_ALLOW_LEGACY_NVM sale con código distinto de cero" '[[ ${LEGACY_CODE} -ne 0 ]]'
check "avisa que está deprecado" 'grep -qi "deprecado" /tmp/legacy_output.log'
check "NVM sigue sin instalarse tras el intento rechazado" '[[ ! -d "${HOME}/.nvm" ]]'
rm -f /tmp/legacy_output.log

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: el bootstrap interactivo usa Mise y nunca instala NVM."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
