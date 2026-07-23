#!/usr/bin/env bash
# tests/test_joplin_installer.sh
#
# Prueba simulada (mocks) de scripts/productivity/install_joplin.sh
# (Hito 36, ver docs/ROADMAP.md). Mecanismo curl-script (reutiliza
# curl_script_run de scripts/lib/curl_script.sh para el paso de
# descarga/ejecución), pero con check_status/uninstall_tool propios: el
# script oficial de Joplin instala en `~/.joplin/Joplin.AppImage`, sin
# symlink en el PATH — no encaja en la convención genérica
# `~/.local/bin/<binario>` del resto del grupo curl-script (mismo
# criterio de adaptación que install_ollama.sh). 'curl' se intercepta con
# un comando falso que escribe un script "oficial" de prueba (crea el
# AppImage simulado en un $HOME temporal); $HOME se apunta a ese
# directorio para no tocar el ~/.joplin real de esta máquina.
#
# Uso:
#   bash tests/test_joplin_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/productivity/install_joplin.sh"
readonly INSTALL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_env <instalado: yes|no> [<curl_should_fail: yes|no>] [<appimage_ejecutable: yes|no>]
setup_mock_env() {
    local instalado="$1" curl_should_fail="${2:-no}" appimage_ejecutable="${3:-yes}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    if [[ "${instalado}" == "yes" ]]; then
        mkdir -p "${UCI_MOCK_HOME}/.joplin"
        printf 'contenido-falso-appimage\n' > "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage"
        if [[ "${appimage_ejecutable}" == "yes" ]]; then
            chmod +x "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage"
        else
            chmod -x "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage"
        fi
    fi

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
mkdir -p "${UCI_MOCK_HOME}/.joplin"
printf 'contenido-falso-appimage\n' > "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage"
chmod +x "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage"
echo "1.99.0" > "${UCI_MOCK_HOME}/.joplin/VERSION"
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

# run_installer <acción> <instalado> [<curl_should_fail>] [<appimage_ejecutable>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" instalado="$2" curl_should_fail="${3:-no}" appimage_ejecutable="${4:-yes}"
    setup_mock_env "${instalado}" "${curl_should_fail}" "${appimage_ejecutable}"
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
teardown_mock_env

echo ""
echo "== 2. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 3. install: descarga y corre el script oficial, deja el AppImage instalado =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*Joplin_install_and_update.sh" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga el script oficial de Joplin"
else
    fail "'install' no descargó el script esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "official-install-ran" "${UCI_MOCK_LOG}"; then
    pass "'install' corre el script oficial descargado"
else
    fail "'install' no corrió el script oficial. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ -x "${UCI_MOCK_HOME}/.joplin/Joplin.AppImage" ]]; then
    pass "queda el AppImage ejecutable en ~/.joplin/Joplin.AppImage tras 'install'"
else
    fail "no quedó el AppImage esperado tras 'install'"
fi
teardown_mock_env

echo ""
echo "== 4. install: un fallo real de curl se propaga =="
run_installer "install" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de curl se propaga como código distinto de cero"
else
    fail "un fallo de curl debería propagarse como código distinto de cero"
fi
teardown_mock_env

echo ""
echo "== 5. status con el AppImage presente: INSTALLED =="
run_installer "status" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con el AppImage presente y ejecutable"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 6. status con el AppImage presente pero no ejecutable: BROKEN =="
run_installer "status" "yes" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el AppImage no es ejecutable"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 7. install rechaza si ya está instalado (pide 'update') =="
run_installer "install" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"update"* ]]; then
    pass "'install' rechaza y sugiere 'update' si ya está instalado"
else
    fail "'install' debería rechazar si ya está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 8. uninstall elimina el directorio ~/.joplin =="
run_installer "uninstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ ! -d "${UCI_MOCK_HOME}/.joplin" ]]; then
    pass "'uninstall' elimina el directorio ~/.joplin"
else
    fail "'uninstall' no eliminó el directorio esperado (código ${RUN_CODE})"
fi
teardown_mock_env

echo ""
echo "== 9. uninstall sobre NOT_INSTALLED no falla =="
run_installer "uninstall" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sobre NOT_INSTALLED no falla"
else
    fail "'uninstall' sobre NOT_INSTALLED no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_env

echo ""
echo "== 10. update corre el script oficial de nuevo =="
run_installer "update" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "official-install-ran" "${UCI_MOCK_LOG}"; then
    pass "'update' corre el script oficial de nuevo"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_env

echo ""
echo "== 11. repair se rechaza explícitamente (no implementado a propósito) =="
run_installer "repair" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'repair' se rechaza explícitamente"
else
    fail "'repair' debería rechazarse"
fi
teardown_mock_env

print_test_summary
exit_with_test_summary
