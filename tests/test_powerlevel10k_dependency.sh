#!/usr/bin/env bash
# tests/test_powerlevel10k_dependency.sh
#
# Prueba simulada (mocks) del campo `depends_on` (Hito 17, ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md):
# install_powerlevel10k.sh depende de que Oh My Zsh ya esté instalado. No
# instala nada real: apt-get/dpkg/git/sudo se interceptan con comandos
# falsos en un PATH temporal; ~/.oh-my-zsh se simula creando/omitiendo
# ~/.oh-my-zsh/.git (lo único que revisa git_clone_present).
#
# Uso:
#   bash tests/test_powerlevel10k_dependency.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_P10K_SH="${UCI_REPO_ROOT}/scripts/system/install_powerlevel10k.sh"
readonly INSTALL_P10K_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_TEST_HOME=""

# setup_mock_bin
# apt-get/dpkg/sudo/git/zsh falsos: siempre exitosos, solo registran que
# fueron invocados (no se necesita simular ningún estado de dpkg acá, a
# diferencia de otros tests de instaladores APT).
setup_mock_bin() {
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    for cmd in apt-get dpkg git; do
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

    cat > "${UCI_MOCK_BIN}/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/zsh"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

echo "== 1. Oh My Zsh no instalado: install_powerlevel10k.sh rechaza explícitamente =="
UCI_TEST_HOME="$(mktemp -d)"
setup_mock_bin
set +e
RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" HOME="${UCI_TEST_HOME}" bash "${INSTALL_P10K_SH}" install 2>&1)"
RUN_CODE=$?
set -e
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'install' rechaza (código distinto de cero) si Oh My Zsh no está instalado"
else
    fail "'install' debería rechazar si Oh My Zsh no está instalado (código ${RUN_CODE})"
fi
if [[ "${RUN_OUTPUT}" == *"Oh My Zsh"* ]] && [[ "${RUN_OUTPUT}" == *"install_oh_my_zsh.sh"* ]]; then
    pass "el rechazo menciona explícitamente Oh My Zsh y cómo instalarlo"
else
    fail "el mensaje de rechazo no fue lo bastante explícito. Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get" "${UCI_MOCK_LOG}" 2>/dev/null; then
    fail "no debería haber intentado instalar nada (apt-get) antes de verificar la dependencia"
else
    pass "no se ejecuta ninguna acción de instalación antes de rechazar por la dependencia faltante"
fi
teardown_mock_bin
rm -rf "${UCI_TEST_HOME}"

echo ""
echo "== 2. Oh My Zsh ya instalado: install_powerlevel10k.sh continúa normalmente =="
UCI_TEST_HOME="$(mktemp -d)"
mkdir -p "${UCI_TEST_HOME}/.oh-my-zsh/.git"
setup_mock_bin
set +e
RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" HOME="${UCI_TEST_HOME}" bash "${INSTALL_P10K_SH}" install 2>&1)"
RUN_CODE=$?
set -e
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0 cuando Oh My Zsh ya está instalado"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" == *"Falta instalar Oh My Zsh"* ]]; then
    fail "no debería rechazar por la dependencia si Oh My Zsh ya está instalado"
else
    pass "no rechaza por la dependencia cuando Oh My Zsh ya está instalado"
fi
teardown_mock_bin
rm -rf "${UCI_TEST_HOME}"

print_test_summary
exit_with_test_summary
