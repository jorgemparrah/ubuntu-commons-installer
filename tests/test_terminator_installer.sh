#!/usr/bin/env bash
# tests/test_terminator_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_terminator.sh (Hito 11,
# Fase 2). No instala nada real: apt-get/apt/dpkg/sudo se interceptan con
# comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_terminator_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_terminator.sh"
readonly INSTALL_SH
readonly UCI_BIN_NAME="terminator"
readonly UCI_PKG_NAME="terminator"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|rc|missing> [<upgradable: yes|no>] [<fail_apt_get: yes|no>] [<binary: auto|yes|no>]
#
# El mock de dpkg solo entiende 'dpkg -l <paquete>' (un paquete a la vez,
# igual que scripts/lib/apt.sh). El binario falso solo se crea si
# corresponde según <binary> ("auto" = solo si dpkg_state es "ii"),
# para poder simular tanto INSTALLED como BROKEN (dpkg dice 'ii' pero el
# binario no resuelve).
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" fail_apt_get="${3:-no}" binary="${4:-auto}"
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
if [[ "${fail_apt_get}" == "yes" ]]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" ]]; then
    echo "${UCI_PKG_NAME}/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/${UCI_BIN_NAME}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${UCI_BIN_NAME}"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <accion> <dpkg_state> [<upgradable>] [<fail_apt_get>] [<binary>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" fail_apt_get="${4:-no}" binary="${5:-auto}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${fail_apt_get}" "${binary}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. comando desconocido =="
run_installer "esto-no-existe" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "comando desconocido sale con código distinto de cero"
else
    fail "comando desconocido debería salir con código distinto de cero"
fi
if [[ "${RUN_OUTPUT}" == *"Uso:"* ]]; then
    pass "comando desconocido imprime un mensaje de uso"
else
    fail "comando desconocido no imprimió un mensaje de uso. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 3. instalación =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'install' invoca 'apt-get install -y ${UCI_PKG_NAME}'"
else
    fail "'install' no invocó la instalación esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 4. estado instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. segunda instalación idempotente =="
run_installer "install" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "una segunda corrida de 'install' sobre un paquete ya instalado no falla"
else
    fail "una segunda corrida de 'install' no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 6. actualización cuando existe candidato =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' con candidato disponible invoca '--only-upgrade' y sale con código 0"
else
    fail "'update' con candidato no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 7. actualización cuando ya está actualizado =="
run_installer "update" "ii" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' sin candidato pendiente sale con código 0 sin fallar"
else
    fail "'update' sin candidato no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 8. reparación de estado roto (BROKEN) =="
run_installer "repair" "ii" "no" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'repair' sobre un estado BROKEN sale con código 0"
else
    fail "'repair' sobre BROKEN debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 9. intento de reparación cuando no está instalado =="
run_installer "repair" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'repair' sobre NOT_INSTALLED sale con código distinto de cero"
else
    fail "'repair' sobre NOT_INSTALLED debería fallar"
fi
if [[ "${RUN_OUTPUT}" == *"install"* ]]; then
    pass "'repair' sobre NOT_INSTALLED sugiere usar 'install'"
else
    fail "'repair' no sugirió usar 'install'. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 10. reinstalación explícita =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'reinstall' sale con código 0"
else
    fail "'reinstall' debería salir con código 0 (fue ${RUN_CODE})"
fi
if grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' invoca 'apt-get install --reinstall'"
else
    fail "'reinstall' no invocó la reinstalación esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "purge" "${UCI_MOCK_LOG}"; then
    fail "'reinstall' no debería pasar por 'purge' (evita el ciclo completo de desinstalación)"
else
    pass "'reinstall' evita el ciclo completo de purge+autoremove"
fi
teardown_mock_bin

echo ""
echo "== 11. desinstalación =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE})"
fi
if grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' invoca 'apt-get purge -y ${UCI_PKG_NAME}' (purge, no remove)"
else
    fail "'uninstall' no invocó 'apt-get purge'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 12. segunda desinstalación idempotente =="
run_installer "uninstall" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "una segunda corrida de 'uninstall' sobre un paquete ya ausente no falla"
else
    fail "una segunda corrida de 'uninstall' no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 13. propagación de errores de APT =="
run_installer "install" "missing" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo real de apt-get se propaga como código de salida distinto de cero"
else
    fail "un fallo de apt-get debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 14. sin falsos positivos con estado residual 'rc' de dpkg =="
run_installer "status" "rc"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "el estado residual 'rc' se reporta como NOT_INSTALLED, nunca como INSTALLED sano"
else
    fail "el estado residual 'rc' no se manejó correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
