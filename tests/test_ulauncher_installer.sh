#!/usr/bin/env bash
# tests/test_ulauncher_installer.sh
#
# Prueba simulada (mocks) de scripts/productivity/install_ulauncher.sh
# (Hito 11, siguiente grupo apt-simple tras la Fase 2). Mismo patrón que
# tests/test_ranger_installer.sh, con un mock adicional de
# 'add-apt-repository' (ULauncher no está en los repositorios oficiales,
# ver ADR 0027). La prueba FUNCIONAL real (agrega el PPA de verdad e
# instala el paquete) sigue viviendo en tests/docker/test_ulauncher_ppa.sh
# (caso L01) — esta prueba no la reemplaza, solo cubre el contrato de 6
# verbos con mocks, sin tocar la red ni el sistema real.
#
# Uso:
#   bash tests/test_ulauncher_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/productivity/install_ulauncher.sh"
readonly INSTALL_SH
readonly UCI_BIN_NAME="ulauncher"
readonly UCI_PKG_NAME="ulauncher"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|rc|missing> [<upgradable: yes|no>] [<fail_apt_get: yes|no>] [<binary: auto|yes|no>] [<has_add_apt_repository: yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" fail_apt_get="${3:-no}" binary="${4:-auto}" has_aar="${5:-yes}"
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
# Simula que instalar software-properties-common de verdad deja
# 'add-apt-repository' disponible en PATH (igual que en un sistema real),
# aunque el mock haya arrancado sin él (escenario 4). Se escribe línea por
# línea (en vez de un heredoc anidado) para no depender de un segundo
# nivel de expansión de variables.
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

# run_installer <accion> <dpkg_state> [<upgradable>] [<fail_apt_get>] [<binary>] [<has_add_apt_repository>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" fail_apt_get="${4:-no}" binary="${5:-auto}" has_aar="${6:-yes}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${fail_apt_get}" "${binary}" "${has_aar}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. comando desconocido =="
run_installer "esto-no-existe" "missing"
if [[ "${RUN_CODE}" -ne 0 ]]; then pass "comando desconocido sale con código distinto de cero"; else fail "comando desconocido debería fallar"; fi
teardown_mock_bin

echo ""
echo "== 2. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 3. instalación agrega 'universe' y el PPA antes de instalar el paquete =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "add-apt-repository -y universe" "${UCI_MOCK_LOG}" && grep -q "add-apt-repository -y ppa:agornostal/ulauncher" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'install' agrega 'universe' y el PPA, e instala el paquete"
else
    fail "'install' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 4. instalación cuando 'add-apt-repository' no existe todavía instala software-properties-common primero =="
run_installer "install" "missing" "no" "no" "auto" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install -y software-properties-common" "${UCI_MOCK_LOG}"; then
    pass "'install' instala software-properties-common si 'add-apt-repository' no existe"
else
    fail "'install' no instaló software-properties-common cuando debía. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 5. estado instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED"
else
    fail "'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. dpkg 'ii' sin binario resoluble reporta BROKEN =="
run_installer "status" "ii" "no" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN cuando dpkg dice instalado pero el binario no resuelve"
else
    fail "'status' no reportó BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. install sobre estado BROKEN se rechaza =="
run_installer "install" "ii" "no" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' sobre BROKEN rechaza y sugiere 'repair'"
else
    fail "'install' sobre BROKEN no se comportó como se esperaba. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. actualización con candidato disponible =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 9. reparación de estado roto (BROKEN) =="
run_installer "repair" "ii" "no" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 10. intento de reparación cuando no está instalado =="
run_installer "repair" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"install"* ]]; then
    pass "'repair' sobre NOT_INSTALLED rechaza y sugiere 'install'"
else
    fail "'repair' sobre NOT_INSTALLED no se comportó como se esperaba"
fi
teardown_mock_bin

echo ""
echo "== 11. reinstalación explícita no vuelve a tocar el PPA =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && ! grep -q "add-apt-repository" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' usa --reinstall directo, sin volver a agregar el PPA"
else
    fail "'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 12. desinstalación purga el paquete y quita el PPA =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}" && grep -q "add-apt-repository -y --remove ppa:agornostal/ulauncher" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga el paquete (no remove) y quita el PPA"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 13. propagación de errores de APT =="
run_installer "install" "missing" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo real de apt-get se propaga"
else
    fail "un fallo de apt-get debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 14. sin falsos positivos con estado residual 'rc' de dpkg =="
run_installer "status" "rc"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "el estado residual 'rc' se reporta como NOT_INSTALLED"
else
    fail "el estado residual 'rc' no se manejó correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
