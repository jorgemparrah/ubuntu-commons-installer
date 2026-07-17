#!/usr/bin/env bash
# tests/test_system_utils_contract.sh
#
# Prueba simulada (comandos interceptados/mocks) para el Hito 9, Fase B:
# confirma que scripts/system/install_system_utils.sh,
# install_development_tools.sh e install_multimedia.sh dejaron de
# autoejecutarse incondicionalmente al cargarse (hallazgo más grave de la
# auditoría, ver docs/UBUNTU_COMPATIBILITY.md) y ahora exponen el contrato
# estándar status|install|uninstall|reinstall. No instala nada real: apt,
# sudo y dpkg se interceptan con comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_system_utils_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

UCI_TESTS_RUN=0
UCI_TESTS_FAILED=0

pass() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    echo "  OK  - $1"
}

fail() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    UCI_TESTS_FAILED=$((UCI_TESTS_FAILED + 1))
    echo "FALLO - $1"
}

# setup_mock_bin <estado_dpkg: installed|not_installed>
# Arma un directorio con dpkg/apt/sudo falsos y lo antepone al PATH. dpkg -s
# "sale con éxito" (simula ya instalado) o falla (simula no instalado),
# según el estado pedido. apt/sudo solo registran su invocación en
# UCI_MOCK_LOG, nunca hacen nada real.
UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

setup_mock_bin() {
    local dpkg_state="$1"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-s" ]]; then
    if [[ "${dpkg_state}" == "installed" ]]; then
        exit 0
    else
        exit 1
    fi
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<EOF
#!/usr/bin/env bash
echo "sudo \$*" >> "${UCI_MOCK_LOG}"
"\$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <estado_dpkg>
# Devuelve el código de salida por stdout en la variable global RUN_CODE,
# y deja la salida real en RUN_OUTPUT.
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="${2:-}" dpkg_state="$3"
    setup_mock_bin "${dpkg_state}"

    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" ${action} 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_installer_contract <script> <nombre>
test_installer_contract() {
    local script="$1" name="$2"

    echo ""
    echo "== ${name} (${script}) =="

    # 1) Cargar/invocar sin argumentos NO debe instalar nada (regresión del
    # hallazgo de autoejecución incondicional).
    run_installer "${script}" "" "not_installed"
    if grep -q "apt install" "${UCI_MOCK_LOG}"; then
        fail "${name}: invocar sin argumentos no debería instalar nada (se detectó 'apt install')"
    else
        pass "${name}: invocar sin argumentos no instala nada"
    fi
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: invocar sin argumentos debería salir con código distinto de cero (uso inválido)"
    else
        pass "${name}: invocar sin argumentos sale con código distinto de cero"
    fi
    teardown_mock_bin

    # 2) Subcomando inválido: código distinto de cero.
    run_installer "${script}" "esto-no-existe" "not_installed"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: subcomando inválido debería salir con código distinto de cero"
    else
        pass "${name}: subcomando inválido sale con código distinto de cero"
    fi
    teardown_mock_bin

    # 3) status cuando los paquetes ya están "instalados" (mock): INSTALLED,
    # código 0, y NO debe intentar instalar nada (idempotencia básica).
    run_installer "${script}" "status" "installed"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        fail "${name}: 'status' con paquetes ya instalados debería salir con código 0 (fue ${RUN_CODE})"
    else
        pass "${name}: 'status' con paquetes ya instalados sale con código 0"
    fi
    if [[ "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "${name}: 'status' reporta INSTALLED cuando corresponde"
    else
        fail "${name}: 'status' no reportó INSTALLED. Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "apt install" "${UCI_MOCK_LOG}"; then
        fail "${name}: 'status' no debería instalar nada"
    else
        pass "${name}: 'status' es de solo lectura (no llama 'apt install')"
    fi
    teardown_mock_bin

    # 4) status cuando faltan paquetes: NOT_INSTALLED, código distinto de cero.
    run_installer "${script}" "status" "not_installed"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: 'status' sin paquetes instalados debería salir con código distinto de cero"
    else
        pass "${name}: 'status' sin paquetes instalados sale con código distinto de cero"
    fi
    if [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${name}: 'status' reporta NOT_INSTALLED cuando corresponde"
    else
        fail "${name}: 'status' no reportó NOT_INSTALLED. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    # 5) install: sí debe invocar 'apt install' (mock), y salir con código 0.
    run_installer "${script}" "install" "not_installed"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        fail "${name}: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    else
        pass "${name}: 'install' sale con código 0"
    fi
    if grep -q "apt install" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' invoca 'apt install'"
    else
        fail "${name}: 'install' no invocó 'apt install'. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin
}

test_installer_contract "${UCI_REPO_ROOT}/scripts/system/install_system_utils.sh" "System Utils"
test_installer_contract "${UCI_REPO_ROOT}/scripts/system/install_development_tools.sh" "Development Tools"
test_installer_contract "${UCI_REPO_ROOT}/scripts/system/install_multimedia.sh" "Multimedia"

echo ""
echo "== install_multimedia.sh usa DEBIAN_FRONTEND=noninteractive (EULA de ubuntu-restricted-extras) =="
if grep -q "DEBIAN_FRONTEND=noninteractive" "${UCI_REPO_ROOT}/scripts/system/install_multimedia.sh"; then
    pass "install_multimedia.sh fija DEBIAN_FRONTEND=noninteractive antes de instalar"
else
    fail "install_multimedia.sh no fija DEBIAN_FRONTEND=noninteractive"
fi

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
