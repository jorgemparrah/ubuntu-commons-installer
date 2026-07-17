#!/usr/bin/env bash
# tests/docker/test_runtime_status.sh
#
# Prueba de punta a punta del Gestor de runtimes (Hito 8, ver
# docs/ROADMAP.md y scripts/lib/runtime.sh). Instala Mise y dos runtimes
# distintos (Node y Python) para confirmar que la abstracción realmente es
# genérica, no algo hecho a medida solo para Node. SOLO debe correr dentro
# de un contenedor Docker desechable.
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_runtime_status.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala Mise/Python/Node de verdad. Solo debe correr" >&2
    echo "dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

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

echo "== 1. runtime status sin Mise instalado =="
OUTPUT="$("${SETUP_SH}" runtime status 2>&1)"
CODE=$?
check "'runtime status' sale con código 0 aunque Mise no esté instalado" '[[ ${CODE} -eq 0 ]]'
check "avisa que Mise no está instalado" '[[ "${OUTPUT}" == *"Mise no está instalado"* ]]'

echo ""
echo "== 2. Instalando Mise + Node (vía la migración NVM->Mise no aplica aquí; se instala Node directo) =="
export PATH="${HOME}/.local/bin:${PATH}"
curl -fsSL https://mise.run | sh >/dev/null
"${HOME}/.local/bin/mise" use -g node@lts >/dev/null 2>&1

echo ""
echo "== 3. runtime status con Node gestionado =="
OUTPUT="$("${SETUP_SH}" runtime status 2>&1)"
CODE=$?
check "'runtime status' sale con código 0" '[[ ${CODE} -eq 0 ]]'
check "Node.js aparece como gestionado por Mise" '[[ "${OUTPUT}" == *"Node.js"*"gestionado por Mise"* ]]'
check "Python todavía aparece como no gestionado" '[[ "${OUTPUT}" == *"Python"*"no gestionado por Mise"* ]]'

echo ""
echo "== 4. Instalando Python vía Mise (para probar que el gestor es genérico, no solo para Node) =="
"${HOME}/.local/bin/mise" use -g python@latest >/dev/null 2>&1

echo ""
echo "== 5. runtime status con Node Y Python gestionados =="
OUTPUT="$("${SETUP_SH}" runtime status 2>&1)"
CODE=$?
check "'runtime status' sale con código 0" '[[ ${CODE} -eq 0 ]]'
check "Node.js sigue apareciendo como gestionado" '[[ "${OUTPUT}" == *"Node.js"*"gestionado por Mise"* ]]'
check "Python ahora aparece como gestionado por Mise" '[[ "${OUTPUT}" == *"Python"*"gestionado por Mise"* ]]'
check "Java sigue apareciendo como no gestionado (no se instaló)" '[[ "${OUTPUT}" == *"Java"*"no gestionado por Mise"* ]]'

echo ""
echo "== 6. runtime status no modifica nada (es de solo lectura) =="
BEFORE="$(find "${HOME}/.config/mise" "${HOME}/.local/share/mise" -type f 2>/dev/null | sort | xargs -I{} sha256sum {} 2>/dev/null | sort)"
"${SETUP_SH}" runtime status >/dev/null 2>&1
AFTER="$(find "${HOME}/.config/mise" "${HOME}/.local/share/mise" -type f 2>/dev/null | sort | xargs -I{} sha256sum {} 2>/dev/null | sort)"
check "el estado de Mise no cambia al correr 'runtime status'" '[[ "${BEFORE}" == "${AFTER}" ]]'

echo ""
echo "== 7. subcomando inválido =="
set +e
"${SETUP_SH}" runtime esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "'runtime esto-no-existe' sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: el gestor de runtimes funciona para al menos dos runtimes distintos (Node y Python)."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
