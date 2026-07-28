#!/usr/bin/env bash
# tests/test_orca_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_orca.sh
# (Hito 55, ver docs/ROADMAP.md). Mecanismo deb-direct con la URL
# resuelta dinámicamente contra la API de GitHub Releases
# (scripts/lib/github_release.sh), mismo patrón que LocalSend/DbGate. No
# instala nada real: apt-get/apt/dpkg/sudo/curl/wget se interceptan con
# comandos falsos en un PATH temporal; 'curl' devuelve un JSON de release
# falso y 'wget' escribe contenido falso en el destino.
#
# Además de los criterios comunes del mecanismo, cubre dos riesgos
# propios de Orca, ambos verificados en vivo contra el `.deb` real:
#
#   1. El release publica varios assets (amd64/arm64, .deb y .rpm). El
#      JSON falso los incluye TODOS para comprobar que el patrón elige el
#      `.deb` amd64 y no un arm64 ni un .rpm.
#   2. Ubuntu ya tiene un paquete llamado `orca` (el lector de pantalla
#      de GNOME). Este instalador gestiona `orca-ide`, y ninguna acción
#      debe tocar `orca` a secas — se verifica explícitamente en
#      'uninstall', que es donde un error así sería destructivo sobre
#      software de accesibilidad.
#
# Uso:
#   bash tests/test_orca_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_orca.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="orca-ide"
readonly UCI_BIN_NAME="orca-ide"
readonly UCI_FAKE_VERSION="1.99.0"
readonly UCI_FAKE_BASE="https://github.com/stablyai/orca/releases/download/v${UCI_FAKE_VERSION}"
readonly UCI_FAKE_DEB_URL="${UCI_FAKE_BASE}/orca-ide_${UCI_FAKE_VERSION}_amd64.deb"
readonly UCI_FAKE_ARM_DEB_URL="${UCI_FAKE_BASE}/orca-ide_${UCI_FAKE_VERSION}_arm64.deb"
readonly UCI_FAKE_RPM_URL="${UCI_FAKE_BASE}/orca-ide-${UCI_FAKE_VERSION}.x86_64.rpm"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|missing> [<upgradable: yes|no>] [<binary: auto|yes|no>] [<api_fail: yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" binary="${3:-auto}" api_fail="${4:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "ii" ]]; then
        echo "ii  ${UCI_PKG_NAME}  1.0  amd64  paquete de prueba"
        exit 0
    fi
    exit 1
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"

    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" ]]; then
    echo "${UCI_PKG_NAME}/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
while [[ "$#" -gt 0 && "$1" == *=* && "$1" != -* ]]; do
    export "$1"
    shift
done
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    # El JSON falso lista los assets en un orden que pondría primero un
    # arm64 y un .rpm: si el patrón del instalador estuviera mal, elegiría
    # uno de esos.
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "${api_fail}" == "yes" ]]; then
    exit 1
fi
cat <<'JSON'
{
  "tag_name": "v${UCI_FAKE_VERSION}",
  "assets": [
    {"browser_download_url": "${UCI_FAKE_RPM_URL}"},
    {"browser_download_url": "${UCI_FAKE_ARM_DEB_URL}"},
    {"browser_download_url": "${UCI_FAKE_DEB_URL}"}
  ]
}
JSON
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    cat > "${UCI_MOCK_BIN}/wget" <<EOF
#!/usr/bin/env bash
echo "wget \$*" >> "${UCI_MOCK_LOG}"
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-O" ]]; then
        echo "contenido-falso-deb" > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/wget"

    # El binario del PATH lo crea el postinst del paquete real, no el
    # .deb: se simula aparte del estado de dpkg justo para poder producir
    # el estado BROKEN (paquete instalado, symlink ausente).
    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/${UCI_BIN_NAME}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${UCI_BIN_NAME}"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <dpkg_state> [<upgradable>] [<binary>] [<api_fail>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" binary="${4:-auto}" api_fail="${5:-no}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${binary}" "${api_fail}"
    set +e
    RUN_OUTPUT="$(cd "${UCI_MOCK_BIN}" && PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. install: resuelve la URL vía la API de GitHub y descarga/instala el .deb =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*api.github.com/repos/stablyai/orca/releases/latest" "${UCI_MOCK_LOG}"; then
    pass "'install' consulta la API de GitHub Releases del repo oficial"
else
    fail "'install' no consultó la API esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "apt-get install -y ./orca-ide.deb" "${UCI_MOCK_LOG}"; then
    pass "'install' instala el .deb descargado vía apt-get"
else
    fail "'install' no instaló el paquete esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. install: elige el asset amd64, no el arm64 ni el .rpm =="
run_installer "install" "missing"
if grep -q "wget.*${UCI_FAKE_DEB_URL}" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga el .deb amd64 resuelto dinámicamente"
else
    fail "'install' no descargó el .deb amd64 esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "wget.*arm64" "${UCI_MOCK_LOG}"; then
    fail "'install' descargó el asset arm64: el patrón del asset no discrimina la arquitectura"
else
    pass "'install' no descarga el asset arm64"
fi
if grep -q "wget.*\.rpm" "${UCI_MOCK_LOG}"; then
    fail "'install' descargó un .rpm: el patrón del asset no discrimina el formato"
else
    pass "'install' no descarga el asset .rpm"
fi
teardown_mock_bin

echo ""
echo "== 4. install: un fallo real de la API de GitHub se propaga =="
run_installer "install" "missing" "no" "auto" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de la API de GitHub se propaga como código distinto de cero"
else
    fail "un fallo de la API debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 5. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con dpkg 'ii' pero sin el symlink del postinst: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el binario del PATH no resuelve"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 9. uninstall purga 'orca-ide' y NO toca el paquete 'orca' de GNOME =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' invoca 'apt-get purge' sobre ${UCI_PKG_NAME} (no remove)"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
# El lector de pantalla de GNOME se llama 'orca' a secas y existe en los
# repos de Ubuntu: purgarlo por accidente rompería accesibilidad.
if grep -qE "(purge|remove).*[[:space:]]orca([[:space:]]|$)" "${UCI_MOCK_LOG}"; then
    fail "'uninstall' tocó el paquete 'orca' (lector de pantalla de GNOME). Log: $(cat "${UCI_MOCK_LOG}")"
else
    pass "'uninstall' no toca el paquete 'orca' de GNOME"
fi
teardown_mock_bin

echo ""
echo "== 10. update invoca '--only-upgrade' =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 11. repair corre 'dpkg --configure -a' y reinstala (vuelve a correr el postinst) =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 12. repair rechaza si el paquete no está instalado =="
run_installer "repair" "missing"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"install"* ]]; then
    pass "'repair' rechaza y sugiere 'install' si el paquete no está instalado"
else
    fail "'repair' debería rechazar si el paquete no está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
