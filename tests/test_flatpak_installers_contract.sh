#!/usr/bin/env bash
# tests/test_flatpak_installers_contract.sh
#
# Prueba simulada (mocks) del ciclo de vida de los instaladores del
# mecanismo Flatpak (Hito 50, ver
# docs/adr/0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md):
# Kooha y Papers. Confirma que 'status' distingue los tres casos —
# app instalada, app no instalada, Flatpak ausente (UNKNOWN) — mismo
# criterio que tests/test_snap_installers_contract.sh, más el ciclo
# install/uninstall/update y el rechazo explícito de 'repair'.
#
# No instala nada real: 'flatpak'/'apt-get'/'sudo' se interceptan con
# comandos falsos en un PATH temporal. No requiere flatpak real — corre en
# cualquier máquina, incluida la de desarrollo.
#
# Uso:
#   bash tests/test_flatpak_installers_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <estado: installed|not-installed|flatpak-absent> <app_id>
setup_mock_bin() {
    local estado="$1" app_id="$2"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
echo "apt-get \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-get"

    # 'flatpak-absent': no se crea el binario en el PATH temporal, así que
    # 'command -v flatpak' falla y check_status debe reportar UNKNOWN.
    if [[ "${estado}" == "flatpak-absent" ]]; then
        return 0
    fi

    cat > "${UCI_MOCK_BIN}/flatpak" <<EOF
#!/usr/bin/env bash
echo "flatpak \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "--version" ]]; then
    echo "Flatpak 1.14.6"
    exit 0
fi
if [[ "\$1" == "list" ]]; then
    if [[ "${estado}" == "installed" ]]; then
        echo "${app_id}"
    fi
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/flatpak"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <estado> <app_id>
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2" estado="$3" app_id="$4"
    setup_mock_bin "${estado}" "${app_id}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:/usr/bin:/bin" bash "${UCI_REPO_ROOT}/${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

test_flatpak_contract() {
    local script="$1" name="$2" app_id="$3"

    echo ""
    echo "== ${name} (${script}) =="

    run_installer "${script}" "status" "installed" "${app_id}"
    if [[ "${RUN_OUTPUT}" == "INSTALLED" && "${RUN_CODE}" -eq 0 ]]; then
        pass "${name}: app instalada -> INSTALLED, código 0"
    else
        fail "${name}: app instalada debería dar INSTALLED/código 0. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "not-installed" "${app_id}"
    if [[ "${RUN_OUTPUT}" == "NOT_INSTALLED" && "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: Flatpak presente pero app no instalada -> NOT_INSTALLED"
    else
        fail "${name}: app no instalada debería dar NOT_INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "flatpak-absent" "${app_id}"
    if [[ "${RUN_OUTPUT}" == "UNKNOWN" && "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: Flatpak ausente -> UNKNOWN (no se confunde con NOT_INSTALLED)"
    else
        fail "${name}: Flatpak ausente debería dar UNKNOWN. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "not-installed" "${app_id}"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "${name}: 'install' sale con código 0"
    else
        fail "${name}: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "flatpak remote-add --if-not-exists flathub" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' registra el remote de Flathub de forma idempotente"
    else
        fail "${name}: 'install' no registró el remote de Flathub. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if grep -q "flatpak install -y flathub ${app_id}" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' instala el app ID '${app_id}' desde flathub"
    else
        fail "${name}: 'install' no instaló el app ID esperado. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    # Flatpak ausente al instalar: el helper debe instalarlo vía APT antes
    # de seguir (no viene por defecto en Ubuntu, a diferencia de snapd).
    run_installer "${script}" "install" "flatpak-absent" "${app_id}"
    if grep -q "apt-get install -y flatpak" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' instala el paquete 'flatpak' vía APT si falta"
    else
        fail "${name}: 'install' no instaló 'flatpak' cuando faltaba. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "installed" "${app_id}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "flatpak uninstall -y ${app_id}" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'uninstall' remueve el app ID"
    else
        fail "${name}: 'uninstall' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "installed" "${app_id}"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "flatpak update -y ${app_id}" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'update' actualiza el app ID"
    else
        fail "${name}: 'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "installed" "${app_id}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: 'repair' se rechaza explícitamente (no implementado a propósito)"
    else
        fail "${name}: 'repair' debería rechazarse (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "esto-no-existe" "installed" "${app_id}"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${name}: subcomando inválido sale con código distinto de cero"
    else
        fail "${name}: subcomando inválido debería fallar"
    fi
    teardown_mock_bin
}

test_flatpak_contract "scripts/system/install_kooha.sh" "Kooha" "io.github.seadve.Kooha"
test_flatpak_contract "scripts/productivity/install_papers.sh" "Papers" "org.gnome.Papers"

echo ""
echo "Nota: ninguno de estos instaladores se prueba funcionalmente en CI"
echo "(requiere flatpak real y acceso a Flathub por red) — mismo criterio"
echo "que el grupo Snap, ver docs/UBUNTU_COMPATIBILITY.md."

print_test_summary
exit_with_test_summary
