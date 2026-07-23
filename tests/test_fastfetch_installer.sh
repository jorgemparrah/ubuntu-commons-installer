#!/usr/bin/env bash
# tests/test_fastfetch_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_fastfetch.sh (Hito
# 47, ver docs/ROADMAP.md). Mismo patrón que
# tests/test_ulauncher_installer.sh, con un mock de
# 'add-apt-repository' (fastfetch no está en los repositorios oficiales
# de Ubuntu 24.04/26.04). A diferencia de ULauncher, `install` no agrega
# 'universe' (solo el PPA propio).
#
# Uso:
#   bash tests/test_fastfetch_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_fastfetch.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="fastfetch"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|missing> [<upgradable: yes|no>] [<binary: auto|yes|no>] [<has_add_apt_repository: yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" binary="${3:-auto}" has_aar="${4:-yes}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "ii" ]]; then
        echo "ii  ${UCI_PKG_NAME}  1.0  amd64  paquete de prueba"
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
if [[ "\$*" == *"software-properties-common"* ]]; then
    {
        printf '%s\n' '#!/usr/bin/env bash'
        printf 'echo "add-apt-repository \$*" >> "%s"\n' "${UCI_MOCK_LOG}"
        printf '%s\n' 'exit 0'
    } > "${UCI_MOCK_BIN}/add-apt-repository"
    chmod +x "${UCI_MOCK_BIN}/add-apt-repository"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" ]]; then
    echo "${UCI_PKG_NAME}/noble 2.20.0 amd64 [upgradable from: 2.19.0]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    if [[ "${has_aar}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/add-apt-repository" <<EOF
#!/usr/bin/env bash
echo "add-apt-repository \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/add-apt-repository"
    fi

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/fastfetch" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/fastfetch"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <accion> <dpkg_state> [<upgradable>] [<binary>] [<has_add_apt_repository>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" binary="${4:-auto}" has_aar="${5:-yes}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${binary}" "${has_aar}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. install agrega el PPA propio e instala el paquete =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "add-apt-repository -y ppa:zhangsongcui3371/fastfetch" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'install' agrega el PPA e instala el paquete"
else
    fail "'install' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. install instala software-properties-common si 'add-apt-repository' no existe =="
run_installer "install" "missing" "no" "auto" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install -y software-properties-common" "${UCI_MOCK_LOG}"; then
    pass "'install' instala software-properties-common si 'add-apt-repository' no existe"
else
    fail "'install' no instaló software-properties-common cuando debía. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 4. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED"
else
    fail "'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. dpkg 'ii' sin binario resoluble reporta BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN cuando el binario no resuelve"
else
    fail "'status' no reportó BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED"
else
    fail "'status' no reportó OUTDATED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. install sobre BROKEN se rechaza =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' sobre BROKEN rechaza y sugiere 'repair'"
else
    fail "'install' sobre BROKEN no se comportó como se esperaba. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. uninstall purga el paquete y quita el PPA =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && grep -q "add-apt-repository -y --remove ppa:zhangsongcui3371/fastfetch" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga el paquete (no remove) y quita el PPA"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 9. update invoca '--only-upgrade' =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 10. repair corre 'dpkg --configure -a' y reinstala =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 11. reinstall no vuelve a tocar el PPA =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && ! grep -q "add-apt-repository" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' usa --reinstall directo, sin volver a agregar el PPA"
else
    fail "'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
