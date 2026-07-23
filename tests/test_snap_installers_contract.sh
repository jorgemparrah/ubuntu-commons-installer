#!/usr/bin/env bash
# tests/test_snap_installers_contract.sh
#
# Prueba simulada (Hito 9, Fase B; Yazi, Telegram Desktop, Obsidian,
# Chromium y yq agregados después, OBS Studio retirado en ADR 0038 al
# migrar a su PPA oficial) de los 12 instaladores basados en Snap
# (DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi,
# Telegram Desktop, Obsidian, Chromium, yq): confirma que 'status'
# distingue correctamente tres casos —
# snap instalado, snap no instalado, snapd ausente (UNKNOWN) — donde
# antes los dos últimos se reportaban igual como NOT_INSTALLED (hallazgo
# de docs/UBUNTU_COMPATIBILITY.md). No instala nada real: el comando
# 'snap' se intercepta con un mock en un PATH temporal. No requiere
# snapd/systemd — corre en cualquier máquina, incluida la de desarrollo.
#
# Uso:
#   bash tests/test_snap_installers_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
UCI_MOCK_BIN=""

# setup_mock_bin_installed <snap_package>
# Simula snapd presente y el paquete instalado.
setup_mock_bin_installed() {
    local pkg="$1"
    UCI_MOCK_BIN="$(mktemp -d)"
    cat > "${UCI_MOCK_BIN}/snap" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "list" ]]; then
    echo "Name  Version  Rev  Tracking  Publisher  Notes"
    echo "${pkg}  1.0  1  latest/stable  someone  classic"
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/snap"
}

# setup_mock_bin_not_installed
# Simula snapd presente, pero ningún paquete instalado.
setup_mock_bin_not_installed() {
    UCI_MOCK_BIN="$(mktemp -d)"
    cat > "${UCI_MOCK_BIN}/snap" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
    echo "Name  Version  Rev  Tracking  Publisher  Notes"
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/snap"
}

# setup_mock_bin_snapd_absent
# Simula una máquina sin snapd: el comando 'snap' ni siquiera existe (no
# se crea nada en el PATH temporal).
setup_mock_bin_snapd_absent() {
    UCI_MOCK_BIN="$(mktemp -d)"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
}

# run_status <script>
# Devuelve la salida por RUN_OUTPUT y el código por RUN_CODE, corriendo
# 'status' con un PATH restringido al mock (sin heredar el snap real del
# host, si lo hubiera) más lo esencial para que bash/coreutils funcionen.
RUN_OUTPUT=""
RUN_CODE=0
run_status() {
    local script="$1"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:/usr/bin:/bin" bash "${script}" status 2>&1)"
    RUN_CODE=$?
    set -e
}

test_installer() {
    local script="${UCI_REPO_ROOT}/$1" name="$2"

    echo ""
    echo "== ${name} (${script#"${UCI_REPO_ROOT}"/}) =="

    setup_mock_bin_installed "$3"
    run_status "${script}"
    if [[ "${RUN_OUTPUT}" == "INSTALLED" && "${RUN_CODE}" -eq 0 ]]; then
        pass "${name}: snap instalado -> INSTALLED, código 0"
    else
        fail "${name}: snap instalado debería dar INSTALLED/código 0. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    setup_mock_bin_not_installed
    run_status "${script}"
    if [[ "${RUN_OUTPUT}" == "NOT_INSTALLED" && "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: snapd presente pero paquete no instalado -> NOT_INSTALLED"
    else
        fail "${name}: snap no instalado debería dar NOT_INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    setup_mock_bin_snapd_absent
    run_status "${script}"
    if [[ "${RUN_OUTPUT}" == "UNKNOWN" && "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: snapd ausente -> UNKNOWN (no se confunde con NOT_INSTALLED)"
    else
        fail "${name}: snapd ausente debería dar UNKNOWN. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin
}

test_installer "scripts/development/install_dbeaver.sh" "DBeaver" "dbeaver-ce"
test_installer "scripts/development/install_gitkraken.sh" "GitKraken" "gitkraken"
test_installer "scripts/development/install_insomnia.sh" "Insomnia" "insomnia"
test_installer "scripts/development/install_postman.sh" "Postman" "postman"
test_installer "scripts/system/install_gimp.sh" "GIMP" "gimp"
test_installer "scripts/productivity/install_spotify.sh" "Spotify" "spotify"
test_installer "scripts/productivity/install_zoom.sh" "Zoom" "zoom-client"
test_installer "scripts/system/install_yazi.sh" "Yazi" "yazi"
test_installer "scripts/productivity/install_telegram_desktop.sh" "Telegram Desktop" "telegram-desktop"
test_installer "scripts/productivity/install_obsidian.sh" "Obsidian" "obsidian"
test_installer "scripts/productivity/install_chromium.sh" "Chromium" "chromium"
test_installer "scripts/system/install_yq.sh" "yq" "yq"
test_installer "scripts/development/install_bruno.sh" "Bruno" "bruno"
test_installer "scripts/system/install_krita.sh" "Krita" "krita"

print_test_summary
echo "Nota: ninguno de estos 12 instaladores se prueba funcionalmente (requiere"
echo "snapd/systemd real) — ver la pauta de validación manual para Ubuntu"
echo "26.04 Desktop en docs/UBUNTU_COMPATIBILITY.md."

exit_with_test_summary
