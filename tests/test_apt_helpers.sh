#!/usr/bin/env bash
# tests/test_apt_helpers.sh
#
# Pruebas simuladas (mocks) de scripts/lib/apt.sh (Hito 11, Fase 1). No
# instala nada real: dpkg se intercepta con un comando falso en un PATH
# temporal.
#
# Uso:
#   bash tests/test_apt_helpers.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
APT_SH="${UCI_REPO_ROOT}/scripts/lib/apt.sh"
readonly APT_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
# shellcheck source=../scripts/lib/apt.sh
source "${APT_SH}"

UCI_MOCK_BIN=""

# setup_mock_dpkg <estado_por_paquete...>
# Cada argumento tiene la forma "paquete=estado", donde estado es
# "ii" (instalado), "rc" (removido, config remanente) o "missing" (dpkg
# no lo conoce en absoluto). Cualquier paquete no listado se trata como
# "missing". El mock solo entiende 'dpkg -l <paquete>' (un paquete a la
# vez), igual que el código real de apt_package_installed.
setup_mock_dpkg() {
    UCI_MOCK_BIN="$(mktemp -d)"
    local spec pkg state
    local -A states=()
    for spec in "$@"; do
        pkg="${spec%%=*}"
        state="${spec##*=}"
        states["${pkg}"]="${state}"
    done

    {
        echo "#!/usr/bin/env bash"
        echo 'if [[ "$1" != "-l" ]]; then exit 1; fi'
        echo 'pkg="$2"'
        echo 'case "$pkg" in'
        for pkg in "${!states[@]}"; do
            state="${states[${pkg}]}"
            if [[ "${state}" == "missing" ]]; then
                echo "    \"${pkg}\") echo \"dpkg-query: no packages found matching ${pkg}\" >&2; exit 1 ;;"
            else
                echo "    \"${pkg}\") echo \"${state}  ${pkg}  1.0  amd64  paquete de prueba\"; exit 0 ;;"
            fi
        done
        echo '    *) echo "dpkg-query: no packages found matching $pkg" >&2; exit 1 ;;'
        echo 'esac'
    } > "${UCI_MOCK_BIN}/dpkg"
    chmod +x "${UCI_MOCK_BIN}/dpkg"
}

# setup_mock_dpkg_broken <codigo_de_salida>
# Simula un dpkg roto/inesperado: sale con un código de error que no es
# ni éxito (0) ni "no encontrado" (1) — por ejemplo, un error de permisos
# o de base de datos corrupta de dpkg.
setup_mock_dpkg_broken() {
    local exit_code="$1"
    UCI_MOCK_BIN="$(mktemp -d)"
    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg: error fatal simulado" >&2
exit ${exit_code}
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"
}

teardown_mock_dpkg() {
    rm -rf "${UCI_MOCK_BIN}"
}

with_mock_path() {
    PATH="${UCI_MOCK_BIN}:${PATH}" "$@"
}

echo "== apt_package_installed: paquete con estado 'ii' -> instalado =="
setup_mock_dpkg "cmatrix=ii"
if with_mock_path apt_package_installed cmatrix; then
    pass "apt_package_installed reporta instalado para estado 'ii'"
else
    fail "apt_package_installed debería reportar instalado para estado 'ii'"
fi
teardown_mock_dpkg

echo ""
echo "== apt_package_installed: paquete ausente (dpkg no lo conoce) -> no instalado =="
setup_mock_dpkg "cmatrix=missing"
if with_mock_path apt_package_installed cmatrix; then
    fail "apt_package_installed no debería reportar instalado para un paquete ausente"
else
    pass "apt_package_installed reporta no instalado para un paquete que dpkg desconoce"
fi
teardown_mock_dpkg

echo ""
echo "== apt_package_installed: estado residual 'rc' (config remanente) -> no instalado =="
setup_mock_dpkg "cmatrix=rc"
if with_mock_path apt_package_installed cmatrix; then
    fail "apt_package_installed no debería confundir el estado residual 'rc' con instalado"
else
    pass "apt_package_installed distingue el estado residual 'rc' de instalado de verdad"
fi
teardown_mock_dpkg

echo ""
echo "== apt_all_packages_installed: varios paquetes, todos instalados =="
setup_mock_dpkg "wget=ii" "curl=ii" "git=ii"
if with_mock_path apt_all_packages_installed wget curl git; then
    pass "apt_all_packages_installed reporta éxito cuando todos están instalados"
else
    fail "apt_all_packages_installed debería reportar éxito cuando todos están instalados"
fi
teardown_mock_dpkg

echo ""
echo "== apt_all_packages_installed: uno de varios está ausente =="
setup_mock_dpkg "wget=ii" "curl=missing" "git=ii"
if with_mock_path apt_all_packages_installed wget curl git; then
    fail "apt_all_packages_installed no debería reportar éxito si falta uno"
else
    pass "apt_all_packages_installed reporta fallo si al menos uno de varios está ausente"
fi
teardown_mock_dpkg

echo ""
echo "== apt_all_packages_installed: uno de varios en estado residual 'rc' =="
setup_mock_dpkg "wget=ii" "curl=rc" "git=ii"
if with_mock_path apt_all_packages_installed wget curl git; then
    fail "apt_all_packages_installed no debería reportar éxito si uno quedó en estado 'rc'"
else
    pass "apt_all_packages_installed reporta fallo si uno de varios quedó en estado residual"
fi
teardown_mock_dpkg

echo ""
echo "== apt_package_installed: propagación de un error inesperado de dpkg =="
setup_mock_dpkg_broken 2
if with_mock_path apt_package_installed cmatrix; then
    fail "apt_package_installed no debería reportar instalado si dpkg falla de forma inesperada"
else
    pass "un error inesperado de dpkg (código distinto de 0/1) no se confunde con 'instalado'; no cuelga ni revienta el proceso"
fi
teardown_mock_dpkg

print_test_summary
exit_with_test_summary
