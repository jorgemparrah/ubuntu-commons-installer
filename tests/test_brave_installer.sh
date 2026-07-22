#!/usr/bin/env bash
# tests/test_brave_installer.sh
#
# Prueba simulada (mocks) de scripts/productivity/install_brave.sh (Hito
# 27, ver docs/ROADMAP.md). Primer instalador que usa
# apt_vendor_repo_fetch_file_plain (scripts/lib/apt_vendor_repo.sh):
# Brave publica su clave ya lista para 'signed-by' (sin 'gpg --dearmor')
# y un archivo `.sources` completo en formato DEB822 — ambos se
# descargan a un temporal y se instalan de forma atómica con
# 'sudo install -D' (mismo patrón en dos pasos que
# apt_vendor_repo_fetch_key_dearmored), sin `apt_vendor_repo_write_list`.
# No instala nada real: apt-get/apt/dpkg/sudo/curl/install se interceptan
# con comandos falsos en un PATH temporal. 'install' se mockea
# explícitamente (mismo criterio que tests/test_virtualbox_installer.sh):
# sin mockearlo, 'sudo install -D' invocaría el binario real del sistema
# contra una ruta real y fallaría por permisos en un contenedor no-root
# de CI.
#
# Uso:
#   bash tests/test_brave_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/productivity/install_brave.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="brave-browser"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|missing> [<upgradable: yes|no>] [<binary: auto|yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" binary="${3:-auto}"
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
    echo "${UCI_PKG_NAME}/noble 1.70-1 amd64 [upgradable from: 1.69-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    # apt_vendor_repo_fetch_file_plain (sin gpg/dearmor, a diferencia de
    # Slack/OnlyOffice) descarga con 'curl -fsSL <url> -o <temporal>' —
    # el destino de 'curl' acá siempre es un archivo temporal real
    # (mktemp, sin mockear), nunca la ruta final del sistema — y recién
    # instala ese temporal en la ruta final vía 'sudo install -D', que sí
    # se mockea (ver más abajo), mismo criterio que
    # tests/test_virtualbox_installer.sh: nunca dejar que un mock escriba
    # de verdad contra una ruta real del sistema en un contenedor no-root.
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
# El destino viene tras '-o'; escribimos contenido falso ahí (siempre un
# temporal real, ver nota arriba).
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then
        echo "contenido-falso" > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    cat > "${UCI_MOCK_BIN}/install" <<EOF
#!/usr/bin/env bash
echo "install \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/install"

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/brave-browser" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/brave-browser"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <dpkg_state> [<upgradable>] [<binary>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" binary="${4:-auto}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${binary}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
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
echo "== 2. install: descarga clave y .sources directo, sin gpg/dearmor =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga la clave oficial de Brave directo (sin gpg/dearmor)"
else
    fail "'install' no descargó la clave esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-browser.sources" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga el archivo .sources oficial directo (sin construir una línea 'deb [...]')"
else
    fail "'install' no descargó el archivo .sources esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
# '-w "gpg"' a secas daría un falso positivo: la URL de la clave termina
# en '...keyring.gpg', y "gpg" ahí ya cuenta como palabra completa
# delimitada por '.' (bug real encontrado en la primera corrida de CI de
# este test). Se busca en cambio una línea de log que arranque con el
# comando 'gpg' de verdad (mismo formato "comando \$*" que loguean todos
# los mocks de este archivo).
if grep -q "^gpg " "${UCI_MOCK_LOG}"; then
    fail "'install' no debería invocar 'gpg' (la clave de Brave ya viene lista)"
else
    pass "'install' no invoca 'gpg' (mecanismo distinto a Slack/OnlyOffice)"
fi
if grep -q "install .*brave-browser-archive-keyring.gpg" "${UCI_MOCK_LOG}"; then
    pass "'install' instala la clave descargada en su ruta final vía 'install -D' (nunca escribe el destino real directo con curl)"
else
    fail "'install' no instaló la clave en la ruta final esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "install .*brave-browser-release.sources" "${UCI_MOCK_LOG}"; then
    pass "'install' instala el archivo .sources en su ruta final vía 'install -D'"
else
    fail "'install' no instaló el archivo .sources en la ruta final esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'install' instala el paquete '${UCI_PKG_NAME}'"
else
    fail "'install' no instaló el paquete esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. status con dpkg 'ii' pero sin binario resoluble: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el binario 'brave-browser' no resuelve"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. uninstall: purga el paquete y limpia repo/clave =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga el paquete (no 'remove')"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 8. update invoca '--only-upgrade' =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 9. repair corre 'dpkg --configure -a' y reinstala =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala el paquete"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 10. reinstall usa 'apt-get install --reinstall' directo (sin purgar) =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' invoca 'apt-get install --reinstall'"
else
    fail "'reinstall' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "purge" "${UCI_MOCK_LOG}"; then
    fail "'reinstall' no debería pasar por 'purge'"
else
    pass "'reinstall' evita el ciclo completo de purge+autoremove"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
