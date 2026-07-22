#!/usr/bin/env bash
# tests/test_soapui_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_soapui.sh (Hito
# 29, ver docs/ROADMAP.md). Mecanismo propio (instalador .sh tipo IzPack,
# URL resuelta dinámicamente vía scripts/lib/github_release.sh). No
# instala nada real: 'curl' se intercepta con un mock en un PATH temporal
# que, para la consulta a la API de GitHub, devuelve JSON falso con la
# URL del instalador; para la descarga del instalador en sí, escribe un
# script falso que simula lo que dejaría el instalador real corrido con
# '-q' (crea el árbol de directorios `$HOME/SoapUI-<version>/bin/soapui.sh`
# — ver la advertencia de incertidumbre en el propio instalador sobre si
# esa es realmente la ruta que deja el instalador real). $HOME se apunta
# a un directorio temporal para no tocar el `$HOME` real de esta máquina.
#
# Uso:
#   bash tests/test_soapui_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_soapui.sh"
readonly INSTALL_SH
readonly UCI_FAKE_INSTALLER_URL="https://github.com/SmartBear/soapui/releases/download/v5.99.0/SoapUI-x64-5.99.0.sh"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_HOME=""
UCI_MOCK_LOG=""

# setup_mock_bin <instalado: yes|no> [<api_fail: yes|no>] [<installer_deja_binario: yes|no>]
setup_mock_bin() {
    local instalado="$1" api_fail="${2:-no}" deja_binario="${3:-yes}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_HOME="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    if [[ "${instalado}" == "yes" ]]; then
        mkdir -p "${UCI_MOCK_HOME}/SoapUI-5.10.0/bin"
        printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/SoapUI-5.10.0/bin/soapui.sh"
        chmod +x "${UCI_MOCK_HOME}/SoapUI-5.10.0/bin/soapui.sh"
    fi

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$*" == *"api.github.com"* ]]; then
    if [[ "${api_fail}" == "yes" ]]; then
        exit 1
    fi
    echo '{"browser_download_url": "${UCI_FAKE_INSTALLER_URL}"}'
    exit 0
fi
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then dest="\${arg}"; fi
    prev="\${arg}"
done
cat > "\${dest}" <<SCRIPT
#!/usr/bin/env bash
echo "instalador-oficial-corrido \\\$*" >> "${UCI_MOCK_LOG}"
if [[ "${deja_binario}" == "yes" ]]; then
    mkdir -p "${UCI_MOCK_HOME}/SoapUI-5.99.0/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "${UCI_MOCK_HOME}/SoapUI-5.99.0/bin/soapui.sh"
    chmod +x "${UCI_MOCK_HOME}/SoapUI-5.99.0/bin/soapui.sh"
fi
exit 0
SCRIPT
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <instalado> [<api_fail>] [<deja_binario>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" instalado="$2" api_fail="${3:-no}" deja_binario="${4:-yes}"
    setup_mock_bin "${instalado}" "${api_fail}" "${deja_binario}"
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
echo "== 3. install: resuelve la URL, descarga y corre el instalador con -q =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*api.github.com/repos/SmartBear/soapui/releases/latest" "${UCI_MOCK_LOG}"; then
    pass "'install' consulta la API de GitHub Releases del repo oficial"
else
    fail "'install' no consultó la API esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "instalador-oficial-corrido -q" "${UCI_MOCK_LOG}"; then
    pass "'install' corre el instalador oficial descargado con el flag '-q'"
else
    fail "'install' no corrió el instalador con '-q'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ -x "${UCI_MOCK_HOME}/SoapUI-5.99.0/bin/soapui.sh" ]]; then
    pass "queda un binario resoluble en una ubicación típica tras 'install'"
else
    fail "no quedó un binario resoluble tras 'install'"
fi
teardown_mock_bin

echo ""
echo "== 4. install: un fallo real de la API de GitHub se propaga =="
run_installer "install" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de la API de GitHub se propaga como código distinto de cero"
else
    fail "un fallo de la API debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 5. install: si el instalador no deja un binario resoluble, se rechaza explícitamente =="
run_installer "install" "no" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"tests/manual"* ]]; then
    pass "'install' rechaza y sugiere validación manual si no queda un binario resoluble"
else
    fail "'install' debería rechazar y avisar si no queda un binario resoluble (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con el binario presente: INSTALLED =="
run_installer "status" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con el binario presente"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. install rechaza si ya parece estar instalado =="
run_installer "install" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"uninstall"* ]]; then
    pass "'install' rechaza y sugiere 'uninstall' si ya parece estar instalado"
else
    fail "'install' debería rechazar si ya parece estar instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. uninstall elimina el directorio de instalación detectado =="
run_installer "uninstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ ! -d "${UCI_MOCK_HOME}/SoapUI-5.10.0" ]]; then
    pass "'uninstall' elimina el directorio de instalación"
else
    fail "'uninstall' no eliminó el directorio esperado (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 9. uninstall sobre NOT_INSTALLED no falla =="
run_installer "uninstall" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sobre NOT_INSTALLED no falla"
else
    fail "'uninstall' sobre NOT_INSTALLED no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 10. update/repair se rechazan explícitamente (no implementados a propósito) =="
for verb in update repair; do
    run_installer "${verb}" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "'${verb}' se rechaza explícitamente"
    else
        fail "'${verb}' debería rechazarse"
    fi
    teardown_mock_bin
done

print_test_summary
exit_with_test_summary
