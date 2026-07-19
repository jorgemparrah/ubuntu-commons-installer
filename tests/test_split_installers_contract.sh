#!/usr/bin/env bash
# tests/test_split_installers_contract.sh
#
# Prueba simulada (mocks) de los 14 instaladores individuales creados al
# separar los 3 instaladores multi-paquete (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md).
# Todos siguen el mismo patrón que scripts/system/install_ranger.sh (Hito
# 11, Fase 2), así que se prueban con la misma batería de escenarios en un
# solo archivo, en vez de duplicar tests/test_ranger_installer.sh 14 veces.
# No instala nada real: apt-get/apt/dpkg/sudo se interceptan con comandos
# falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_split_installers_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
UCI_SYSTEM_DIR="${UCI_REPO_ROOT}/scripts/system"
readonly UCI_SYSTEM_DIR

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|rc|missing> <pkg_name> [<upgradable: yes|no>] [<fail_apt_get: yes|no>] [<binary_name_or_none>]
setup_mock_bin() {
    local dpkg_state="$1" pkg_name="$2" upgradable="${3:-no}" fail_apt_get="${4:-no}" binary_name="${5:-}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    case "${dpkg_state}" in
        ii) echo "ii  \$2  1.0  amd64  paquete de prueba"; exit 0 ;;
        rc) echo "rc  \$2  1.0  amd64  paquete de prueba"; exit 0 ;;
        *) echo "dpkg-query: no packages found matching \$2" >&2; exit 1 ;;
    esac
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"

    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${UCI_MOCK_LOG}"
if [[ "${fail_apt_get}" == "yes" ]]; then
    exit 1
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" ]]; then
    echo "${pkg_name}/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
# sudo real soporta 'sudo VAR=val comando' (asignaciones de entorno antes
# del comando, ver install_ubuntu_restricted_extras.sh:
# DEBIAN_FRONTEND=noninteractive) — se emula despojando esos pares
# NAME=value y exportándolos antes de ejecutar el resto.
while [[ "$#" -gt 0 && "$1" == *=* && "$1" != -* ]]; do
    export "$1"
    shift
done
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    if [[ -n "${binary_name}" && "${dpkg_state}" == "ii" ]]; then
        cat > "${UCI_MOCK_BIN}/${binary_name}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${binary_name}"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <pkg_name> <dpkg_state> [<upgradable>] [<fail_apt_get>] [<binary_name_or_none>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" pkg_name="$3" dpkg_state="$4" upgradable="${5:-no}" fail_apt_get="${6:-no}" binary_name="${7:-}"
    setup_mock_bin "${dpkg_state}" "${pkg_name}" "${upgradable}" "${fail_apt_get}" "${binary_name}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_full_contract <script> <label> <pkg_name> <binary_name_or_none>
# binary_name vacío ("") significa "paquete meta sin binario propio": el
# instalador no intenta detectar BROKEN vía 'command -v' (ver ADR 0031), así
# que los escenarios de reparación se prueban igual (repair_tool no depende
# de un BROKEN previo, solo de que el paquete esté instalado).
test_full_contract() {
    local script="$1" label="$2" pkg="$3" binary="$4"

    echo ""
    echo "== ${label} (${script}) =="

    run_installer "${script}" "esto-no-existe" "${pkg}" "missing"
    if [[ "${RUN_CODE}" -ne 0 ]]; then pass "${label}: comando desconocido sale con código distinto de cero"; else fail "${label}: comando desconocido debería fallar"; fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "missing"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${label}: estado inicial reporta NOT_INSTALLED"
    else
        fail "${label}: estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "${pkg}" "missing"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'install' invoca 'apt-get install -y ${pkg}'"
    else
        fail "${label}: 'install' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "ii" "no" "no" "${binary}"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "${label}: 'status' reporta INSTALLED"
    else
        fail "${label}: 'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "${pkg}" "ii" "yes" "no" "${binary}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'update' invoca '--only-upgrade'"
    else
        fail "${label}: 'update' no se comportó como se esperaba (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "${pkg}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'repair' corre 'dpkg --configure -a' y reinstala"
    else
        fail "${label}: 'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "${pkg}" "missing"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"install"* ]]; then
        pass "${label}: 'repair' sobre NOT_INSTALLED rechaza y sugiere 'install'"
    else
        fail "${label}: 'repair' sobre NOT_INSTALLED no se comportó como se esperaba. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "reinstall" "${pkg}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y ${pkg}" "${UCI_MOCK_LOG}" && ! grep -q "purge" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'reinstall' usa --reinstall directo, sin pasar por purge"
    else
        fail "${label}: 'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "${pkg}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'uninstall' invoca 'apt-get purge' (no remove)"
    else
        fail "${label}: 'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "${pkg}" "missing" "no" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: un fallo real de apt-get se propaga"
    else
        fail "${label}: un fallo de apt-get debería propagarse como código distinto de cero"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "rc"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${label}: estado residual 'rc' se reporta como NOT_INSTALLED"
    else
        fail "${label}: estado residual 'rc' no se manejó correctamente. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    if [[ -n "${binary}" ]]; then
        run_installer "${script}" "status" "${pkg}" "ii" "no" "no" ""
        if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
            pass "${label}: dpkg 'ii' sin binario resoluble reporta BROKEN"
        else
            fail "${label}: no reportó BROKEN con dpkg 'ii' y binario ausente. Salida: ${RUN_OUTPUT}"
        fi
        teardown_mock_bin
    else
        echo "  (omitido: ${label} es un paquete meta sin binario propio, BROKEN no aplica — ver ADR 0031)"
    fi
}

# script|label|paquete|binario (vacío = paquete meta sin binario propio)
UCI_ENTRIES=(
    "install_wget.sh|wget|wget|wget"
    "install_curl.sh|curl|curl|curl"
    "install_git.sh|Git|git|git"
    "install_build_essential.sh|build-essential|build-essential|"
    "install_software_properties_common.sh|software-properties-common|software-properties-common|add-apt-repository"
    "install_apt_transport_https.sh|apt-transport-https|apt-transport-https|"
    "install_gnupg2.sh|GnuPG|gnupg2|gpg"
    "install_cheese.sh|Cheese|cheese|cheese"
    "install_v4l_utils.sh|v4l-utils|v4l-utils|v4l2-ctl"
    "install_ubuntu_restricted_extras.sh|ubuntu-restricted-extras|ubuntu-restricted-extras|"
    "install_vlc.sh|VLC|vlc|vlc"
    "install_meld.sh|Meld|meld|meld"
    "install_baobab.sh|Baobab|baobab|baobab"
    "install_gparted.sh|GParted|gparted|gparted"
)

for entry in "${UCI_ENTRIES[@]}"; do
    IFS='|' read -r script_name label pkg binary <<< "${entry}"
    test_full_contract "${UCI_SYSTEM_DIR}/${script_name}" "${label}" "${pkg}" "${binary}"
done

print_test_summary
exit_with_test_summary
