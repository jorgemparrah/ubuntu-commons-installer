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
run_suite "tests/test_obs_studio_installer.sh" bash tests/test_obs_studio_installer.sh
run_suite "tests/test_tools_catalog_setup_js_consistency.sh" bash tests/test_tools_catalog_setup_js_consistency.sh
run_suite "tests/test_tools_catalog_ubuntu_compatibility_consistency.sh" bash tests/test_tools_catalog_ubuntu_compatibility_consistency.sh
run_suite "tests/test_snap_installers_full_contract.sh" bash tests/test_snap_installers_full_contract.sh
run_suite "tests/test_deb_direct_full_contract.sh" bash tests/test_deb_direct_full_contract.sh
run_suite "tests/test_terminal_apps_apt_simple_contract.sh" bash tests/test_terminal_apps_apt_simple_contract.sh
run_suite "tests/test_ghostty_installer.sh" bash tests/test_ghostty_installer.sh
run_suite "tests/test_curl_script_contract.sh" bash tests/test_curl_script_contract.sh
run_suite "tests/test_install_profile.sh" bash tests/test_install_profile.sh
run_suite "tests/test_list_info_commands.sh" bash tests/test_list_info_commands.sh
run_suite "tests/test_dependencies_lib.sh" bash tests/test_dependencies_lib.sh
run_suite "tests/test_powerlevel10k_dependency.sh" bash tests/test_powerlevel10k_dependency.sh
run_suite "tests/test_virtualbox_installer.sh" bash tests/test_virtualbox_installer.sh
run_suite "tests/test_slack_installer.sh" bash tests/test_slack_installer.sh
run_suite "tests/test_libreoffice_installer.sh" bash tests/test_libreoffice_installer.sh
run_suite "tests/test_keepassxc_installer.sh" bash tests/test_keepassxc_installer.sh
run_suite "tests/test_onlyoffice_installer.sh" bash tests/test_onlyoffice_installer.sh
run_suite "tests/test_brave_installer.sh" bash tests/test_brave_installer.sh
run_suite "tests/test_ngrok_installer.sh" bash tests/test_ngrok_installer.sh
run_suite "tests/test_ollama_installer.sh" bash tests/test_ollama_installer.sh
run_suite "tests/test_localsend_installer.sh" bash tests/test_localsend_installer.sh
run_suite "tests/test_steam_installer.sh" bash tests/test_steam_installer.sh
run_suite "tests/test_soapui_installer.sh" bash tests/test_soapui_installer.sh
run_suite "tests/test_hoppscotch_installer.sh" bash tests/test_hoppscotch_installer.sh
run_suite "tests/test_beekeeper_studio_installer.sh" bash tests/test_beekeeper_studio_installer.sh
run_suite "tests/test_dbgate_installer.sh" bash tests/test_dbgate_installer.sh
run_suite "tests/test_virt_manager_installer.sh" bash tests/test_virt_manager_installer.sh
run_suite "tests/test_vscodium_installer.sh" bash tests/test_vscodium_installer.sh
run_suite "tests/test_inkscape_installer.sh" bash tests/test_inkscape_installer.sh
run_suite "tests/test_element_installer.sh" bash tests/test_element_installer.sh
run_suite "tests/test_signal_desktop_installer.sh" bash tests/test_signal_desktop_installer.sh
run_suite "tests/test_joplin_installer.sh" bash tests/test_joplin_installer.sh
run_suite "tests/test_lutris_installer.sh" bash tests/test_lutris_installer.sh
run_suite "tests/test_heroic_installer.sh" bash tests/test_heroic_installer.sh
run_suite "tests/test_xh_installer.sh" bash tests/test_xh_installer.sh
run_suite "tests/test_dust_installer.sh" bash tests/test_dust_installer.sh
run_suite "tests/test_procs_installer.sh" bash tests/test_procs_installer.sh
run_suite "tests/test_terraform_installer.sh" bash tests/test_terraform_installer.sh
run_suite "tests/test_opentofu_installer.sh" bash tests/test_opentofu_installer.sh
run_suite "tests/test_azure_cli_installer.sh" bash tests/test_azure_cli_installer.sh
run_suite "tests/test_google_cloud_cli_installer.sh" bash tests/test_google_cloud_cli_installer.sh
run_suite "tests/test_awscli_installer.sh" bash tests/test_awscli_installer.sh
run_suite "tests/test_syncthing_installer.sh" bash tests/test_syncthing_installer.sh
run_suite "tests/test_eza_installer.sh" bash tests/test_eza_installer.sh
run_suite "tests/test_zip_utils_installer.sh" bash tests/test_zip_utils_installer.sh
run_suite "tests/test_tailscale_installer.sh" bash tests/test_tailscale_installer.sh
run_suite "tests/test_cloudflared_installer.sh" bash tests/test_cloudflared_installer.sh
run_suite "tests/test_fastfetch_installer.sh" bash tests/test_fastfetch_installer.sh
run_suite "tests/test_pipes_sh_installer.sh" bash tests/test_pipes_sh_installer.sh
run_suite "tests/test_pokemon_colorscripts_installer.sh" bash tests/test_pokemon_colorscripts_installer.sh
run_suite "tests/test_vagrant_installer.sh" bash tests/test_vagrant_installer.sh

section "Resumen general"
if [[ "${FAILED}" -eq 0 ]]; then
    echo "Todas las suites pasaron."
else
    echo "Al menos una suite falló. Revisa la salida arriba."
fi

exit "${FAILED}"
