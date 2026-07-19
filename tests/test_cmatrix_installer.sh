#!/usr/bin/env bash
# tests/test_cmatrix_installer.sh
#
# Prueba simulada (mocks) del instalador piloto de la Fase 1 del Hito 11
# (scripts/system/install_cmatrix.sh, ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md): confirma
# el ciclo de vida completo de los 6 verbos sobre el dispatcher y los
# helpers APT compartidos. No instala nada real: apt-get/apt/dpkg/sudo se
# interceptan con comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_cmatrix_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_CMATRIX_SH="${UCI_REPO_ROOT}/scripts/system/install_cmatrix.sh"
readonly INSTALL_CMATRIX_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|rc|missing> [<upgradable: yes|no>]
# El mock de dpkg solo entiende 'dpkg -l cmatrix' (un paquete a la vez,
# igual que scripts/lib/apt.sh). El binario falso 'cmatrix' solo se crea
# en el PATH si el estado es 'ii', para que 'command -v cmatrix' sea
# consistente con el estado dpkg simulado.
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    case "${dpkg_state}" in
        ii) echo "ii  \$2  1.0  amd64  paquete de prueba"; exit 0 ;;
        rc) echo "rc  \$2  1.0  amd64  paquete de prueba"; exit 0 ;;
        *) echo "dpkg-query: no packages found matching \$2" >&2; exit 1 ;;
    esac
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"

    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" ]]; then
    echo "cmatrix/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    if [[ "${dpkg_state}" == "ii" ]]; then
        cat > "${UCI_MOCK_BIN}/cmatrix" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/cmatrix"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <accion> <dpkg_state> [<upgradable>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}"
    setup_mock_bin "${dpkg_state}" "${upgradable}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_CMATRIX_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "estado inicial: 'status' sale con código distinto de cero"
else
    fail "estado inicial: 'status' debería salir con código distinto de cero"
fi
if [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial: reporta NOT_INSTALLED"
else
    fail "estado inicial: no reportó NOT_INSTALLED. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. instalación simulada =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install -y cmatrix" "${UCI_MOCK_LOG}"; then
    pass "'install' invoca 'apt-get install -y cmatrix'"
else
    fail "'install' no invocó 'apt-get install -y cmatrix'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. segunda instalación idempotente =="
run_installer "install" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "una segunda corrida de 'install' sobre un paquete ya instalado no falla (idempotencia)"
else
    fail "una segunda corrida de 'install' no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 4. estado instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0 cuando el paquete está instalado y el binario resuelve"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4b. estado OUTDATED cuando hay una actualización disponible en el cache local de apt =="
run_installer "status" "ii" "yes"
if [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED cuando 'apt list --upgradable' muestra una versión más nueva"
else
    fail "'status' debería reportar OUTDATED. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. actualización =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'update' sale con código 0"
else
    fail "'update' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install --only-upgrade -y cmatrix" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca 'apt-get install --only-upgrade -y cmatrix'"
else
    fail "'update' no invocó la actualización esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 6. reparación =="
run_installer "repair" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'repair' sale con código 0"
else
    fail "'repair' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y cmatrix" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 7. desinstalación =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get purge -y cmatrix" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' invoca 'apt-get purge -y cmatrix' (purge, no remove)"
else
    fail "'uninstall' no invocó 'apt-get purge -y cmatrix'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 8. estado final: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado final: 'status' vuelve a reportar NOT_INSTALLED"
else
    fail "estado final: no reportó NOT_INSTALLED. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 9. comando inválido =="
run_installer "esto-no-existe" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "comando inválido sale con código distinto de cero"
else
    fail "comando inválido debería salir con código distinto de cero"
fi
if [[ "${RUN_OUTPUT}" == *"Uso:"* ]]; then
    pass "comando inválido imprime un mensaje de uso"
else
    fail "comando inválido no imprimió un mensaje de uso. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
