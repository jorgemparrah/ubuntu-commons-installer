#!/usr/bin/env bash
# tests/test_install_profile.sh
#
# Prueba simulada (mocks) de 'setup.sh install --profile <nombre>' (Hito
# 13, ver docs/ROADMAP.md). No instala nada real de los 53 mecanismos
# distintos del catálogo: usa el perfil 'ai-cli' (Claude Code, Codex CLI,
# OpenCode, Antigravity CLI), las 4 únicas herramientas que comparten
# exactamente el mismo mecanismo curl-script (ver
# docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md), y mockea 'curl'
# igual que tests/test_curl_script_contract.sh — sin red real, sin tocar
# el $HOME real de esta workstation.
#
# Uso:
#   bash tests/test_install_profile.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
SETUP_SH="${UCI_REPO_ROOT}/setup.sh"
readonly SETUP_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_env: crea un 'curl' falso que, según la URL pedida (-o dest),
# escribe un script "oficial" de prueba que crea el binario esperado en
# $HOME/.local/bin de un $HOME temporal.
setup_mock_env() {
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    mkdir -p "${UCI_MOCK_HOME}/.local/bin"

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
url=""
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then dest="\${arg}"; fi
    if [[ "\${arg}" != -* && -z "\${url}" ]]; then url="\${arg}"; fi
    prev="\${arg}"
done
case "\${url}" in
    *claude.ai*) bin_name="claude" ;;
    *chatgpt.com*) bin_name="codex" ;;
    *opencode.ai*) bin_name="opencode" ;;
    *antigravity.google*) bin_name="agy" ;;
    *) echo "curl mock: URL inesperada \${url}" >&2; exit 1 ;;
esac
cat > "\${dest}" <<SCRIPT
#!/usr/bin/env bash
mkdir -p "${UCI_MOCK_HOME}/.local/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/.local/bin/\${bin_name}"
chmod +x "${UCI_MOCK_HOME}/.local/bin/\${bin_name}"
echo "official-install-ran: \${bin_name}" >> "${UCI_MOCK_LOG}"
SCRIPT
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"
}

teardown_mock_env() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

RUN_OUTPUT=""
RUN_CODE=0
run_setup() {
    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" UCI_HOME_DIR="${UCI_MOCK_HOME}" \
        PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" \
        bash "${SETUP_SH}" install "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 'install --profile' con perfil desconocido =="
setup_mock_env
run_setup --profile no-existe
if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"Perfil desconocido"* ]]; then
    pass "perfil desconocido sale con código distinto de cero y mensaje claro"
else
    fail "perfil desconocido no se manejó como se esperaba (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 'install --profile ai-cli' instala las 4 CLIs de IA (mocks de curl) =="
setup_mock_env
run_setup --profile ai-cli
check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        pass "${description}"
    else
        fail "${description} (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
}
check "'install --profile ai-cli' sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
check "instala Claude Code" '[[ -x "${UCI_MOCK_HOME}/.local/bin/claude" ]]'
check "instala Codex CLI" '[[ -x "${UCI_MOCK_HOME}/.local/bin/codex" ]]'
check "instala OpenCode" '[[ -x "${UCI_MOCK_HOME}/.local/bin/opencode" ]]'
check "instala Antigravity CLI (agy)" '[[ -x "${UCI_MOCK_HOME}/.local/bin/agy" ]]'
check "el resumen final reporta 4 instalados" '[[ "${RUN_OUTPUT}" == *"4 instalado(s)"* ]]'
teardown_mock_env

echo ""
echo "== 'install --profile ai-cli' es idempotente (segunda corrida no reinstala) =="
setup_mock_env
run_setup --profile ai-cli
run_setup --profile ai-cli
check "la segunda corrida sale con código 0" '[[ ${RUN_CODE} -eq 0 ]]'
check "la segunda corrida reporta 4 ya presentes, 0 instalados" '[[ "${RUN_OUTPUT}" == *"0 instalado(s), 4 ya presente(s)"* ]]'
teardown_mock_env

print_test_summary
exit_with_test_summary
