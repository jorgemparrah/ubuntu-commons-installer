#!/usr/bin/env bash
# tests/test_virt_manager_installer.sh
#
# Prueba simulada (mocks) de
# scripts/development/install_virt_manager.sh (Hito 33, ver
# docs/ROADMAP.md). No instala nada real: apt-get/apt/dpkg/sudo/
# groupadd/usermod/gpasswd/groups/systemctl/kvm-ok se interceptan con
# comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_virt_manager_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_virt_manager.sh"
readonly INSTALL_SH
readonly UCI_PKG_NAME="virt-manager"

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <dpkg_state: ii|missing> [<upgradable: yes|no>] [<binary: auto|yes|no>] [<kvm_supported: yes|no>]
setup_mock_bin() {
    local dpkg_state="$1" upgradable="${2:-no}" binary="${3:-auto}" kvm_supported="${4:-yes}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_state}" == "ii" ]]; then
        echo "ii  \$2  1.0  amd64  paquete de prueba"
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
    echo "${UCI_PKG_NAME}/noble 4.2.0-1 amd64 [upgradable from: 4.1.0-1]"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    for cmd in groupadd usermod gpasswd; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done

    cat > "${UCI_MOCK_BIN}/systemctl" <<EOF
#!/usr/bin/env bash
echo "systemctl \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/systemctl"

    cat > "${UCI_MOCK_BIN}/groups" <<'EOF'
#!/usr/bin/env bash
echo "usuario libvirt kvm sudo"
EOF
    chmod +x "${UCI_MOCK_BIN}/groups"

    cat > "${UCI_MOCK_BIN}/kvm-ok" <<EOF
#!/usr/bin/env bash
echo "kvm-ok \$*" >> "${UCI_MOCK_LOG}"
if [[ "${kvm_supported}" == "yes" ]]; then
    exit 0
fi
exit 1
EOF
    chmod +x "${UCI_MOCK_BIN}/kvm-ok"

    local create_binary="no"
    if [[ "${binary}" == "yes" ]]; then
        create_binary="yes"
    elif [[ "${binary}" == "auto" && "${dpkg_state}" == "ii" ]]; then
        create_binary="yes"
    fi
    if [[ "${create_binary}" == "yes" ]]; then
        cat > "${UCI_MOCK_BIN}/virt-manager" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/virt-manager"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <dpkg_state> [<upgradable>] [<binary>] [<kvm_supported>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" dpkg_state="$2" upgradable="${3:-no}" binary="${4:-auto}" kvm_supported="${5:-yes}"
    setup_mock_bin "${dpkg_state}" "${upgradable}" "${binary}" "${kvm_supported}"
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
echo "== 2. install: instala todos los paquetes, agrega grupos y habilita libvirtd =="
run_installer "install" "missing"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker" "${UCI_MOCK_LOG}"; then
    pass "'install' instala todos los paquetes necesarios"
else
    fail "'install' no instaló los paquetes esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "usermod -aG libvirt,kvm" "${UCI_MOCK_LOG}"; then
    pass "'install' agrega el usuario a los grupos 'libvirt' y 'kvm'"
else
    fail "'install' no agregó los grupos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "systemctl enable --now libvirtd" "${UCI_MOCK_LOG}"; then
    pass "'install' habilita e inicia el servicio 'libvirtd'"
else
    fail "'install' no habilitó 'libvirtd'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. install: advierte si el hardware no soporta virtualización (kvm-ok falla) =="
run_installer "install" "missing" "no" "auto" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"Advertencia"* ]]; then
    pass "'install' avisa si kvm-ok reporta que no hay soporte de virtualización"
else
    fail "'install' debería avisar sin fallar si no hay soporte de virtualización (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. install: no advierte si el hardware SÍ soporta virtualización =="
run_installer "install" "missing" "no" "auto" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" != *"Advertencia"* ]]; then
    pass "'install' no avisa si kvm-ok confirma soporte de virtualización"
else
    fail "'install' no debería avisar si hay soporte de virtualización. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. status con el paquete instalado: INSTALLED =="
run_installer "status" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con dpkg 'ii' pero sin binario resoluble: BROKEN =="
run_installer "status" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el binario 'virt-manager' no resuelve"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. status con candidato de actualización: OUTDATED =="
run_installer "status" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "ii" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 9. uninstall purga todos los paquetes y quita los grupos =="
run_installer "uninstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get purge -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga todos los paquetes (no remove)"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "gpasswd -d .* libvirt" "${UCI_MOCK_LOG}" && grep -q "gpasswd -d .* kvm" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' quita al usuario de los grupos 'libvirt' y 'kvm'"
else
    fail "'uninstall' no quitó los grupos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 10. update invoca '--only-upgrade' sobre todos los paquetes =="
run_installer "update" "ii" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade' sobre todos los paquetes"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 11. repair corre 'dpkg --configure -a' y reinstala todos los paquetes =="
run_installer "repair" "ii" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "dpkg --configure -a" "${UCI_MOCK_LOG}" && grep -q "apt-get install --reinstall -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker" "${UCI_MOCK_LOG}"; then
    pass "'repair' corre 'dpkg --configure -a' y reinstala todos los paquetes"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 12. reinstall reinstala todos los paquetes directo (sin purgar) =="
run_installer "reinstall" "ii"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y virt-manager qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' invoca 'apt-get install --reinstall' sobre todos los paquetes"
else
    fail "'reinstall' no se comportó como se esperaba (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "purge" "${UCI_MOCK_LOG}"; then
    fail "'reinstall' no debería pasar por 'purge'"
else
    pass "'reinstall' evita el ciclo completo de purge+autoremove"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
