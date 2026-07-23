#!/usr/bin/env bash
# tests/test_procs_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_procs.sh (Hito 39,
# ver docs/ROADMAP.md). Segundo caso real del mecanismo
# `manager=archive-direct` (el primero fue xh, con `.tar.gz` — ver
# tests/test_xh_installer.sh): procs no está en apt/snap ni publica
# `.deb`, solo un `.zip` con el binario suelto en la raíz (a diferencia
# del tarball de xh, sin subdirectorio versionado). No instala nada
# real: 'curl'/'unzip' se interceptan con comandos falsos en un PATH
# temporal; 'curl' distingue la consulta a la API de GitHub (JSON falso)
# de la descarga del zip ('-o', contenido falso); 'unzip' se mockea
# explícitamente (en vez de generar un `.zip` real): simula la
# extracción escribiendo el binario `procs` directo en el directorio
# destino. $HOME se apunta a un directorio temporal para no tocar el
# ~/.local/bin real de esta máquina.
#
# Uso:
#   bash tests/test_procs_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_procs.sh"
readonly INSTALL_SH
readonly UCI_FAKE_ZIP_URL="https://github.com/dalance/procs/releases/download/v0.14.12/procs-v0.14.12-x86_64-linux.zip"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_env <instalado: yes|no> [<api_fail: yes|no>]
setup_mock_env() {
    local instalado="$1" api_fail="${2:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    if [[ "${instalado}" == "yes" ]]; then
        mkdir -p "${UCI_MOCK_HOME}/.local/bin"
        printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/.local/bin/procs"
        chmod +x "${UCI_MOCK_HOME}/.local/bin/procs"
    fi

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$*" == *"api.github.com"* ]]; then
    if [[ "${api_fail}" == "yes" ]]; then
        exit 1
    fi
    echo '{"assets": [{"browser_download_url": "${UCI_FAKE_ZIP_URL}"}]}'
    exit 0
fi
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then dest="\${arg}"; fi
    prev="\${arg}"
done
echo "contenido-falso-zip" > "\${dest}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    # 'unzip' simula la extracción real: escribe el binario 'procs'
    # directo en el directorio destino (-d), sin subdirectorio (a
    # diferencia del tarball de xh).
    cat > "${UCI_MOCK_BIN}/unzip" <<EOF
#!/usr/bin/env bash
echo "unzip \$*" >> "${UCI_MOCK_LOG}"
dest_dir=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-d" ]]; then dest_dir="\${arg}"; fi
    prev="\${arg}"
done
printf '#!/usr/bin/env bash\nexit 0\n' > "\${dest_dir}/procs"
chmod +x "\${dest_dir}/procs"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/unzip"
}

teardown_mock_env() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <instalado> [<api_fail>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" instalado="$2" api_fail="${3:-no}"
    setup_mock_env "${instalado}" "${api_fail}"
    set +e
    RUN_OUTPUT="$(HOME="${UCI_MOCK_HOME}" PATH="${UCI_MOCK_BIN}:${UCI_MOCK_HOME}/.local/bin:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
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
echo "== 3. install: resuelve la URL, descarga y extrae el zip, deja el binario en ~/.local/bin =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*api.github.com/repos/dalance/procs/releases/latest" "${UCI_MOCK_LOG}"; then
    pass "'install' consulta la API de GitHub Releases del repo oficial"
else
    fail "'install' no consultó la API esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -qF "curl -fsSL ${UCI_FAKE_ZIP_URL}" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga el zip resuelto dinámicamente"
else
    fail "'install' no descargó el zip esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "unzip -oq" "${UCI_MOCK_LOG}"; then
    pass "'install' extrae el zip descargado"
else
    fail "'install' no extrajo el zip. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ -x "${UCI_MOCK_HOME}/.local/bin/procs" ]]; then
    pass "queda el binario 'procs' ejecutable en ~/.local/bin tras 'install'"
else
    fail "no quedó el binario esperado en ~/.local/bin tras 'install'"
fi
teardown_mock_env

echo ""
echo "== 4. install: un fallo real de la API de GitHub se propaga =="
run_installer "install" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de la API de GitHub se propaga como código distinto de cero"
else
    fail "un fallo de la API debería propagarse como código distinto de cero"
fi
teardown_mock_env

echo ""
echo "== 5. status con el binario presente: INSTALLED =="
run_installer "status" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con el binario presente"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 6. install rechaza si ya está instalado =="
run_installer "install" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"reinstall"* ]]; then
    pass "'install' rechaza y sugiere 'reinstall' si ya está instalado"
else
    fail "'install' debería rechazar si ya está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_env

echo ""
echo "== 7. uninstall elimina el binario de ~/.local/bin =="
run_installer "uninstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ ! -e "${UCI_MOCK_HOME}/.local/bin/procs" ]]; then
    pass "'uninstall' elimina el binario de ~/.local/bin"
else
    fail "'uninstall' no eliminó el binario esperado (código ${RUN_CODE})"
fi
teardown_mock_env

echo ""
echo "== 8. uninstall sobre NOT_INSTALLED no falla =="
run_installer "uninstall" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sobre NOT_INSTALLED no falla"
else
    fail "'uninstall' sobre NOT_INSTALLED no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_env

echo ""
echo "== 9. update/repair se rechazan explícitamente (no implementados a propósito) =="
for verb in update repair; do
    run_installer "${verb}" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "'${verb}' se rechaza explícitamente"
    else
        fail "'${verb}' debería rechazarse"
    fi
    teardown_mock_env
done

print_test_summary
exit_with_test_summary
