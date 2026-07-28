#!/usr/bin/env bash
# tests/test_albert_installer.sh
#
# Prueba simulada (mocks) de scripts/productivity/install_albert.sh (Hito
# 51, ver docs/ROADMAP.md). No instala nada real:
# apt-get/apt/dpkg/sudo/gpg/curl/install/tee se interceptan con comandos
# falsos en un PATH temporal.
#
# Particularidad frente al resto de los instaladores apt-vendor-repo: en
# Albert la URL del REPOSITORIO depende de la versión de Ubuntu
# (`xUbuntu_24.04` / `xUbuntu_26.04` en openSUSE Build Service), no solo
# la línea 'deb' — así que el test simula /etc/os-release apuntando
# UCI_TEST_OS_RELEASE a un archivo temporal, para verificar que la URL se
# arma con el VERSION_ID correcto en las dos versiones soportadas, sin
# depender de la versión real de la máquina donde corre el test.
#
# Uso:
#   bash tests/test_albert_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/productivity/install_albert.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="albert"

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
if [[ "\$1" == "--print-architecture" ]]; then
    echo "amd64"
    exit 0
fi
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
    echo "${UCI_PKG_NAME}/noble 35.1.0 amd64 [upgradable from: 35.0.0]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    cat > "${UCI_MOCK_BIN}/gpg" <<EOF
#!/usr/bin/env bash
echo "gpg \$*" >> "${UCI_MOCK_LOG}"
cat > /dev/null
echo "clave-falsa-dearmored"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/gpg"

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
echo "clave-falsa-armored"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    cat > "${UCI_MOCK_BIN}/install" <<EOF
#!/usr/bin/env bash
echo "install \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/install"

    cat > "${UCI_MOCK_BIN}/tee" <<EOF
#!/usr/bin/env bash
echo "tee \$*" >> "${UCI_MOCK_LOG}"
cat >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/tee"

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/albert" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/albert"
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
echo "== 2. install: dearmora la clave y agrega el repo OBS =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "gpg --dearmor" "${UCI_MOCK_LOG}"; then
    pass "'install' convierte la clave a formato binario vía 'gpg --dearmor'"
else
    fail "'install' no invocó 'gpg --dearmor'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "curl .*download.opensuse.org/repositories/home:manuelschneid3r/xUbuntu_.*/Release.key" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga la clave del repositorio OBS del proyecto"
else
    fail "'install' no descargó la clave esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "install .*albert-manuelschneid3r.gpg" "${UCI_MOCK_LOG}"; then
    pass "'install' instala la clave dearmorada en su ruta final"
else
    fail "'install' no instaló la clave esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "tee /etc/apt/sources.list.d/albert.list" "${UCI_MOCK_LOG}"; then
    pass "'install' escribe la lista de repositorios de Albert"
else
    fail "'install' no escribió el repo esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "apt-get install -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'install' instala el paquete '${UCI_PKG_NAME}'"
else
    fail "'install' no instaló el paquete esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. la URL del repo se arma con el VERSION_ID real de la máquina =="
# A diferencia del resto de los apt-vendor-repo, acá la URL del REPO (no
# solo la línea 'deb') depende de la versión de Ubuntu. El mock de 'tee'
# vuelca el contenido escrito al log, así que se puede verificar la línea
# 'deb' completa contra el VERSION_ID real del entorno donde corre.
UCI_EXPECTED_VERSION_ID="$(. /etc/os-release && echo "${VERSION_ID}")"
run_installer "install" "missing"
if grep -q "xUbuntu_${UCI_EXPECTED_VERSION_ID}/" "${UCI_MOCK_LOG}"; then
    pass "la URL del repositorio usa xUbuntu_${UCI_EXPECTED_VERSION_ID} (VERSION_ID real, resuelto dinámicamente)"
else
    fail "la URL del repositorio no usó xUbuntu_${UCI_EXPECTED_VERSION_ID}. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -qE "deb \[arch=amd64 signed-by=/usr/share/keyrings/albert-manuelschneid3r\.gpg\] .*xUbuntu_.*/ /" "${UCI_MOCK_LOG}"; then
    pass "la línea 'deb' tiene el formato de repo plano de OBS (termina en ' /')"
else
    fail "la línea 'deb' no tuvo el formato esperado. Log: $(cat "${UCI_MOCK_LOG}")"
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
echo "== 5. status con dpkg 'ii' pero sin binario resoluble: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el binario 'albert' no resuelve"
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
echo "== 8. uninstall: purga el paquete y limpia repo/clave =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${UCI_PKG_NAME}" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga el paquete (no 'remove')"
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

echo ""
echo "== 11. reinstall usa 'apt-get install --reinstall' directo (sin purgar) =="
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
