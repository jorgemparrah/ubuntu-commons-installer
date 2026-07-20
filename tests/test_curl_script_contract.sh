#!/usr/bin/env bash
# tests/test_curl_script_contract.sh
#
# Prueba simulada (mocks) del ciclo de vida de los instaladores del
# mecanismo curl-script (Hito 16, ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md): Claude Code,
# Codex CLI, OpenCode, Antigravity CLI, OpenClaw, Hermes Agent. Ninguno
# corre contra la red real ni el proveedor oficial: 'curl' se intercepta
# con un comando falso en un PATH temporal que escribe un script "oficial"
# de prueba (crea el binario esperado en un directorio simulado de
# ~/.local/bin), y $HOME se apunta a un directorio temporal para no tocar
# el ~/.local/bin real de esta máquina.
#
# Uso:
#   bash tests/test_curl_script_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_env <binary_name> <curl_should_fail: yes|no>
setup_mock_env() {
    local binary_name="$1" curl_should_fail="${2:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    mkdir -p "${UCI_MOCK_HOME}/.local/bin"

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "${curl_should_fail}" == "yes" ]]; then
    exit 1
fi
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then dest="\${arg}"; fi
    prev="\${arg}"
done
cat > "\${dest}" <<SCRIPT
#!/usr/bin/env bash
mkdir -p "${UCI_MOCK_HOME}/.local/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/.local/bin/${binary_name}"
chmod +x "${UCI_MOCK_HOME}/.local/bin/${binary_name}"
echo "official-install-ran" >> "${UCI_MOCK_LOG}"
SCRIPT
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"
}

teardown_mock_env() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <binary_name> <curl_should_fail>
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" binary_name="$3" curl_should_fail="${4:-no}"
    setup_mock_env "${binary_name}" "${curl_should_fail}"
    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_curl_script_contract <script> <label> <binary_name>
test_curl_script_contract() {
    local script="${UCI_REPO_ROOT}/$1" label="$2" binary_name="$3"

    echo ""
    echo "== ${label} (${script#"${UCI_REPO_ROOT}"/}) =="

    run_installer "${script}" "esto-no-existe" "${binary_name}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then pass "${label}: comando desconocido sale con código distinto de cero"; else fail "${label}: comando desconocido debería fallar"; fi
    teardown_mock_env

    run_installer "${script}" "status" "${binary_name}"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${label}: estado inicial reporta NOT_INSTALLED"
    else
        fail "${label}: estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_env

    run_installer "${script}" "install" "${binary_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && [[ -x "${UCI_MOCK_HOME}/.local/bin/${binary_name}" ]] && grep -q "official-install-ran" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'install' descarga y corre el script oficial, el binario queda instalado"
    else
        fail "${label}: 'install' no se comportó como se esperaba (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_env

    run_installer "${script}" "install" "${binary_name}" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: un fallo real de 'curl' se propaga"
    else
        fail "${label}: un fallo de 'curl' debería propagarse como código distinto de cero"
    fi
    teardown_mock_env

    # 'status' después de instalar: se seedea el binario directamente en
    # $HOME/.local/bin (equivalente a haber corrido 'install' antes).
    setup_mock_env "${binary_name}"
    mkdir -p "${UCI_MOCK_HOME}/.local/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/.local/bin/${binary_name}"
    chmod +x "${UCI_MOCK_HOME}/.local/bin/${binary_name}"
    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" bash "${script}" status 2>&1)"
    RUN_CODE=$?
    set -e
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "${label}: 'status' reporta INSTALLED con el binario ya presente"
    else
        fail "${label}: 'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi

    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" bash "${script}" uninstall 2>&1)"
    RUN_CODE=$?
    set -e
    if [[ "${RUN_CODE}" -eq 0 && ! -e "${UCI_MOCK_HOME}/.local/bin/${binary_name}" ]]; then
        pass "${label}: 'uninstall' remueve el binario de \$HOME/.local/bin"
    else
        fail "${label}: 'uninstall' no removió el binario (código ${RUN_CODE})"
    fi
    teardown_mock_env

    run_installer "${script}" "repair" "${binary_name}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: 'repair' se rechaza explícitamente (no implementado a propósito)"
    else
        fail "${label}: 'repair' debería rechazarse"
    fi
    teardown_mock_env

    run_installer "${script}" "update" "${binary_name}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: 'update' se rechaza explícitamente (no implementado a propósito)"
    else
        fail "${label}: 'update' debería rechazarse"
    fi
    teardown_mock_env

    run_installer "${script}" "reinstall" "${binary_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && [[ -x "${UCI_MOCK_HOME}/.local/bin/${binary_name}" ]]; then
        pass "${label}: 'reinstall' (fallback mecánico del dispatcher) deja el binario instalado"
    else
        fail "${label}: 'reinstall' no se comportó como se esperaba (código ${RUN_CODE})"
    fi
    teardown_mock_env
}

test_curl_script_contract "scripts/development/install_claude_code.sh" "Claude Code" "claude"
test_curl_script_contract "scripts/development/install_codex_cli.sh" "Codex CLI" "codex"
test_curl_script_contract "scripts/development/install_opencode.sh" "OpenCode" "opencode"
test_curl_script_contract "scripts/development/install_antigravity.sh" "Antigravity CLI" "agy"
test_curl_script_contract "scripts/productivity/install_openclaw.sh" "OpenClaw" "openclaw"
test_curl_script_contract "scripts/productivity/install_hermes_agent.sh" "Hermes Agent" "hermes"

print_test_summary
exit_with_test_summary
