#!/usr/bin/env bash
# tests/test_ghostty_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_ghostty.sh, que
# decide su mecanismo de instalación según la versión de Ubuntu (ver
# docs/adr/0032-mecanismo-condicional-por-version-de-ubuntu.md): confirma
# que en 24.04 agrega el PPA (ppa:mkasberg/ghostty-ubuntu) antes de
# instalar, y que en cualquier otra versión (26.04+) instala directo del
# repositorio oficial, sin tocar ningún PPA. No instala nada real:
# dpkg/apt-get/apt/sudo/lsb_release/add-apt-repository se interceptan con
# comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_ghostty_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_ghostty.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="ghostty"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <ubuntu_version> <dpkg_state: ii|rc|missing> [<binary: auto|yes|no>] [<has_add_apt_repository: yes|no>]
setup_mock_bin() {
    local ubuntu_version="$1" dpkg_state="$2" binary="${3:-auto}" has_aar="${4:-yes}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/lsb_release" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-rs" ]]; then
    echo "${ubuntu_version}"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/lsb_release"

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
# Simula que instalar software-properties-common de verdad deja
# 'add-apt-repository' disponible en PATH (igual que en un sistema real),
# aunque el mock haya arrancado sin él (escenario 3).
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
        cat > "${UCI_MOCK_BIN}/ghostty" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/ghostty"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <ubuntu_version> <accion> <dpkg_state> [<binary>] [<has_add_apt_repository>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local ubuntu_version="$1" action="$2" dpkg_state="$3" binary="${4:-auto}" has_aar="${5:-yes}"
    setup_mock_bin "${ubuntu_version}" "${dpkg_state}" "${binary}" "${has_aar}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. Ubuntu 24.04: 'install' agrega el PPA antes de instalar =="
run_installer "24.04" "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "add-apt-repository -y ppa:mkasberg/ghostty-ubuntu" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "24.04: 'install' agrega el PPA de mkasberg y luego instala el paquete"
else
    fail "24.04: 'install' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 2. Ubuntu 26.04: 'install' NO toca ningún PPA, instala directo =="
run_installer "26.04" "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]] && ! grep -q "add-apt-repository" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "26.04: 'install' no agrega ningún PPA, instala directo del repositorio oficial"
else
    fail "26.04: 'install' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. Ubuntu 24.04: si 'add-apt-repository' no existe, instala software-properties-common primero =="
run_installer "24.04" "install" "missing" "auto" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install -y software-properties-common" "${UCI_MOCK_LOG}"; then
    pass "24.04: 'install' instala software-properties-common si 'add-apt-repository' no existe"
else
    fail "24.04: no instaló software-properties-common cuando debía. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 4. Ubuntu 24.04: 'uninstall' quita el paquete y el PPA =="
run_installer "24.04" "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && grep -q "add-apt-repository -y --remove ppa:mkasberg/ghostty-ubuntu" "${UCI_MOCK_LOG}"; then
    pass "24.04: 'uninstall' purga el paquete y quita el PPA"
else
    fail "24.04: 'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 5. Ubuntu 26.04: 'uninstall' NO intenta quitar ningún PPA =="
run_installer "26.04" "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && ! grep -q "add-apt-repository" "${UCI_MOCK_LOG}"; then
    pass "26.04: 'uninstall' purga el paquete sin tocar ningún PPA"
else
    fail "26.04: 'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 6. status/update/repair no dependen de la versión (mismo comportamiento en 24.04 y 26.04) =="
for version in "24.04" "26.04"; do
    run_installer "${version}" "status" "ii"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* ]]; then
        pass "${version}: 'status' reporta INSTALLED"
    else
        fail "${version}: 'status' no reportó INSTALLED. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${version}" "status" "ii" "no"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "${version}: dpkg 'ii' sin binario resoluble reporta BROKEN"
    else
        fail "${version}: no reportó BROKEN. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin
done

echo ""
echo "== 7. comando desconocido y estado residual 'rc' =="
run_installer "26.04" "esto-no-existe" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "comando desconocido sale con código distinto de cero"
else
    fail "comando desconocido debería fallar"
fi
teardown_mock_bin

run_installer "26.04" "status" "rc"
if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado residual 'rc' se reporta como NOT_INSTALLED"
else
    fail "estado residual 'rc' no se manejó correctamente. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
