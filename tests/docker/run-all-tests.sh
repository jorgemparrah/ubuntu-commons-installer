#!/usr/bin/env bash
# tests/docker/run-all-tests.sh
#
# Corre toda la batería de pruebas del repositorio. Pensado para ejecutarse
# DENTRO de la imagen de tests/docker/Dockerfile (ver docs/TESTING.md), pero
# también funciona en cualquier máquina si se acepta correr los tests
# reales (bash -n, node --check, y los tests/*.sh y *.js).
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

cd "${UCI_REPO_ROOT}"

FAILED=0

section() {
    echo ""
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

run_suite() {
    local description="$1"
    shift
    section "${description}"
    if "$@"; then
        echo ">>> ${description}: OK"
    else
        echo ">>> ${description}: FALLÓ"
        FAILED=1
    fi
}

section "Sintaxis (bash -n)"
if bash -n setup.sh && find scripts -type f -name '*.sh' -exec bash -n {} \;; then
    echo ">>> Sintaxis: OK"
else
    echo ">>> Sintaxis: FALLÓ"
    FAILED=1
fi

if command -v shellcheck >/dev/null 2>&1; then
    section "ShellCheck"
    if shellcheck setup.sh scripts/lib/*.sh scripts/bootstrap/*.sh scripts/diagnostics/*.sh scripts/migrations/*.sh; then
        echo ">>> ShellCheck: OK"
    else
        echo ">>> ShellCheck: FALLÓ"
        FAILED=1
    fi
else
    echo ""
    echo "ShellCheck no está disponible en esta imagen; se omite."
fi

if command -v node >/dev/null 2>&1; then
    section "node --check"
    if node --check setup.js && node --check scripts/lib/status_contract.js; then
        echo ">>> node --check: OK"
    else
        echo ">>> node --check: FALLÓ"
        FAILED=1
    fi
    run_suite "tests/test_status_mapping.js" node tests/test_status_mapping.js
else
    echo ""
    echo "Node.js no está disponible en esta imagen; se omite tests/test_status_mapping.js."
fi

run_suite "tests/test_router.sh" bash tests/test_router.sh
run_suite "tests/test_doctor.sh" bash tests/test_doctor.sh
run_suite "tests/test_backup.sh" bash tests/test_backup.sh
run_suite "tests/test_backup_move_dir.sh" bash tests/test_backup_move_dir.sh
run_suite "tests/test_migrations.sh" bash tests/test_migrations.sh
run_suite "tests/test_install_nodejs_legacy.sh" bash tests/test_install_nodejs_legacy.sh
run_suite "tests/test_system_utils_contract.sh" bash tests/test_system_utils_contract.sh
run_suite "tests/test_system_update_contract.sh" bash tests/test_system_update_contract.sh
run_suite "tests/test_mongodb_compass_download.sh" bash tests/test_mongodb_compass_download.sh
run_suite "tests/test_kernel_hwe_fallback.sh" bash tests/test_kernel_hwe_fallback.sh
run_suite "tests/test_chrome_arch_check.sh" bash tests/test_chrome_arch_check.sh
run_suite "tests/test_snap_installers_contract.sh" bash tests/test_snap_installers_contract.sh
run_suite "tests/test_installer_cli.sh" bash tests/test_installer_cli.sh
run_suite "tests/test_apt_helpers.sh" bash tests/test_apt_helpers.sh
run_suite "tests/test_cmatrix_installer.sh" bash tests/test_cmatrix_installer.sh
run_suite "tests/test_ranger_installer.sh" bash tests/test_ranger_installer.sh
run_suite "tests/test_terminator_installer.sh" bash tests/test_terminator_installer.sh
run_suite "tests/test_flameshot_installer.sh" bash tests/test_flameshot_installer.sh
run_suite "tests/test_tools_registry.sh" bash tests/test_tools_registry.sh
run_suite "tests/test_split_installers_contract.sh" bash tests/test_split_installers_contract.sh
run_suite "tests/test_tools_catalog_docs_consistency.sh" bash tests/test_tools_catalog_docs_consistency.sh
run_suite "tests/test_ulauncher_installer.sh" bash tests/test_ulauncher_installer.sh
run_suite "tests/test_tools_catalog_setup_js_consistency.sh" bash tests/test_tools_catalog_setup_js_consistency.sh
run_suite "tests/test_snap_installers_full_contract.sh" bash tests/test_snap_installers_full_contract.sh

section "Resumen general"
if [[ "${FAILED}" -eq 0 ]]; then
    echo "Todas las suites pasaron."
else
    echo "Al menos una suite falló. Revisa la salida arriba."
fi

exit "${FAILED}"
