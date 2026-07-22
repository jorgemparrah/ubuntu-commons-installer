#!/usr/bin/env bash
# tests/test_ollama_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_ollama.sh (Hito
# 28, ver docs/ROADMAP.md). Usa el mecanismo curl-script
# (scripts/lib/curl_script.sh, ver ADR 0037) para 'install'/'status', pero
# NO reutiliza el test parametrizado genérico
# tests/test_curl_script_contract.sh: el 'uninstall' de Ollama es distinto
# a los demás instaladores curl-script (no asume ~/.local/bin/<binario>,
# sigue los pasos de desinstalación documentados oficialmente:
# systemctl/rm del binario/userdel/groupdel). 'curl' y los comandos de
# desinstalación se interceptan con comandos falsos en un PATH temporal;
# $HOME se apunta a un directorio temporal.
#
# Uso:
#   bash tests/test_ollama_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_ollama.sh"
readonly INSTALL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_bin <binario_presente: yes|no> [<curl_should_fail: yes|no>]
setup_mock_bin() {
    local binario_presente="$1" curl_should_fail="${2:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

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
printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_BIN}/ollama"
chmod +x "${UCI_MOCK_BIN}/ollama"
echo "official-install-ran" >> "${UCI_MOCK_LOG}"
SCRIPT
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    if [[ "${binario_presente}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/ollama" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/ollama"
    fi

    for cmd in systemctl userdel groupdel; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <binario_presente> [<curl_should_fail>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" binario_presente="$2" curl_should_fail="${3:-no}"
    setup_mock_bin "${binario_presente}" "${curl_should_fail}"
    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. comando desconocido =="
run_installer "esto-no-existe" "no"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "comando desconocido sale con código distinto de cero"
else
    fail "comando desconocido debería fallar"
fi
teardown_mock_bin

echo ""
echo "== 2. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 3. install descarga y corre el script oficial =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "official-install-ran" "${UCI_MOCK_LOG}" && [[ -x "${UCI_MOCK_BIN}/ollama" ]]; then
    pass "'install' descarga y corre el script oficial, el binario queda resoluble"
else
    fail "'install' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 4. un fallo real de curl se propaga =="
run_installer "install" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo real de curl se propaga como código distinto de cero"
else
    fail "un fallo de curl debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 5. status con el binario presente: INSTALLED =="
run_installer "status" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con el binario presente"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. uninstall sigue los pasos oficiales (systemd + binario + usuario/grupo dedicados) =="
run_installer "uninstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "systemctl stop ollama" "${UCI_MOCK_LOG}" && grep -q "systemctl disable ollama" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' detiene y deshabilita el servicio systemd de Ollama"
else
    fail "'uninstall' no detuvo/deshabilitó el servicio esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ ! -e "${UCI_MOCK_BIN}/ollama" ]]; then
    pass "'uninstall' elimina el binario de Ollama"
else
    fail "'uninstall' no eliminó el binario de Ollama"
fi
if grep -q "userdel ollama" "${UCI_MOCK_LOG}" && grep -q "groupdel ollama" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' elimina el usuario/grupo dedicados de Ollama"
else
    fail "'uninstall' no eliminó el usuario/grupo esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 7. update/repair se rechazan explícitamente (no implementados a propósito) =="
for verb in update repair; do
    run_installer "${verb}" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "'${verb}' se rechaza explícitamente"
    else
        fail "'${verb}' debería rechazarse"
    fi
    teardown_mock_bin
done

echo ""
echo "== 8. reinstall (fallback mecánico del dispatcher) deja el binario instalado =="
run_installer "reinstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ -x "${UCI_MOCK_BIN}/ollama" ]]; then
    pass "'reinstall' deja el binario instalado"
else
    fail "'reinstall' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
