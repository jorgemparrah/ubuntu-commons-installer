#!/usr/bin/env bash
# tests/test_installer_cli.sh
#
# Pruebas no destructivas de scripts/lib/installer_cli.sh (Hito 11, Fase
# 1). No instala nada real: genera pequeños "fixtures" (scripts temporales
# que sourcean la biblioteca real y definen funciones falsas) y los corre
# como procesos Bash normales, para poder observar su código de salida sin
# arriesgar que un `set -e` de este mismo test aborte antes de tiempo.
#
# Uso:
#   bash tests/test_installer_cli.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALLER_CLI_SH="${UCI_REPO_ROOT}/scripts/lib/installer_cli.sh"
readonly INSTALLER_CLI_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_FIXTURE_DIR="$(mktemp -d)"
readonly UCI_FIXTURE_DIR
UCI_FIXTURE_MARKER="${UCI_FIXTURE_DIR}/marker.log"
readonly UCI_FIXTURE_MARKER

cleanup() {
    rm -rf "${UCI_FIXTURE_DIR}"
}
trap cleanup EXIT

# make_fixture <cuerpo_de_funciones>
# Escribe un script temporal que sourcea la biblioteca REAL y define las
# funciones que el cuerpo dado declare, y termina llamando a
# installer_run_cli "$@". Imprime la ruta del fixture creado.
make_fixture() {
    local body="$1"
    local fixture="${UCI_FIXTURE_DIR}/fixture_${RANDOM}.sh"
    {
        echo "#!/usr/bin/env bash"
        echo "set -Eeuo pipefail"
        echo "source \"${INSTALLER_CLI_SH}\""
        echo "TOOL_NAME=\"FixtureTool\""
        echo "UCI_FIXTURE_MARKER=\"${UCI_FIXTURE_MARKER}\""
        echo "${body}"
        echo 'installer_run_cli "$@"'
    } > "${fixture}"
    echo "${fixture}"
}

# Fixture con los 6 verbos implementados, cada uno deja una marca
# distinguible en UCI_FIXTURE_MARKER para poder confirmar que se invocó la
# función correcta.
FULL_FIXTURE="$(make_fixture '
check_status() { echo "status-called" >> "${UCI_FIXTURE_MARKER}"; echo "INSTALLED"; return 0; }
install_tool() { echo "install-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
uninstall_tool() { echo "uninstall-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
reinstall_tool() { echo "reinstall-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
update_tool() { echo "update-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
repair_tool() { echo "repair-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
')"

echo "== Los 6 comandos válidos invocan la función correspondiente =="
for pair in "status:status-called" "install:install-called" "uninstall:uninstall-called" \
            "reinstall:reinstall-called" "update:update-called" "repair:repair-called"; do
    verb="${pair%%:*}"
    expected_marker="${pair##*:}"
    : > "${UCI_FIXTURE_MARKER}"
    set +e
    bash "${FULL_FIXTURE}" "${verb}" > /dev/null 2>&1
    code=$?
    set -e
    if [[ "${code}" -eq 0 ]] && grep -qx "${expected_marker}" "${UCI_FIXTURE_MARKER}"; then
        pass "'${verb}' invoca su función correspondiente y sale con código 0"
    else
        fail "'${verb}' no invocó '${expected_marker}' o no salió con código 0 (fue ${code})"
    fi
done

echo ""
echo "== reinstall usa reinstall_tool() si está definida (no el fallback mecánico) =="
: > "${UCI_FIXTURE_MARKER}"
bash "${FULL_FIXTURE}" reinstall > /dev/null 2>&1 || true
if grep -qx "reinstall-called" "${UCI_FIXTURE_MARKER}" \
    && ! grep -qx "uninstall-called" "${UCI_FIXTURE_MARKER}" \
    && ! grep -qx "install-called" "${UCI_FIXTURE_MARKER}"; then
    pass "reinstall_tool() propia tiene prioridad sobre el fallback mecánico"
else
    fail "reinstall no priorizó reinstall_tool() propia. Marcador: $(cat "${UCI_FIXTURE_MARKER}")"
fi

echo ""
echo "== reinstall sin reinstall_tool() propia usa el fallback mecánico (uninstall + install) =="
NO_REINSTALL_FIXTURE="$(make_fixture '
check_status() { return 0; }
install_tool() { echo "install-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
uninstall_tool() { echo "uninstall-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
')"
: > "${UCI_FIXTURE_MARKER}"
set +e
bash "${NO_REINSTALL_FIXTURE}" reinstall > /dev/null 2>&1
code=$?
set -e
if [[ "${code}" -eq 0 ]] && grep -qx "uninstall-called" "${UCI_FIXTURE_MARKER}" && grep -qx "install-called" "${UCI_FIXTURE_MARKER}"; then
    pass "reinstall sin función propia cae al fallback mecánico (uninstall_tool + install_tool)"
else
    fail "el fallback mecánico de reinstall no se ejecutó correctamente. Marcador: $(cat "${UCI_FIXTURE_MARKER}" 2>/dev/null || echo '<vacío>')"
fi

echo ""
echo "== update/repair SIN función propia se rechazan explícitamente, nunca caen a reinstall =="
for verb in update repair; do
    : > "${UCI_FIXTURE_MARKER}"
    set +e
    OUTPUT="$(bash "${NO_REINSTALL_FIXTURE}" "${verb}" 2>&1)"
    code=$?
    set -e
    if [[ "${code}" -eq 3 ]]; then
        pass "'${verb}' sin implementación propia sale con código 3 (UNSUPPORTED)"
    else
        fail "'${verb}' sin implementación propia debería salir con código 3 (fue ${code})"
    fi
    if [[ "${OUTPUT}" == *"no implementa"* ]] || [[ "${OUTPUT}" == *"ADR 0029"* ]] || [[ "${OUTPUT}" == *"0029"* ]]; then
        pass "'${verb}' sin implementación imprime un mensaje explícito citando la limitación"
    else
        fail "'${verb}' no imprimió un mensaje explícito. Salida: ${OUTPUT}"
    fi
    if [[ -s "${UCI_FIXTURE_MARKER}" ]]; then
        fail "'${verb}' sin implementación propia no debería haber ejecutado ninguna función (marcador no vacío)"
    else
        pass "'${verb}' sin implementación propia no ejecuta ninguna función (nunca cae a reinstall)"
    fi
done

echo ""
echo "== comando desconocido: no ejecuta nada, sale con código de uso (1), imprime ayuda =="
: > "${UCI_FIXTURE_MARKER}"
set +e
OUTPUT="$(bash "${FULL_FIXTURE}" esto-no-existe 2>&1)"
code=$?
set -e
if [[ "${code}" -eq 1 ]]; then
    pass "comando desconocido sale con código 1"
else
    fail "comando desconocido debería salir con código 1 (fue ${code})"
fi
if [[ ! -s "${UCI_FIXTURE_MARKER}" ]]; then
    pass "comando desconocido no ejecuta ninguna acción por defecto"
else
    fail "comando desconocido ejecutó algo (marcador no vacío): $(cat "${UCI_FIXTURE_MARKER}")"
fi
if [[ "${OUTPUT}" == *"Uso:"* ]]; then
    pass "comando desconocido imprime un mensaje de uso"
else
    fail "comando desconocido no imprimió un mensaje de uso. Salida: ${OUTPUT}"
fi

echo ""
echo "== sin ningún argumento: no revienta con 'unbound variable', cae al mismo caso por defecto =="
set +e
OUTPUT="$(bash "${FULL_FIXTURE}" 2>&1)"
code=$?
set -e
if [[ "${code}" -eq 1 ]] && [[ "${OUTPUT}" == *"Uso:"* ]]; then
    pass "invocar sin argumentos no revienta bajo 'set -u'; cae al caso de uso inválido"
else
    fail "invocar sin argumentos no se comportó como se esperaba (código ${code}). Salida: ${OUTPUT}"
fi

echo ""
echo "== función obligatoria ausente: se detecta, código 2, no ejecuta nada =="
MISSING_INSTALL_FIXTURE="$(make_fixture '
check_status() { return 0; }
uninstall_tool() { echo "uninstall-called" >> "${UCI_FIXTURE_MARKER}"; return 0; }
')"
: > "${UCI_FIXTURE_MARKER}"
set +e
OUTPUT="$(bash "${MISSING_INSTALL_FIXTURE}" install 2>&1)"
code=$?
set -e
if [[ "${code}" -eq 2 ]]; then
    pass "'install' sin install_tool() definida sale con código 2 (función obligatoria ausente)"
else
    fail "'install' sin install_tool() debería salir con código 2 (fue ${code})"
fi
if [[ "${OUTPUT}" == *"install_tool"* ]]; then
    pass "el mensaje de error nombra la función obligatoria ausente"
else
    fail "el mensaje de error no menciona 'install_tool'. Salida: ${OUTPUT}"
fi
if [[ ! -s "${UCI_FIXTURE_MARKER}" ]]; then
    pass "ninguna función se ejecutó cuando falta una obligatoria"
else
    fail "se ejecutó algo pese a faltar una función obligatoria: $(cat "${UCI_FIXTURE_MARKER}")"
fi

echo ""
echo "== propagación de código de salida: el dispatcher no reescribe el código real =="
CUSTOM_CODE_FIXTURE="$(make_fixture '
check_status() { return 7; }
install_tool() { return 0; }
uninstall_tool() { return 0; }
')"
set +e
bash "${CUSTOM_CODE_FIXTURE}" status > /dev/null 2>&1
code=$?
set -e
if [[ "${code}" -eq 7 ]]; then
    pass "el código de salida 7 de check_status se propaga tal cual, sin reescribirse"
else
    fail "se esperaba código 7, se obtuvo ${code}"
fi

echo ""
echo "== ausencia de 'eval' en el código real de la biblioteca =="
# Se excluyen las líneas de comentario: el propio archivo documenta en
# prosa, más de una vez, que no usa eval — eso no debe confundirse con
# una instancia real (mismo criterio que tests/test_kernel_hwe_fallback.sh).
installer_cli_code_only() {
    grep -vE '^\s*#' "${INSTALLER_CLI_SH}"
}
if installer_cli_code_only | grep -qw 'eval'; then
    fail "installer_cli.sh usa 'eval' en código real"
else
    pass "installer_cli.sh no usa 'eval' en ningún código real"
fi

print_test_summary
exit_with_test_summary
