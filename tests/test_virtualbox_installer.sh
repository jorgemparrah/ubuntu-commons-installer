#!/usr/bin/env bash
# tests/test_virtualbox_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_virtualbox.sh
# (Hito 24, ver docs/ROADMAP.md). No instala nada real ni carga ningún
# módulo de kernel: apt-get/apt-cache/apt/dpkg/gpg/curl/sudo/groupadd/
# usermod/gpasswd se interceptan con comandos falsos en un PATH temporal.
# El dispositivo del módulo de kernel (/dev/vboxdrv) se simula vía
# UCI_VIRTUALBOX_VBOXDRV_PATH, apuntado a un archivo temporal — ningún
# contenedor Docker de este proyecto puede cargar un módulo de kernel de
# verdad (ver el encabezado del propio instalador); la validación real
# queda para tests/manual/ (Hito 19).
#
# Uso:
#   bash tests/test_virtualbox_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_virtualbox.sh"
readonly INSTALL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_VBOXDRV_FILE=""

# setup_mock_bin <dpkg_installed_pkg:vacío|virtualbox-X.Y> [<upgradable:yes|no>] [<latest_available:virtualbox-X.Y>]
setup_mock_bin() {
    local installed_pkg="${1:-}" upgradable="${2:-no}" latest_available="${3:-virtualbox-7.1}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_VBOXDRV_FILE="$(mktemp -u)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "--print-architecture" ]]; then
    echo "amd64"
    exit 0
fi
if [[ "\$1" == "-l" ]]; then
    if [[ -n "${installed_pkg}" ]]; then
        echo "ii  ${installed_pkg}  1.0  amd64  paquete de prueba"
    fi
    exit 0
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

    cat > "${UCI_MOCK_BIN}/apt-cache" <<EOF
#!/usr/bin/env bash
echo "apt-cache \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "search" ]]; then
    echo "${latest_available} - VirtualBox ${latest_available#virtualbox-}"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt-cache"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "list" && "${upgradable}" == "yes" && -n "${installed_pkg}" ]]; then
    echo "${installed_pkg}/noble 7.1.2-1 amd64 [upgradable from: 7.1.0-1]"
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

    for cmd in groupadd usermod gpasswd dkms; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done

    # 'install'/'tee': apt_vendor_repo_fetch_key_dearmored/apt_vendor_repo_write_list
    # (scripts/lib/apt_vendor_repo.sh) los invocan vía 'sudo' para escribir
    # el keyring/la lista de repos en rutas reales del sistema
    # (/usr/share/keyrings, /etc/apt/sources.list.d). Como el mock de
    # 'sudo' de acá hace passthrough directo (no simula privilegios), sin
    # mockear también 'install'/'tee' se invocarían los binarios REALES
    # del sistema contra esas rutas, fallando por permisos en un
    # contenedor no-root (bug real encontrado en la primera corrida de
    # CI de este test). Se mockean con el mismo criterio que el resto:
    # solo registran la invocación, nunca tocan el sistema real.
    cat > "${UCI_MOCK_BIN}/install" <<EOF
#!/usr/bin/env bash
echo "install \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/install"

    cat > "${UCI_MOCK_BIN}/tee" <<EOF
#!/usr/bin/env bash
echo "tee \$*" >> "${UCI_MOCK_LOG}"
cat > /dev/null
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/tee"

    cat > "${UCI_MOCK_BIN}/groups" <<'EOF'
#!/usr/bin/env bash
echo "usuario vboxusers sudo"
EOF
    chmod +x "${UCI_MOCK_BIN}/groups"

    cat > "${UCI_MOCK_BIN}/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-r" ]]; then
    echo "6.8.0-generic"
    exit 0
fi
exit 1
EOF
    chmod +x "${UCI_MOCK_BIN}/uname"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}" "${UCI_VBOXDRV_FILE}"
}

# run_installer <acción> <dpkg_installed_pkg> [<upgradable>] [<latest_available>] [<vboxdrv_presente:yes|no>]
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" installed_pkg="${2:-}" upgradable="${3:-no}" latest_available="${4:-virtualbox-7.1}" vboxdrv_present="${5:-no}"
    setup_mock_bin "${installed_pkg}" "${upgradable}" "${latest_available}"
    if [[ "${vboxdrv_present}" == "yes" ]]; then
        touch "${UCI_VBOXDRV_FILE}"
    fi
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" UCI_VIRTUALBOX_VBOXDRV_PATH="${UCI_VBOXDRV_FILE}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. comando desconocido =="
run_installer "esto-no-existe" ""
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "comando desconocido sale con código distinto de cero"
else
    fail "comando desconocido debería salir con código distinto de cero"
fi
teardown_mock_bin

echo ""
echo "== 2. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" ""
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 3. install: detecta el paquete más nuevo disponible y lo instala =="
run_installer "install" "" "no" "virtualbox-7.1" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get install -y linux-headers-6.8.0-generic dkms virtualbox-7.1" "${UCI_MOCK_LOG}"; then
    pass "'install' instala linux-headers/dkms/el paquete detectado dinámicamente"
else
    fail "'install' no instaló lo esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "usermod -aG vboxusers" "${UCI_MOCK_LOG}"; then
    pass "'install' agrega el usuario al grupo 'vboxusers'"
else
    fail "'install' no agregó el grupo 'vboxusers'. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"Advertencia"* ]]; then
    pass "'install' avisa si el módulo de kernel no cargó (esperado en este entorno simulado)"
else
    fail "'install' debería avisar que el módulo no cargó. Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. status tras una instalación cuyo módulo SÍ cargó: INSTALLED =="
run_installer "status" "virtualbox-7.1" "no" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED cuando el paquete está instalado y el módulo cargó"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. status tras una instalación cuyo módulo NO cargó: BROKEN =="
run_installer "status" "virtualbox-7.1" "no" "virtualbox-7.1" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN cuando el paquete está instalado pero el módulo no cargó"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. status con candidato de actualización: OUTDATED =="
run_installer "status" "virtualbox-7.1" "yes" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"OUTDATED"* ]]; then
    pass "'status' reporta OUTDATED con candidato de actualización disponible"
else
    fail "'status' no reportó OUTDATED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. install rechaza si ya está instalado (INSTALLED/OUTDATED) =="
run_installer "install" "virtualbox-7.1" "no" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"update"* ]]; then
    pass "'install' rechaza y sugiere 'update' si ya está instalado"
else
    fail "'install' debería rechazar si ya está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "virtualbox-7.1" "no" "virtualbox-7.1" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 9. uninstall: purga el paquete detectado y limpia repo/clave/grupo =="
run_installer "uninstall" "virtualbox-7.1" "no" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "apt-get purge -y virtualbox-7.1" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' purga el paquete detectado (no 'remove')"
else
    fail "'uninstall' no purgó el paquete esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "gpasswd -d" "${UCI_MOCK_LOG}"; then
    pass "'uninstall' quita al usuario del grupo 'vboxusers' (estaba presente en el mock de 'groups')"
else
    fail "'uninstall' no quitó al usuario del grupo. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 10. uninstall idempotente si no hay nada instalado =="
run_installer "uninstall" ""
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sobre NOT_INSTALLED no falla"
else
    fail "'uninstall' sobre NOT_INSTALLED no debería fallar (fue ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 11. reinstall/update/repair rechazan sobre NOT_INSTALLED =="
for verb in reinstall update repair; do
    run_installer "${verb}" ""
    if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"install"* ]]; then
        pass "'${verb}' sobre NOT_INSTALLED rechaza y sugiere 'install'"
    else
        fail "'${verb}' debería rechazar sobre NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mock_bin
done

echo ""
echo "== 12. update invoca '--only-upgrade' sobre el paquete detectado =="
run_installer "update" "virtualbox-7.1" "yes" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --only-upgrade -y virtualbox-7.1" "${UCI_MOCK_LOG}"; then
    pass "'update' invoca '--only-upgrade' sobre el paquete detectado"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 13. repair reinstala linux-headers/dkms/el paquete detectado =="
run_installer "repair" "virtualbox-7.1" "no" "virtualbox-7.1" "no"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y virtualbox-7.1" "${UCI_MOCK_LOG}" && grep -q "dkms autoinstall" "${UCI_MOCK_LOG}"; then
    pass "'repair' reinstala el paquete y corre 'dkms autoinstall'"
else
    fail "'repair' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 14. reinstall usa 'apt-get install --reinstall' directo (sin purgar) =="
run_installer "reinstall" "virtualbox-7.1" "no" "virtualbox-7.1" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "apt-get install --reinstall -y virtualbox-7.1" "${UCI_MOCK_LOG}"; then
    pass "'reinstall' invoca 'apt-get install --reinstall' sobre el paquete detectado"
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
