#!/usr/bin/env bash
# tests/test_zip_utils_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_zip_utils.sh (Hito
# 45, ver docs/ROADMAP.md). No instala nada real:
# apt-get/apt/dpkg/sudo se interceptan con comandos falsos en un PATH
# temporal. Instalador multi-paquete (unzip + zip), mismo criterio que
# install_virt_manager.sh: 'unzip' es el paquete de referencia para
# status/update, pero install/uninstall/reinstall/repair operan sobre
# ambos paquetes a la vez.
#
# Uso:
#   bash tests/test_zip_utils_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_zip_utils.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="unzip"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|missing> [<upgradable: yes|no>] [<binaries: auto|yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" binaries="${3:-auto}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "ii" ]]; then
        echo "ii  \$2  1.0  amd64  paquete de prueba"
        exit 0
    fi
    exit 1
fi
if [[ "\$1" == "--configure" ]]; then
    exit 0
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
    echo "${UCI_PKG_NAME}/noble 6.0-28 amd64 [upgradable from: 6.0-27]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    local create_binaries="no"
    if [[ "${binaries}" == "yes" ]]; then
        create_binaries="yes"
    elif [[ "${binaries}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binaries="yes"
    fi
    if [[ "${create_binaries}" == "yes" ]]; then
        for bin in unzip zip; do
            cat > "${UCI_MOCK_BIN}/${bin}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
            chmod +x "${UCI_MOCK_BIN}/${bin}"
        done
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <dpkg_state> [<upgradable>] [<binaries>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" binaries="${4:-auto}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${binaries}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. install: instala ambos paquetes (unzip y zip) =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install -y unzip zip" "${UCI_MOCK_LOG}"; then
    pass "'install' instala ambos paquetes ('unzip' y 'zip') en una sola invocación"
else
    fail "'install' no instaló los paquetes esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. status con dpkg 'ii' pero sin binarios resolubles: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si 'unzip'/'zip' no resuelven"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. uninstall: purga ambos paquetes =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y unzip zip" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga ambos paquetes (no 'remove')"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 8. update invoca '--only-upgrade' sobre ambos paquetes =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y unzip zip" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade' sobre ambos paquetes"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 9. repair corre 'dpkg --configure -a' y reinstala ambos paquetes =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y unzip zip" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala ambos paquetes"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 10. reinstall usa 'apt-get install --reinstall' directo (sin purgar) =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y unzip zip" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' invoca 'apt-get install --reinstall' sobre ambos paquetes"
else
    fail "'reinstall' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "purge" "${UCI_MOCK_LOG}"; then
    fail "'reinstall' no debería pasar por 'purge'"
else
    pass "'reinstall' evita el ciclo completo de purge+autoremove"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
