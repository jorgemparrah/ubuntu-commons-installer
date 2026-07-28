#!/usr/bin/env bash
# tests/test_omniroute_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_omniroute.sh
# (Hito 56, ver docs/adr/0047-mecanismo-npm-mise-para-omniroute.md).
# **Único caso del mecanismo `npm-mise`**: paquete npm global instalado
# sobre un Node fijado por Mise, no el del sistema. Mismo escenario de
# mockeo que el caso `pip-mise` de tests/test_local_ai_ui_installers.sh.
#
# No instala nada real ni toca el HOME real: 'mise' se intercepta dentro
# de un $HOME temporal y el PATH apunta a un directorio temporal.
#
# El foco de las afirmaciones es que NUNCA se use el npm/Node del
# sistema: todas las invocaciones de npm deben pasar por
# 'mise exec node@24 -- npm', y un npm suelto en el PATH (que el mock
# registra aparte) no debe recibir ninguna llamada.
#
# Uso:
#   bash tests/test_omniroute_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="scripts/development/install_omniroute.sh"
readonly INSTALL_SH
readonly UCI_PKG="omniroute"
readonly UCI_NODE="24"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_SYSTEM_NPM_LOG=""
UCI_TEST_HOME=""

# setup_mocks <mise: presente|ausente> <npm_ls: ok|fail> [<npm_install: ok|fail>]
# El mock de 'mise' cubre las tres formas en que lo usa el instalador:
# 'exec node@24 -- npm ...', 'install node@24' y 'reshim'.
setup_mocks() {
    local mise="${1:-presente}" npm_ls="${2:-fail}" npm_install="${3:-ok}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_SYSTEM_NPM_LOG="$(mktemp)"
    UCI_TEST_HOME="$(mktemp -d)"

    # 'curl' falla siempre: 'runtime_ensure_mise' lo usa para bajar Mise
    # de https://mise.run, y esta prueba no debe tocar la red. Así el
    # escenario "Mise ausente" es determinista y offline.
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
exit 1
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    # npm del SISTEMA: si el instalador lo invocara, quedaría registrado
    # acá y las afirmaciones lo detectan. Nunca debería usarse.
    cat > "${UCI_MOCK_BIN}/npm" <<EOF
#!/usr/bin/env bash
echo "npm-del-sistema \$*" >> "${UCI_SYSTEM_NPM_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/npm"

    if [[ "${mise}" == "presente" ]]; then
        mkdir -p "${UCI_TEST_HOME}/.local/bin"
        cat > "${UCI_TEST_HOME}/.local/bin/mise" <<EOF
#!/usr/bin/env bash
echo "mise \$*" >> "${UCI_MOCK_LOG}"
# 'mise exec node@${UCI_NODE} -- npm ls -g --depth=0 omniroute'
for arg in "\$@"; do
    if [[ "\${arg}" == "ls" ]]; then
        [[ "${npm_ls}" == "ok" ]] && exit 0
        exit 1
    fi
    if [[ "\${arg}" == "install" && "${npm_install}" == "fail" ]]; then
        # Solo falla el 'npm install -g', no el 'mise install node@X'.
        for inner in "\$@"; do
            [[ "\${inner}" == "-g" ]] && exit 1
        done
    fi
done
exit 0
EOF
        chmod +x "${UCI_TEST_HOME}/.local/bin/mise"
    fi
}

teardown_mocks() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_TEST_HOME}"
    rm -f "${UCI_MOCK_LOG}" "${UCI_SYSTEM_NPM_LOG}"
}

RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" HOME="${UCI_TEST_HOME}" \
        bash "${UCI_REPO_ROOT}/${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# assert_system_npm_untouched <contexto>
assert_system_npm_untouched() {
    local context="$1"
    if [[ -s "${UCI_SYSTEM_NPM_LOG}" ]]; then
        fail "${context}: se usó el npm del sistema. Log: $(cat "${UCI_SYSTEM_NPM_LOG}")"
    else
        pass "${context}: no se usó el npm del sistema"
    fi
}

echo "== 1. Mise ausente: UNKNOWN, no NOT_INSTALLED =="
setup_mocks "ausente"
run_installer "status"
if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == "UNKNOWN" ]]; then
    pass "Mise ausente -> UNKNOWN (no se confunde 'no se puede saber' con 'no instalado')"
else
    fail "Mise ausente debería dar UNKNOWN. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
fi
teardown_mocks

echo ""
echo "== 2. status con Mise presente y paquete ausente: NOT_INSTALLED =="
setup_mocks "presente" "fail"
run_installer "status"
if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta NOT_INSTALLED"
else
    fail "'status' debería dar NOT_INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
fi
if grep -q "exec node@${UCI_NODE} -- npm ls -g" "${UCI_MOCK_LOG}"; then
    pass "'status' consulta npm a través del Node de Mise"
else
    fail "'status' no consultó npm vía Mise. Log: $(cat "${UCI_MOCK_LOG}")"
fi
assert_system_npm_untouched "status"
teardown_mocks

echo ""
echo "== 3. status con el paquete presente: INSTALLED =="
setup_mocks "presente" "ok"
run_installer "status"
if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED"
else
    fail "'status' debería dar INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
fi
teardown_mocks

echo ""
echo "== 4. install: fija Node 24 vía Mise e instala el paquete global =="
setup_mocks "presente" "fail"
run_installer "install"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "mise install node@${UCI_NODE}" "${UCI_MOCK_LOG}"; then
    pass "'install' fija Node ${UCI_NODE} vía Mise (el paquete exige >=22 <23 || >=24 <27)"
else
    fail "'install' no instaló Node ${UCI_NODE} vía Mise. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "exec node@${UCI_NODE} -- npm install -g ${UCI_PKG}" "${UCI_MOCK_LOG}"; then
    pass "'install' corre 'npm install -g' sobre el Node de Mise"
else
    fail "'install' no corrió npm sobre el Node de Mise. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "mise reshim" "${UCI_MOCK_LOG}"; then
    pass "'install' corre 'reshim' (si no, el ejecutable no queda en el PATH)"
else
    fail "'install' no corrió 'reshim'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"omniroute"* && "${RUN_OUTPUT}" == *"20128"* ]]; then
    pass "'install' informa cómo arrancar el servicio y en qué puerto (no lo gestiona)"
else
    fail "'install' debería informar cómo arrancar el servicio. Salida: ${RUN_OUTPUT}"
fi
assert_system_npm_untouched "install"
teardown_mocks

echo ""
echo "== 5. install: un fallo real de npm se propaga =="
setup_mocks "presente" "fail" "fail"
run_installer "install"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de 'npm install -g' se propaga como código distinto de cero"
else
    fail "un fallo de npm debería propagarse como código distinto de cero. Salida: ${RUN_OUTPUT}"
fi
teardown_mocks

echo ""
echo "== 6. install sin Mise instalable: falla con mensaje claro =="
# Mise ausente y 'curl' mockeado para fallar: runtime_ensure_mise no
# puede instalarlo y no se toca la red.
setup_mocks "ausente"
run_installer "install"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'install' falla si no se puede disponer de Mise"
else
    fail "'install' debería fallar si no hay Mise (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" == *"Mise"* ]]; then
    pass "'install' explica que el problema fue Mise, no algo genérico"
else
    fail "'install' debería mencionar Mise en el error. Salida: ${RUN_OUTPUT}"
fi
assert_system_npm_untouched "install sin Mise"
teardown_mocks

echo ""
echo "== 7. uninstall: quita el paquete global y conserva los datos =="
setup_mocks "presente" "ok"
run_installer "uninstall"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "exec node@${UCI_NODE} -- npm uninstall -g ${UCI_PKG}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' corre 'npm uninstall -g' sobre el Node de Mise"
else
    fail "'uninstall' no corrió npm uninstall vía Mise. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"conservaron"* ]]; then
    pass "'uninstall' informa que conserva la configuración y los datos locales"
else
    fail "'uninstall' debería informar que conserva los datos. Salida: ${RUN_OUTPUT}"
fi
assert_system_npm_untouched "uninstall"
teardown_mocks

echo ""
echo "== 8. uninstall con Mise ausente: no falla (nada que quitar) =="
setup_mocks "ausente"
run_installer "uninstall"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' es tolerante si Mise no está disponible"
else
    fail "'uninstall' no debería fallar si Mise no está (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mocks

echo ""
echo "== 9. update: reinstala la última versión publicada =="
setup_mocks "presente" "ok"
run_installer "update"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "exec node@${UCI_NODE} -- npm install -g ${UCI_PKG}" "${UCI_MOCK_LOG}"; then
    pass "'update' corre 'npm install -g' (que ya trae la última versión)"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "mise reshim" "${UCI_MOCK_LOG}"; then
    pass "'update' corre 'reshim'"
else
    fail "'update' no corrió 'reshim'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mocks

echo ""
echo "== 10. update con Mise ausente: rechaza y pide 'install' =="
setup_mocks "ausente"
run_installer "update"
if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"install"* ]]; then
    pass "'update' rechaza y sugiere 'install' si Mise no está disponible"
else
    fail "'update' debería rechazar y sugerir 'install' (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mocks

print_test_summary
exit_with_test_summary
