#!/usr/bin/env bash
# tests/test_xh_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_xh.sh (Hito 38, ver
# docs/ROADMAP.md). Primer y único caso hasta ahora del mecanismo
# `tarball-direct`: xh no está en apt/snap ni publica un `.deb`, solo
# tarballs `.tar.gz` en GitHub Releases. No instala nada real:
# 'curl'/'tar' se interceptan con comandos falsos en un PATH temporal;
# 'curl' distingue la consulta a la API de GitHub (JSON falso) de la
# descarga del tarball ('-o', contenido falso); 'tar' se mockea
# explícitamente (en vez de generar un `.tar.gz` real): simula la
# extracción creando el árbol de directorios que el tarball real
# contiene (`xh-v<version>-x86_64-unknown-linux-musl/xh`). $HOME se
# apunta a un directorio temporal para no tocar el ~/.local/bin real de
# esta máquina.
#
# Uso:
#   bash tests/test_xh_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_xh.sh"
readonly INSTALL_SH
readonly UCI_FAKE_TARBALL_URL="https://github.com/ducaale/xh/releases/download/v0.26.1/xh-v0.26.1-x86_64-unknown-linux-musl.tar.gz"

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
        printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/.local/bin/xh"
        chmod +x "${UCI_MOCK_HOME}/.local/bin/xh"
    fi

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$*" == *"api.github.com"* ]]; then
    if [[ "${api_fail}" == "yes" ]]; then
        exit 1
    fi
    echo '{"assets": [{"browser_download_url": "${UCI_FAKE_TARBALL_URL}"}]}'
    exit 0
fi
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then dest="\${arg}"; fi
    prev="\${arg}"
done
echo "contenido-falso-tar-gz" > "\${dest}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    # 'tar' simula la extracción real: crea el árbol de directorios que
    # el tarball oficial contiene, con el binario 'xh' en su ruta
    # anidada real (xh-v<version>-x86_64-unknown-linux-musl/xh).
    cat > "${UCI_MOCK_BIN}/tar" <<EOF
#!/usr/bin/env bash
echo "tar \$*" >> "${UCI_MOCK_LOG}"
dest_dir=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-C" ]]; then dest_dir="\${arg}"; fi
    prev="\${arg}"
done
mkdir -p "\${dest_dir}/xh-v0.26.1-x86_64-unknown-linux-musl"
printf '#!/usr/bin/env bash\nexit 0\n' > "\${dest_dir}/xh-v0.26.1-x86_64-unknown-linux-musl/xh"
chmod +x "\${dest_dir}/xh-v0.26.1-x86_64-unknown-linux-musl/xh"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/tar"
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
echo "== 3. install: resuelve la URL, descarga y extrae el tarball, deja el binario en ~/.local/bin =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*api.github.com/repos/ducaale/xh/releases/latest" "${UCI_MOCK_LOG}"; then
    pass "'install' consulta la API de GitHub Releases del repo oficial"
else
    fail "'install' no consultó la API esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -qF "curl -fsSL ${UCI_FAKE_TARBALL_URL}" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga el tarball resuelto dinámicamente"
else
    fail "'install' no descargó el tarball esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "tar -xzf" "${UCI_MOCK_LOG}"; then
    pass "'install' extrae el tarball descargado"
else
    fail "'install' no extrajo el tarball. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ -x "${UCI_MOCK_HOME}/.local/bin/xh" ]]; then
    pass "queda el binario 'xh' ejecutable en ~/.local/bin tras 'install'"
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
if [[ "${RUN_CODE}" -eq 0 ]] && [[ ! -e "${UCI_MOCK_HOME}/.local/bin/xh" ]]; then
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
