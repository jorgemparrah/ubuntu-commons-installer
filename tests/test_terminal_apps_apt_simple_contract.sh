#!/usr/bin/env bash
# tests/test_terminal_apps_apt_simple_contract.sh
#
# Prueba simulada (mocks) del ciclo de vida completo de instaladores
# apt-simple agregados al catálogo después del piloto (nnn, lf; fzf,
# thefuck, jq del Hito 28; Okular del Hito 29; Podman, Lazygit del Hito
# 33; HTTPie del Hito 38; duf, btop, zoxide, tealdeer del Hito 39; Kitty,
# Alacritty del Hito 40; ImageMagick, FFmpeg del Hito 43; FileZilla del
# Hito 44; ripgrep, fd, bat, tree, rsync del Hito 45; WireGuard, OpenVPN
# del Hito 46): todos están en los repositorios oficiales de Ubuntu,
# mismo patrón que
# scripts/system/install_ranger.sh. No instala
# nada real: apt-get/apt/dpkg/sudo se interceptan con comandos falsos en
# un PATH temporal.
#
# Uso:
#   bash tests/test_terminal_apps_apt_simple_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|rc|missing> [<upgradable: yes|no>] [<fail_apt_get: yes|no>] [<binary: auto|yes|no>] <pkg> <binary_name>
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" fail_apt_get="${3:-no}" binary="${4:-auto}" pkg="$5" binary_name="$6"
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
    echo "${pkg}/noble 2.0-1 amd64 [upgradable from: 1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
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

# run_installer <script> <accion> <pkg> <binary_name> <dpkg_state> [<upgradable>] [<fail_apt_get>] [<binary>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" pkg="$3" binary_name="$4" dpkg_state="$5" upgradable="${6:-no}" fail_apt_get="${7:-no}" binary="${8:-auto}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${fail_apt_get}" "${binary}" "${pkg}" "${binary_name}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_apt_simple_contract <script> <label> <pkg> <binary_name>
test_apt_simple_contract() {
    local script="${UCI_REPO_ROOT}/$1" label="$2" pkg="$3" binary_name="$4"

    echo ""
    echo "== ${label} (${script#"${UCI_REPO_ROOT}"/}) =="

    run_installer "${script}" "esto-no-existe" "${pkg}" "${binary_name}" "missing"
    if [[ "${RUN_CODE}" -ne 0 ]]; then pass "${label}: comando desconocido sale con código distinto de cero"; else fail "${label}: comando desconocido debería fallar"; fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "${binary_name}" "missing"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${label}: estado inicial reporta NOT_INSTALLED"
    else
        fail "${label}: estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "${pkg}" "${binary_name}" "missing"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'install' invoca 'apt-get install -y ${pkg}'"
    else
        fail "${label}: 'install' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "${binary_name}" "ii"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "${label}: 'status' reporta INSTALLED"
    else
        fail "${label}: 'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "${pkg}" "${binary_name}" "ii" "yes"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'update' invoca '--only-upgrade'"
    else
        fail "${label}: 'update' no se comportó como se esperaba (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "${pkg}" "${binary_name}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'repair' corre 'dpkg --configure -a' y reinstala"
    else
        fail "${label}: 'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "${pkg}" "${binary_name}" "missing"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"install"* ]]; then
        pass "${label}: 'repair' sobre NOT_INSTALLED rechaza y sugiere 'install'"
    else
        fail "${label}: 'repair' sobre NOT_INSTALLED no se comportó como se esperaba. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "reinstall" "${pkg}" "${binary_name}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y ${pkg}" "${UCI_MOCK_LOG}" && ! grep -q "purge" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'reinstall' usa --reinstall directo, sin pasar por purge"
    else
        fail "${label}: 'reinstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "${pkg}" "${binary_name}" "ii"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y ${pkg}" "${UCI_MOCK_LOG}"; then
        pass "${label}: 'uninstall' invoca 'apt-get purge' (no remove)"
    else
        fail "${label}: 'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "${pkg}" "${binary_name}" "missing" "no" "yes"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${label}: un fallo real de apt-get se propaga"
    else
        fail "${label}: un fallo de apt-get debería propagarse como código distinto de cero"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "${binary_name}" "rc"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${label}: estado residual 'rc' se reporta como NOT_INSTALLED"
    else
        fail "${label}: estado residual 'rc' no se manejó correctamente. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "${pkg}" "${binary_name}" "ii" "no" "no" "no"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "${label}: dpkg 'ii' sin binario resoluble reporta BROKEN"
    else
        fail "${label}: no reportó BROKEN con dpkg 'ii' y binario ausente. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin
}

test_apt_simple_contract "scripts/system/install_nnn.sh" "nnn" "nnn" "nnn"
test_apt_simple_contract "scripts/system/install_lf.sh" "lf" "lf" "lf"
test_apt_simple_contract "scripts/system/install_fzf.sh" "fzf" "fzf" "fzf"
test_apt_simple_contract "scripts/system/install_thefuck.sh" "thefuck" "thefuck" "thefuck"
test_apt_simple_contract "scripts/system/install_jq.sh" "jq" "jq" "jq"
test_apt_simple_contract "scripts/productivity/install_okular.sh" "Okular" "okular" "okular"
test_apt_simple_contract "scripts/development/install_podman.sh" "Podman" "podman" "podman"
test_apt_simple_contract "scripts/development/install_lazygit.sh" "Lazygit" "lazygit" "lazygit"
test_apt_simple_contract "scripts/system/install_httpie.sh" "HTTPie" "httpie" "httpie"
test_apt_simple_contract "scripts/system/install_kitty.sh" "Kitty" "kitty" "kitty"
test_apt_simple_contract "scripts/system/install_alacritty.sh" "Alacritty" "alacritty" "alacritty"
test_apt_simple_contract "scripts/system/install_duf.sh" "duf" "duf" "duf"
test_apt_simple_contract "scripts/system/install_btop.sh" "btop" "btop" "btop"
test_apt_simple_contract "scripts/system/install_zoxide.sh" "zoxide" "zoxide" "zoxide"
test_apt_simple_contract "scripts/system/install_tealdeer.sh" "tealdeer" "tealdeer" "tldr"
test_apt_simple_contract "scripts/editors/install_neovim.sh" "Neovim" "neovim" "nvim"
test_apt_simple_contract "scripts/system/install_imagemagick.sh" "ImageMagick" "imagemagick" "convert"
test_apt_simple_contract "scripts/system/install_ffmpeg.sh" "FFmpeg" "ffmpeg" "ffmpeg"
test_apt_simple_contract "scripts/productivity/install_filezilla.sh" "FileZilla" "filezilla" "filezilla"
test_apt_simple_contract "scripts/system/install_ripgrep.sh" "ripgrep" "ripgrep" "rg"
test_apt_simple_contract "scripts/system/install_fd.sh" "fd" "fd-find" "fdfind"
test_apt_simple_contract "scripts/system/install_bat.sh" "bat" "bat" "batcat"
test_apt_simple_contract "scripts/system/install_tree.sh" "tree" "tree" "tree"
test_apt_simple_contract "scripts/system/install_rsync.sh" "rsync" "rsync" "rsync"
test_apt_simple_contract "scripts/system/install_wireguard.sh" "WireGuard" "wireguard" "wg"
test_apt_simple_contract "scripts/system/install_openvpn.sh" "OpenVPN" "openvpn" "openvpn"

print_test_summary
exit_with_test_summary
