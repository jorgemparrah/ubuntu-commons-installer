#!/usr/bin/env bash
# tests/test_deb_direct_full_contract.sh
#
# Prueba simulada (mocks) del ciclo de vida completo de los instaladores
# deb-directo migrados en el Hito 11 (Google Chrome, MongoDB Compass) más
# Discord (Hito 25, agregado después):
# install/uninstall/update/reinstall/repair sobre scripts/lib/apt.sh +
# scripts/lib/deb_direct.sh + scripts/lib/installer_cli.sh. Complementa,
# sin reemplazar, tests/test_chrome_arch_check.sh (I09, ya cubre la
# verificación de arquitectura) y tests/test_mongodb_compass_download.sh
# (I07, ya cubre los fallos de descarga/instalación del .deb). No instala
# nada real: dpkg/apt-get/wget/sudo se interceptan con comandos falsos en
# un PATH temporal.
#
# Uso:
#   bash tests/test_deb_direct_full_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_MOCK_WORKDIR=""

# setup_mock_bin <dpkg_state: ii|missing> <pkg> <binary> <deb_name> [<upgradable: yes|no>] [<binary_presente: yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" pkg="$2" binary="$3" deb_name="$4" upgradable="${5:-no}" binary_presente="${6:-auto}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_MOCK_WORKDIR="$(mktemp -d)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "ii" ]]; then
        echo "ii  ${pkg}  1.0  amd64  paquete de prueba"
        exit 0
    else
        exit 1
    fi
fi
if [[ "\$1" == "--print-architecture" ]]; then
    echo "amd64"
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
    echo "${pkg}/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/wget" <<EOF
#!/usr/bin/env bash
echo "wget \$*" >> "${UCI_MOCK_LOG}"
for arg in "\$@"; do
    if [[ "\$arg" == *.deb && "\$arg" != http* ]]; then
        echo "contenido falso de .deb" > "\$arg"
    fi
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/wget"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    local create_binary="no"
    if [[ "${binary_presente}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary_presente}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/${binary}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${binary}"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_WORKDIR}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <dpkg_state> <pkg> <binary> <deb_name> [<upgradable>] [<binary_presente>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" dpkg_state="$3" pkg="$4" binary="$5" deb_name="$6" upgradable="${7:-no}" binary_presente="${8:-auto}"
    setup_mock_bin "${dpkg_state}" "${pkg}" "${binary}" "${deb_name}" "${upgradable}" "${binary_presente}"
    set +e
    RUN_OUTPUT="$(cd "${UCI_MOCK_WORKDIR}" && PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_deb_direct_full_contract <script> <label> <pkg> <binary> <deb_name>
test_deb_direct_full_contract() {
    local script="${UCI_REPO_ROOT}/$1" label="$2" pkg="$3" binary="$4" deb_name="$5"

    echo ""
    echo "== ${label} (${script#"${UCI_REPO_ROOT}"/}) =="

    run_installer "${script}" "install" "missing" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "wget" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ./${deb_name}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'install' descarga el .deb y lo instala vía apt-get"
    else
        fail "${label}: 'install' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "ii" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* ]]; then
        pass "${label}: 'status' reporta INSTALLED"
    else
        fail "${label}: 'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "ii" "${pkg}" "${binary}" "${deb_name}" "no" "no"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "${label}: dpkg 'ii' sin binario resoluble reporta BROKEN"
    else
        fail "${label}: no reportó BROKEN con dpkg 'ii' y binario ausente. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "ii" "${pkg}" "${binary}" "${deb_name}" "yes"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'update' invoca '--only-upgrade'"
    else
        fail "${label}: 'update' no se comportó como se esperaba (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "ii" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'repair' corre 'dpkg --configure -a' y reinstala"
    else
        fail "${label}: 'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "missing" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"install"* ]]; then
        pass "${label}: 'repair' sobre NOT_INSTALLED rechaza y sugiere 'install'"
    else
        fail "${label}: 'repair' sobre NOT_INSTALLED no se comportó como se esperaba. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "reinstall" "ii" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${pkg}" "${UCI_MOCK_LOG}" && grep -q "apt-get install -y ./${deb_name}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'reinstall' usa el fallback mecánico del dispatcher (purge + descargar e instalar de nuevo)"
    else
        fail "${label}: 'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "ii" "${pkg}" "${binary}" "${deb_name}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'uninstall' invoca 'apt-get purge' (no remove)"
    else
        fail "${label}: 'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin
}

test_deb_direct_full_contract "scripts/productivity/install_chrome.sh" "Google Chrome" "google-chrome-stable" "google-chrome" "google-chrome-stable_current_amd64.deb"
test_deb_direct_full_contract "scripts/development/install_mongodb_compass.sh" "MongoDB Compass" "mongodb-compass" "mongodb-compass" "mongodb-compass_1.46.8_amd64.deb"
test_deb_direct_full_contract "scripts/productivity/install_discord.sh" "Discord" "discord" "discord" "discord.deb"

print_test_summary
exit_with_test_summary
