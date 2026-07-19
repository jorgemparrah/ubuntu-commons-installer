#!/usr/bin/env bash
# tests/test_system_update_contract.sh
#
# Prueba simulada (comandos interceptados/mocks) para el Hito 9, Fase B:
# confirma que scripts/system/install_system_update.sh y
# scripts/maintenance/install_final_update.sh dejaron de reportar
# 'INSTALLED' incondicionalmente en 'status' (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md, ver docs/adr/0013-separar-mantenimiento-de-instaladores.md)
# y ahora hacen un diagnóstico real de solo lectura. No ejecuta ningún
# 'apt upgrade'/'apt autoremove' real: apt/apt-get/sudo se interceptan
# con comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_system_update_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <upgradable_count> <autoremovable_count>
setup_mock_bin() {
    local upgradable="$1" autoremovable="$2"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" ]]; then
    echo "Listing..."
    for ((i=0; i<${upgradable}; i++)); do
        echo "paquete-falso-\${i}/noble 2.0 amd64 [upgradable from: 1.0]"
    done
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$*" == *"--simulate autoremove"* ]]; then
    for ((i=0; i<${autoremovable}; i++)); do
        echo "Remv paquete-huerfano-\${i} [1.0]"
    done
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

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

RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" upgradable="$3" autoremovable="${4:-0}"
    setup_mock_bin "${upgradable}" "${autoremovable}"

    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

test_status_contract() {
    local script="$1" name="$2"

    echo ""
    echo "== ${name} (${script}) =="

    run_installer "${script}" "status" "0" "0"
    if [[ "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* && "${RUN_CODE}" -eq 0 ]]; then
        pass "${name}: 'status' reporta INSTALLED (sin pendientes) y código 0"
    else
        fail "${name}: 'status' sin pendientes debería reportar INSTALLED/código 0. Salida: ${RUN_OUTPUT} (código ${RUN_CODE})"
    fi
    if grep -qE "apt (upgrade|autoremove)|apt-get (upgrade|autoremove -y)" "${UCI_MOCK_LOG}"; then
        fail "${name}: 'status' no debería ejecutar upgrade/autoremove real"
    else
        pass "${name}: 'status' es de solo lectura"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "3" "0"
    if [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* && "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: 'status' con actualizaciones pendientes reporta NOT_INSTALLED y código distinto de cero"
    else
        fail "${name}: 'status' con actualizaciones pendientes no reportó lo esperado. Salida: ${RUN_OUTPUT} (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "0" "0"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "${name}: 'install' sale con código 0"
    else
        fail "${name}: 'install' debería salir con código 0. Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "apt upgrade" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' sí invoca 'apt upgrade' (es la acción real)"
    else
        fail "${name}: 'install' no invocó 'apt upgrade'"
    fi
    teardown_mock_bin

    run_installer "${script}" "esto-no-existe" "0" "0"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: subcomando inválido sale con código distinto de cero"
    else
        fail "${name}: subcomando inválido debería salir con código distinto de cero"
    fi
    teardown_mock_bin
}

test_status_contract "${UCI_REPO_ROOT}/scripts/system/install_system_update.sh" "System Update"
test_status_contract "${UCI_REPO_ROOT}/scripts/maintenance/install_final_update.sh" "Final Update"

echo ""
echo "== install_final_update.sh: 'status' también considera paquetes huérfanos (autoremove) =="
run_installer "${UCI_REPO_ROOT}/scripts/maintenance/install_final_update.sh" "status" "0" "2"
if [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* && "${RUN_CODE}" -ne 0 ]]; then
    pass "Final Update: 'status' reporta NOT_INSTALLED cuando hay paquetes huérfanos, aunque no haya upgrades pendientes"
else
    fail "Final Update: 'status' no consideró los paquetes huérfanos. Salida: ${RUN_OUTPUT} (código ${RUN_CODE})"
fi
teardown_mock_bin

print_test_summary

exit_with_test_summary
