#!/usr/bin/env bash
# tests/test_list_info_commands.sh
#
# Prueba simulada de 'setup.sh list'/'setup.sh info' (metadata del
# catálogo). 'list' es puramente lectura de datos (no ejecuta ningún
# script), así que se prueba directamente contra el catálogo real. 'info'
# sí invoca 'status' de cada herramienta filtrada — se prueba solo con el
# perfil 'ai-cli' (las 4 únicas del mecanismo curl-script, mismo mock de
# 'curl' que tests/test_install_profile.sh) para no depender de los otros
# mecanismos del catálogo.
#
# Uso:
#   bash tests/test_list_info_commands.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

RUN_OUTPUT=""
RUN_CODE=0
run_setup() {
    set +e
    RUN_OUTPUT="$(bash "${SETUP_SH}" "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 'list' sin filtro =="
run_setup list
assert_ok() {
    local description="$1" condition="$2"
    if eval "${condition}"; then pass "${description}"; else fail "${description}. Salida: ${RUN_OUTPUT}"; fi
}
assert_ok "'list' sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
assert_ok "'list' muestra el encabezado de la tabla" '[[ "${RUN_OUTPUT}" == *"ID"*"NOMBRE"*"CATEGORÍA"*"PERFILES"* ]]'
assert_ok "'list' incluye una herramienta 'required' (wget)" '[[ "${RUN_OUTPUT}" == *"wget"* ]]'
assert_ok "'list' incluye una herramienta 'optional' (docker)" '[[ "${RUN_OUTPUT}" == *"docker"* ]]'
assert_ok "'list' no corre ningún 'status' real (sin columna ESTADO)" '[[ "${RUN_OUTPUT}" != *"ESTADO"* ]]'

echo ""
echo "== 'list --profile minimal' filtra correctamente =="
run_setup list --profile minimal
assert_ok "'list --profile minimal' sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
assert_ok "incluye wget (required, en minimal)" '[[ "${RUN_OUTPUT}" == *"wget"* ]]'
assert_ok "NO incluye docker (optional, fuera de minimal)" '[[ "${RUN_OUTPUT}" != *"docker"* ]]'

echo ""
echo "== 'list' con perfil desconocido no filtra nada (perfil vacío = sin match) =="
run_setup list --profile no-existe
assert_ok "'list --profile no-existe' sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
assert_ok "no incluye ninguna fila de herramienta (solo encabezado)" '[[ "${RUN_OUTPUT}" != *"wget"* && "${RUN_OUTPUT}" != *"docker"* ]]'

echo ""
echo "== 'info --profile ai-cli' agrega el estado real (mock de curl) =="
UCI_MOCK_BIN="$(mktemp -d)"
UCI_MOCK_HOME="$(mktemp -d)"
mkdir -p "${UCI_MOCK_HOME}/.local/bin"
cat > "${UCI_MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "${UCI_MOCK_BIN}/curl"

set +e
RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" UCI_HOME_DIR="${UCI_MOCK_HOME}" \
    PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" \
    bash "${SETUP_SH}" info --profile ai-cli 2>&1)"
RUN_CODE=$?
set -e
rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"

assert_ok "'info --profile ai-cli' sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
assert_ok "muestra la columna ESTADO" '[[ "${RUN_OUTPUT}" == *"ESTADO"* ]]'
assert_ok "reporta NOT_INSTALLED para claude_code (nada instalado en el \$HOME simulado)" '[[ "${RUN_OUTPUT}" == *"claude_code"*"NOT_INSTALLED"* ]]'

print_test_summary
exit_with_test_summary
