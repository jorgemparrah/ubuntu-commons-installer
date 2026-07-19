#!/usr/bin/env bash
# tests/test_system_utils_contract.sh
#
# Prueba simulada (comandos interceptados/mocks) de los 3 agrupadores
# delgados (ver ADR 0031, docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md):
# scripts/system/install_system_utils.sh, install_development_tools.sh e
# install_multimedia.sh. Desde esa migración, cada uno delega en sus
# instaladores individuales (bash "$member" status|install|uninstall) en
# vez de manejar los paquetes directamente — esta prueba confirma que la
# delegación funciona de punta a punta, no la lógica de cada paquete
# individual (esa vive en tests/test_split_installers_contract.sh). No
# instala nada real: apt-get/apt/dpkg/sudo se interceptan con comandos
# falsos en un PATH temporal, heredado por los procesos hijos que lanza
# cada agrupador.
#
# Uso:
#   bash tests/test_system_utils_contract.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <estado_dpkg: installed|not_installed> [<binarios_a_crear...>]
# dpkg -l <paquete> responde "instalado" o "no instalado" para CUALQUIER
# paquete consultado (a diferencia de tests/test_split_installers_contract.sh,
# acá no importa distinguir por paquete: los 3 agrupadores solo se prueban
# en el caso "todos instalados" / "ninguno instalado"). apt-get/apt/sudo
# solo registran su invocación; sudo despoja asignaciones NAME=value antes
# de ejecutar (necesario para install_ubuntu_restricted_extras.sh:
# DEBIAN_FRONTEND=noninteractive).
setup_mock_bin() {
    local dpkg_state="$1"
    shift
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "installed" ]]; then
        echo "ii  \$2  1.0  amd64  paquete de prueba"
        exit 0
    else
        exit 1
    fi
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
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "SUDO_LOG_PLACEHOLDER"
while [[ "$#" -gt 0 && "$1" == *=* && "$1" != -* ]]; do
    export "$1"
    shift
done
"$@"
EOF
    sed -i "s#SUDO_LOG_PLACEHOLDER#${UCI_MOCK_LOG}#" "${UCI_MOCK_BIN}/sudo"
    chmod +x "${UCI_MOCK_BIN}/sudo"

    local binary
    if [[ "${dpkg_state}" == "installed" ]]; then
        for binary in "$@"; do
            cat > "${UCI_MOCK_BIN}/${binary}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
            chmod +x "${UCI_MOCK_BIN}/${binary}"
        done
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <script> <accion> <estado_dpkg> [<binarios...>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="${2:-}" dpkg_state="$3"
    shift 3
    setup_mock_bin "${dpkg_state}" "$@"

    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${script}" ${action} 2>&1)"
    RUN_CODE=$?
    set -e
}

# test_group_contract <script> <nombre> <binarios...>
# <binarios...> son los binarios reales de los miembros del grupo (los
# paquetes meta sin binario propio, como build-essential, no aportan
# ninguno — ver ADR 0031), usados solo para el escenario "todo instalado".
test_group_contract() {
    local script="$1" name="$2"
    shift 2

    echo ""
    echo "== ${name} (${script}) =="

    run_installer "${script}" "" "not_installed"
    if grep -q "apt-get install" "${UCI_MOCK_LOG}"; then
        fail "${name}: invocar sin argumentos no debería instalar nada (se detectó 'apt-get install')"
    else
        pass "${name}: invocar sin argumentos no instala nada"
    fi
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: invocar sin argumentos debería salir con código distinto de cero (uso inválido)"
    else
        pass "${name}: invocar sin argumentos sale con código distinto de cero"
    fi
    teardown_mock_bin

    run_installer "${script}" "esto-no-existe" "not_installed"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: subcomando inválido debería salir con código distinto de cero"
    else
        pass "${name}: subcomando inválido sale con código distinto de cero"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "installed" "$@"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        fail "${name}: 'status' con todos los miembros instalados debería salir con código 0 (fue ${RUN_CODE})"
    else
        pass "${name}: 'status' con todos los miembros instalados sale con código 0"
    fi
    if [[ "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "${name}: 'status' reporta INSTALLED cuando corresponde"
    else
        fail "${name}: 'status' no reportó INSTALLED. Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "apt-get install" "${UCI_MOCK_LOG}"; then
        fail "${name}: 'status' no debería instalar nada"
    else
        pass "${name}: 'status' es de solo lectura (no llama 'apt-get install')"
    fi
    teardown_mock_bin

    run_installer "${script}" "status" "not_installed"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: 'status' sin ningún miembro instalado debería salir con código distinto de cero"
    else
        pass "${name}: 'status' sin ningún miembro instalado sale con código distinto de cero"
    fi
    if [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "${name}: 'status' reporta NOT_INSTALLED cuando corresponde"
    else
        fail "${name}: 'status' no reportó NOT_INSTALLED. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin

    run_installer "${script}" "install" "not_installed"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        fail "${name}: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    else
        pass "${name}: 'install' sale con código 0"
    fi
    if grep -q "apt-get install" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'install' invoca 'apt-get install' (delegado en los miembros)"
    else
        fail "${name}: 'install' no invocó 'apt-get install'. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "uninstall" "installed" "$@"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        fail "${name}: 'uninstall' debería salir con código 0 (fue ${RUN_CODE})"
    else
        pass "${name}: 'uninstall' sale con código 0"
    fi
    if grep -q "apt-get purge" "${UCI_MOCK_LOG}"; then
        pass "${name}: 'uninstall' invoca 'apt-get purge' (delegado en los miembros)"
    else
        fail "${name}: 'uninstall' no invocó 'apt-get purge'. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mock_bin

    run_installer "${script}" "update" "installed" "$@"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: 'update' a nivel de grupo no está implementado a propósito (ADR 0031); debería rechazarse"
    else
        pass "${name}: 'update' a nivel de grupo se rechaza explícitamente (código ${RUN_CODE})"
    fi
    teardown_mock_bin

    run_installer "${script}" "repair" "installed" "$@"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        fail "${name}: 'repair' a nivel de grupo no está implementado a propósito (ADR 0031); debería rechazarse"
    else
        pass "${name}: 'repair' a nivel de grupo se rechaza explícitamente (código ${RUN_CODE})"
    fi
    teardown_mock_bin
}

test_group_contract "${UCI_REPO_ROOT}/scripts/system/install_system_utils.sh" "System Utils" meld baobab gparted
test_group_contract "${UCI_REPO_ROOT}/scripts/system/install_development_tools.sh" "Development Tools" wget curl git add-apt-repository gpg
test_group_contract "${UCI_REPO_ROOT}/scripts/system/install_multimedia.sh" "Multimedia" cheese v4l2-ctl vlc

echo ""
echo "== install_ubuntu_restricted_extras.sh usa DEBIAN_FRONTEND=noninteractive (EULA) =="
if grep -q "DEBIAN_FRONTEND=noninteractive" "${UCI_REPO_ROOT}/scripts/system/install_ubuntu_restricted_extras.sh"; then
    pass "install_ubuntu_restricted_extras.sh fija DEBIAN_FRONTEND=noninteractive antes de instalar"
else
    fail "install_ubuntu_restricted_extras.sh no fija DEBIAN_FRONTEND=noninteractive"
fi

print_test_summary

exit_with_test_summary
