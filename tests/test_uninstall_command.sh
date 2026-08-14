#!/usr/bin/env bash
# tests/test_uninstall_command.sh
#
# Prueba simulada (mocks) del comando './setup.sh uninstall'.
#
# Es el primer comando del router capaz de DESINSTALAR software en lote,
# así que lo que más importa verificar no es que funcione, sino que no
# actúe cuando no debe: que `--dry-run` no toque nada, que sin
# confirmación explícita no toque nada, que un id mal escrito aborte
# ANTES de desinstalar algo, y que no intente quitar lo que no está
# instalado o cuyo estado no se pudo determinar.
#
# No desinstala nada real: los instaladores del catálogo se sustituyen por
# scripts falsos en una copia temporal del repo, que registran en un log
# lo que se les pidió.
#
# Uso:
#   bash tests/test_uninstall_command.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_FAKE_REPO=""
UCI_ACTION_LOG=""

# setup_fixture <estado_docker> <estado_steam> <estado_meld>
# Copia el repo a un directorio temporal y reemplaza SOLO los instaladores
# de tres herramientas conocidas por dobles que reportan el estado pedido
# y registran cada acción recibida.
setup_fixture() {
    local st_docker="$1" st_steam="$2" st_meld="$3"
    UCI_FAKE_REPO="$(mktemp -d)"
    UCI_ACTION_LOG="$(mktemp)"

    # Copia mínima: lo necesario para que setup.sh corra.
    cp "${UCI_REPO_ROOT}/setup.sh" "${UCI_FAKE_REPO}/"
    cp -r "${UCI_REPO_ROOT}/scripts" "${UCI_FAKE_REPO}/"

    _fake_installer "${UCI_FAKE_REPO}/scripts/development/install_docker.sh" "docker" "${st_docker}"
    _fake_installer "${UCI_FAKE_REPO}/scripts/productivity/install_steam.sh" "steam" "${st_steam}"
    _fake_installer "${UCI_FAKE_REPO}/scripts/system/install_meld.sh" "meld" "${st_meld}"
}

# _fake_installer <ruta> <etiqueta> <estado>
_fake_installer() {
    local path="$1" label="$2" status="$3"
    cat > "${path}" <<EOF
#!/usr/bin/env bash
echo "${label} \$*" >> "${UCI_ACTION_LOG}"
case "\$1" in
    status)
        echo "${status}"
        [[ "${status}" == "INSTALLED" || "${status}" == "OUTDATED" ]] && exit 0
        exit 1
        ;;
    uninstall)
        echo "${label} desinstalado (falso)"
        exit 0
        ;;
esac
exit 0
EOF
    chmod +x "${path}"
}

teardown_fixture() {
    rm -rf "${UCI_FAKE_REPO}"
    rm -f "${UCI_ACTION_LOG}"
}

# run_uninstall <entrada_stdin> [args...]
RUN_CODE=0
RUN_OUTPUT=""
run_uninstall() {
    local stdin_data="$1"
    shift
    set +e
    RUN_OUTPUT="$(printf '%s\n' "${stdin_data}" | bash "${UCI_FAKE_REPO}/setup.sh" uninstall "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

uninstalls_in_log() {
    grep -c " uninstall" "${UCI_ACTION_LOG}" 2>/dev/null || echo 0
}

echo "== 1. --dry-run no desinstala nada =="
setup_fixture "INSTALLED" "INSTALLED" "NOT_INSTALLED"
run_uninstall "" --tool docker,steam --dry-run
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "'--dry-run' no invocó 'uninstall' en ningún instalador"
else
    fail "'--dry-run' NO debe desinstalar nada. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"dry-run"* ]]; then
    pass "'--dry-run' informa qué se desinstalaría"
else
    fail "'--dry-run' debería informar el plan. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 2. sin confirmar ('no') no desinstala nada =="
setup_fixture "INSTALLED" "INSTALLED" "NOT_INSTALLED"
run_uninstall "no" --tool docker,steam
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "una respuesta distinta de 'si' cancela sin tocar nada"
else
    fail "sin confirmación explícita NO debe desinstalarse nada. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"Cancelado"* ]]; then
    pass "informa que se canceló"
else
    fail "debería informar la cancelación. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 3. Enter vacío tampoco desinstala =="
setup_fixture "INSTALLED" "INSTALLED" "NOT_INSTALLED"
run_uninstall "" --tool docker
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "una respuesta vacía no se interpreta como confirmación"
else
    fail "una respuesta vacía NO debe confirmar. Log: $(cat "${UCI_ACTION_LOG}")"
fi
teardown_fixture

echo ""
echo "== 4. confirmando con 'si' sí desinstala, y solo lo pedido =="
setup_fixture "INSTALLED" "INSTALLED" "INSTALLED"
run_uninstall "si" --tool docker,steam
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' confirmado sale con código 0"
else
    fail "debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "^docker uninstall" "${UCI_ACTION_LOG}" && grep -q "^steam uninstall" "${UCI_ACTION_LOG}"; then
    pass "desinstaló las dos herramientas pedidas"
else
    fail "debería desinstalar docker y steam. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if grep -q "^meld uninstall" "${UCI_ACTION_LOG}"; then
    fail "desinstaló 'meld', que NO se pidió. Log: $(cat "${UCI_ACTION_LOG}")"
else
    pass "no tocó ninguna herramienta que no se pidió"
fi
teardown_fixture

echo ""
echo "== 5. omite lo que no está instalado, sin fallar =="
setup_fixture "INSTALLED" "NOT_INSTALLED" "NOT_INSTALLED"
run_uninstall "si" --tool docker,steam
if grep -q "^docker uninstall" "${UCI_ACTION_LOG}"; then
    pass "desinstala lo que sí está instalado"
else
    fail "docker debería desinstalarse. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if grep -q "^steam uninstall" "${UCI_ACTION_LOG}"; then
    fail "intentó desinstalar 'steam' estando NOT_INSTALLED. Log: $(cat "${UCI_ACTION_LOG}")"
else
    pass "omite lo que ya no está instalado (nada que quitar)"
fi
teardown_fixture

echo ""
echo "== 6. no actúa sobre un estado que no se pudo determinar (UNKNOWN) =="
# Mismo criterio que el skip por UNKNOWN del flujo interactivo: no se toca
# el sistema sin saber en qué estado está.
setup_fixture "UNKNOWN" "UNSUPPORTED" "NOT_INSTALLED"
run_uninstall "si" --tool docker,steam
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "no desinstala nada con estado UNKNOWN/UNSUPPORTED"
else
    fail "no debe actuar a ciegas sobre un estado no determinable. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"omite"* ]]; then
    pass "explica que lo omitió en vez de callarlo"
else
    fail "debería explicar por qué omite. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 7. un id desconocido aborta ANTES de desinstalar algo =="
# Es preferible fallar de entrada por un id mal escrito a desinstalar la
# mitad de la lista y recién ahí descubrir el error.
setup_fixture "INSTALLED" "INSTALLED" "INSTALLED"
run_uninstall "si" --tool docker,noexiste
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "un id desconocido hace fallar el comando"
else
    fail "debería fallar con un id desconocido (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "no desinstaló NADA antes de detectar el id inválido"
else
    fail "no debe desinstalar nada si algún id es inválido. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"noexiste"* ]]; then
    pass "nombra el id inválido en el error"
else
    fail "debería nombrar el id inválido. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 8. advierte de los efectos no reversibles antes de confirmar =="
setup_fixture "INSTALLED" "INSTALLED" "NOT_INSTALLED"
run_uninstall "no" --tool docker
if [[ "${RUN_OUTPUT}" == *"purge"* ]]; then
    pass "avisa que 'uninstall' hace purge, no remove"
else
    fail "debería avisar del purge. Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" == *"i386"* || "${RUN_OUTPUT}" == *"no se revierten"* || "${RUN_OUTPUT}" == *"NO se revierten"* ]]; then
    pass "avisa de los efectos que no se revierten"
else
    fail "debería avisar de lo que no se revierte. Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" == *"DATOS se conservan"* || "${RUN_OUTPUT}" == *"datos"* ]]; then
    pass "aclara que los datos del usuario se conservan"
else
    fail "debería aclarar qué pasa con los datos. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 9. modo interactivo: lista solo lo instalado y respeta la cancelación =="
setup_fixture "INSTALLED" "NOT_INSTALLED" "NOT_INSTALLED"
run_uninstall "q"
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "'q' cancela el modo interactivo sin tocar nada"
else
    fail "'q' debe cancelar. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_OUTPUT}" == *"docker"* ]]; then
    pass "el listado interactivo incluye la herramienta instalada"
else
    fail "el listado debería incluir docker. Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" != *"steam"* ]]; then
    pass "el listado NO incluye lo que no está instalado"
else
    fail "el listado no debería incluir steam (NOT_INSTALLED). Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 10. modo interactivo: un número fuera de rango no desinstala nada =="
setup_fixture "INSTALLED" "INSTALLED" "INSTALLED"
run_uninstall "9999"
if [[ "$(uninstalls_in_log)" -eq 0 ]]; then
    pass "un número fuera de rango no desinstala nada"
else
    fail "no debe actuar con una selección inválida. Log: $(cat "${UCI_ACTION_LOG}")"
fi
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "una selección inválida hace fallar el comando"
else
    fail "debería fallar con una selección fuera de rango (código ${RUN_CODE})"
fi
teardown_fixture

print_test_summary
exit_with_test_summary
