#!/usr/bin/env bash
# tests/test_snap_installers_full_contract.sh
#
# Prueba simulada (mocks) del ciclo de vida completo de los instaladores
# Snap migrados en el Hito 11 (DBeaver, GitKraken, Insomnia, Postman,
# GIMP, OBS Studio, Spotify, Zoom) más Yazi (agregado después):
# install/uninstall/update/reinstall/repair sobre scripts/lib/snap.sh +
# scripts/lib/installer_cli.sh.
# Complementa, sin reemplazar, tests/test_snap_installers_contract.sh
# (I10, que ya cubría los 3 casos de 'status': instalado/no
# instalado/snapd ausente). No instala nada real ni requiere
# snapd/systemd — corre en cualquier máquina, incluida la de desarrollo.
#
# Uso:
#   bash tests/test_snap_installers_full_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <estado: installed|not_installed|snapd_absent> <pkg>
setup_mock_bin() {
    local state="$1" pkg="$2"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    if [[ "${state}" == "snapd_absent" ]]; then
        return 0
    fi

    cat > "${UCI_MOCK_BIN}/snap" <<EOF
#!/usr/bin/env bash
echo "snap \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" ]]; then
    echo "Name  Version  Rev  Tracking  Publisher  Notes"
    if [[ "${state}" == "installed" ]]; then
        echo "${pkg}  1.0  1  latest/stable  someone  classic"
    fi
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/snap"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <estado> <pkg>
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" state="$3" pkg="$4"
    setup_mock_bin "${state}" "${pkg}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:/usr/bin:/bin" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_snap_full_contract <script> <label> <pkg> <classic: yes|no>
test_snap_full_contract() {
    local script="${UCI_REPO_ROOT}/$1" label="$2" pkg="$3" classic="$4"

    echo ""
    echo "== ${label} (${script#"${UCI_REPO_ROOT}"/}) =="

    run_installer "${script}" "esto-no-existe" "not_installed" "${pkg}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then pass "${label}: comando desconocido sale con código distinto de cero"; else fail "${label}: comando desconocido debería fallar"; fi
    teardown_mock_bin

    run_installer "${script}" "install" "not_installed" "${pkg}"
    local expected_install="snap install ${pkg}"
    [[ "${classic}" == "yes" ]] && expected_install="snap install ${pkg} --classic"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -qF "${expected_install}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'install' invoca '${expected_install}'"
    else
        fail "${label}: 'install' no invocó lo esperado. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "installed" "${pkg}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -qF "snap remove ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'uninstall' invoca 'snap remove ${pkg}'"
    else
        fail "${label}: 'uninstall' no invocó lo esperado. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "installed" "${pkg}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -qF "snap refresh ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'update' invoca 'snap refresh ${pkg}'"
    else
        fail "${label}: 'update' no invocó lo esperado. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "reinstall" "installed" "${pkg}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -qF "snap remove ${pkg}" "${UCI_MOCK_LOG}" && grep -qF "${expected_install}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'reinstall' usa el fallback mecánico (remove + install)"
    else
        fail "${label}: 'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "installed" "${pkg}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: 'repair' se rechaza explícitamente (no implementado a propósito)"
    else
        fail "${label}: 'repair' debería rechazarse con código distinto de cero"
    fi
    teardown_mock_bin
}

test_snap_full_contract "scripts/development/install_dbeaver.sh" "DBeaver" "dbeaver-ce" "yes"
test_snap_full_contract "scripts/development/install_gitkraken.sh" "GitKraken" "gitkraken" "yes"
test_snap_full_contract "scripts/development/install_insomnia.sh" "Insomnia" "insomnia" "yes"
test_snap_full_contract "scripts/development/install_postman.sh" "Postman" "postman" "yes"
test_snap_full_contract "scripts/system/install_gimp.sh" "GIMP" "gimp" "yes"
test_snap_full_contract "scripts/system/install_obs_studio.sh" "OBS Studio" "obs-studio" "yes"
test_snap_full_contract "scripts/productivity/install_spotify.sh" "Spotify" "spotify" "yes"
test_snap_full_contract "scripts/productivity/install_zoom.sh" "Zoom" "zoom-client" "no"
test_snap_full_contract "scripts/system/install_yazi.sh" "Yazi" "yazi" "yes"

print_test_summary
exit_with_test_summary
