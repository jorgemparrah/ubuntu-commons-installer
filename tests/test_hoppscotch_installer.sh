#!/usr/bin/env bash
# tests/test_hoppscotch_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_hoppscotch.sh
# (Hito 31, ver docs/ROADMAP.md). Mecanismo deb-direct, pero con
# resolución sobre la LISTA de releases recientes (no solo
# 'releases/latest') — se confirmó en la investigación que el release
# más reciente del repo real a veces es un hotfix que solo publica el
# asset "SelfHost" (autohospedar el backend), sin el .deb de la app de
# escritorio. El mock de 'curl' simula exactamente ese escenario: el
# primer release de la lista (más reciente) solo trae el asset
# SelfHost, y el segundo sí trae el de escritorio — el instalador debe
# saltar el primero y resolver el segundo. No instala nada real:
# apt-get/apt/dpkg/sudo/curl se interceptan con comandos falsos en un
# PATH temporal.
#
# Uso:
#   bash tests/test_hoppscotch_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_hoppscotch.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="hoppscotch"
readonly UCI_FAKE_DESKTOP_DEB_URL="https://github.com/hoppscotch/releases/releases/download/v26.6.0-0/Hoppscotch_linux_x64.deb"

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
if [[ "\$1" == "--configure" ]]; then
    exit 0
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
    echo "${UCI_PKG_NAME}/noble 26.7.0-0 amd64 [upgradable from: 26.6.0-0]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    # 'curl' se usa SOLO para consultar la lista de releases (la descarga
    # real del .deb la hace 'deb_direct_download' vía 'wget', no 'curl' —
    # se mockean ambos por separado, mismo criterio que LocalSend). El
    # primer release (más reciente) SOLO trae el asset SelfHost; el
    # segundo trae el de escritorio (Hoppscotch_linux_x64.deb) — el
    # instalador debe encontrar el segundo, no fallar ni quedarse con el
    # primero.
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "${api_fail}" == "yes" ]]; then
    exit 1
fi
cat <<'JSON'
[
  {
    "tag_name": "v26.6.1-0",
    "assets": [
      {"name": "Hoppscotch_SelfHost_linux_x64.deb", "browser_download_url": "https://github.com/hoppscotch/releases/releases/download/v26.6.1-0/Hoppscotch_SelfHost_linux_x64.deb"}
    ]
  },
  {
    "tag_name": "v26.6.0-0",
    "assets": [
      {"name": "Hoppscotch_SelfHost_linux_x64.deb", "browser_download_url": "https://github.com/hoppscotch/releases/releases/download/v26.6.0-0/Hoppscotch_SelfHost_linux_x64.deb"},
      {"name": "Hoppscotch_linux_x64.deb", "browser_download_url": "${UCI_FAKE_DESKTOP_DEB_URL}"}
    ]
  }
]
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

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/hoppscotch-desktop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/hoppscotch-desktop"
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
echo "== 2. install: salta el release SelfHost-only y resuelve el .deb de escritorio del release anterior =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl.*api.github.com/repos/hoppscotch/releases/releases" "${UCI_MOCK_LOG}"; then
    pass "'install' consulta la lista de releases (no solo 'releases/latest')"
else
    fail "'install' no consultó la lista de releases esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -qF "wget -O hoppscotch.deb ${UCI_FAKE_DESKTOP_DEB_URL}" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga (vía wget) el .deb de escritorio del release que sí lo publica (no el SelfHost)"
else
    fail "'install' no descargó la URL de escritorio esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "apt-get install -y ./hoppscotch.deb" "${UCI_MOCK_LOG}"; then
    pass "'install' instala el .deb descargado vía apt-get"
else
    fail "'install' no instaló el paquete esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. install: un fallo real de la API de GitHub se propaga =="
run_installer "install" "missing" "no" "auto" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un fallo de la API de GitHub se propaga como código distinto de cero"
else
    fail "un fallo de la API debería propagarse como código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 4. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. status con dpkg 'ii' pero sin el binario 'hoppscotch-desktop' resoluble: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si 'hoppscotch-desktop' no resuelve"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. uninstall purga (no remove) =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' invoca 'apt-get purge' (no remove)"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 9. update invoca '--only-upgrade' =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 10. repair corre 'dpkg --configure -a' y reinstala =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
