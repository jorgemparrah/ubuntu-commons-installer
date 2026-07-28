#!/usr/bin/env bash
# tests/test_local_ai_ui_installers.sh
#
# Prueba simulada (mocks) de los tres instaladores de interfaces locales
# de IA del Hito 53 (ver
# docs/adr/0046-mecanismos-para-interfaces-locales-de-ia.md):
#
#   - AnythingLLM  — manager=curl-script (mecanismo ya existente)
#   - Open WebUI   — manager=pip-mise    (mecanismo nuevo, único caso)
#   - LM Studio    — manager=appimage-direct (mecanismo nuevo, único caso)
#
# Los tres se agrupan en un solo archivo porque comparten el mismo
# escenario de mockeo (`$HOME` a un directorio temporal, sin red) pero
# NO comparten mecanismo — de ahí que cada uno tenga su propia función de
# contrato en vez de una parametrizada, a diferencia de
# tests/test_flatpak_installers_contract.sh.
#
# No instala nada real ni toca el HOME real: curl/mise/apt-get/sudo se
# interceptan en un PATH temporal y $HOME apunta a un directorio
# temporal (mismo criterio que tests/test_curl_script_contract.sh).
#
# Uso:
#   bash tests/test_local_ai_ui_installers.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_TEST_HOME=""

# ---------------------------------------------------------------------
# Infraestructura común de mocks
# ---------------------------------------------------------------------

# setup_common_mocks
# apt-get/dpkg/sudo falsos. 'sudo' emula las asignaciones de entorno
# previas al comando (mismo patrón que test_split_installers_contract.sh).
setup_common_mocks() {
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_TEST_HOME="$(mktemp -d)"

    for cmd in apt-get dpkg; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done

    cat > "${UCI_MOCK_BIN}/sudo" <<EOF
#!/usr/bin/env bash
echo "sudo \$*" >> "${UCI_MOCK_LOG}"
while [[ "\$#" -gt 0 && "\$1" == *=* && "\$1" != -* ]]; do
    export "\$1"
    shift
done
"\$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mocks() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_TEST_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local script="$1" action="$2"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" HOME="${UCI_TEST_HOME}" \
        bash "${UCI_REPO_ROOT}/${script}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

# ---------------------------------------------------------------------
# AnythingLLM — manager=curl-script
# ---------------------------------------------------------------------

# El mock de 'curl' escribe un "installer.sh" falso que replica lo único
# que le importa a este instalador del script oficial: crear el AppImage
# ejecutable dentro de ANYTHING_LLM_INSTALL_DIR.
setup_anythingllm_mocks() {
    setup_common_mocks
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then
        {
            echo '#!/bin/sh'
            echo 'DEST="\${ANYTHING_LLM_INSTALL_DIR:-\$HOME}"'
            echo 'mkdir -p "\$DEST"'
            echo 'echo fake-appimage > "\$DEST/AnythingLLMDesktop.AppImage"'
            echo 'chmod +x "\$DEST/AnythingLLMDesktop.AppImage"'
            echo 'mkdir -p "\$HOME/.local/share/applications"'
            echo 'touch "\$HOME/.local/share/applications/anythingllmdesktop.desktop"'
        } > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"
}

test_anythingllm() {
    local script="scripts/development/install_anythingllm.sh"
    local appimage_rel=".local/share/anythingllm/AnythingLLMDesktop.AppImage"

    echo ""
    echo "== AnythingLLM (curl-script) =="

    setup_anythingllm_mocks
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "AnythingLLM: estado inicial reporta NOT_INSTALLED"
    else
        fail "AnythingLLM: estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    setup_anythingllm_mocks
    run_installer "${script}" "install"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "AnythingLLM: 'install' sale con código 0"
    else
        fail "AnythingLLM: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "curl .*releases/latest/download/installer.sh" "${UCI_MOCK_LOG}"; then
        pass "AnythingLLM: 'install' descarga el installer.sh oficial del release"
    else
        fail "AnythingLLM: no descargó el installer.sh esperado. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if [[ -x "${UCI_TEST_HOME}/${appimage_rel}" ]]; then
        pass "AnythingLLM: el AppImage queda en ~/.local/share/anythingllm (no suelto en \$HOME)"
    else
        fail "AnythingLLM: el AppImage no quedó en la ruta esperada"
    fi
    teardown_mocks

    # status INSTALLED / BROKEN
    setup_anythingllm_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/anythingllm"
    echo fake > "${UCI_TEST_HOME}/${appimage_rel}"
    chmod +x "${UCI_TEST_HOME}/${appimage_rel}"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "AnythingLLM: 'status' reporta INSTALLED"
    else
        fail "AnythingLLM: 'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    run_installer "${script}" "install"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"update"* ]]; then
        pass "AnythingLLM: 'install' rechaza y sugiere 'update' si ya está instalado"
    else
        fail "AnythingLLM: 'install' debería rechazar si ya está instalado. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    setup_anythingllm_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/anythingllm"
    echo fake > "${UCI_TEST_HOME}/${appimage_rel}"
    chmod -x "${UCI_TEST_HOME}/${appimage_rel}"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "AnythingLLM: 'status' reporta BROKEN si el AppImage no es ejecutable"
    else
        fail "AnythingLLM: 'status' no reportó BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    run_installer "${script}" "repair"
    if [[ "${RUN_CODE}" -eq 0 && -x "${UCI_TEST_HOME}/${appimage_rel}" ]]; then
        pass "AnythingLLM: 'repair' restaura el permiso de ejecución"
    else
        fail "AnythingLLM: 'repair' no restauró el permiso (código ${RUN_CODE})"
    fi
    teardown_mocks

    setup_anythingllm_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/anythingllm" "${UCI_TEST_HOME}/.config/anythingllm-desktop"
    echo fake > "${UCI_TEST_HOME}/${appimage_rel}"
    chmod +x "${UCI_TEST_HOME}/${appimage_rel}"
    run_installer "${script}" "uninstall"
    if [[ "${RUN_CODE}" -eq 0 && ! -d "${UCI_TEST_HOME}/.local/share/anythingllm" ]]; then
        pass "AnythingLLM: 'uninstall' elimina el directorio de instalación"
    else
        fail "AnythingLLM: 'uninstall' no eliminó el directorio (código ${RUN_CODE})"
    fi
    if [[ -d "${UCI_TEST_HOME}/.config/anythingllm-desktop" ]]; then
        pass "AnythingLLM: 'uninstall' NO borra los datos del usuario (AGENT.md §2)"
    else
        fail "AnythingLLM: 'uninstall' no debería borrar ~/.config/anythingllm-desktop"
    fi
    teardown_mocks
}

# ---------------------------------------------------------------------
# Open WebUI — manager=pip-mise
# ---------------------------------------------------------------------

# setup_openwebui_mocks <mise: presente|ausente> <pip_show: ok|fail>
# El mock de 'mise' cubre las tres formas en que lo usa el instalador:
# 'exec python@X -- pip ...', 'install python@X' y 'reshim'.
setup_openwebui_mocks() {
    local mise="${1:-presente}" pip_show="${2:-fail}"
    setup_common_mocks

    if [[ "${mise}" == "presente" ]]; then
        mkdir -p "${UCI_TEST_HOME}/.local/bin"
        cat > "${UCI_TEST_HOME}/.local/bin/mise" <<EOF
#!/usr/bin/env bash
echo "mise \$*" >> "${UCI_MOCK_LOG}"
# 'mise exec python@3.11 -- pip show open-webui'
for arg in "\$@"; do
    if [[ "\${arg}" == "show" ]]; then
        [[ "${pip_show}" == "ok" ]] && exit 0
        exit 1
    fi
done
exit 0
EOF
        chmod +x "${UCI_TEST_HOME}/.local/bin/mise"
    fi
}

test_open_webui() {
    local script="scripts/development/install_open_webui.sh"

    echo ""
    echo "== Open WebUI (pip-mise) =="

    setup_openwebui_mocks "ausente"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == "UNKNOWN" ]]; then
        pass "Open WebUI: Mise ausente -> UNKNOWN (no se confunde con NOT_INSTALLED)"
    else
        fail "Open WebUI: Mise ausente debería dar UNKNOWN. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "fail"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "Open WebUI: Mise presente y paquete ausente -> NOT_INSTALLED"
    else
        fail "Open WebUI: debería dar NOT_INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "ok"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -eq 0 && "${RUN_OUTPUT}" == *"INSTALLED"* && "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
        pass "Open WebUI: paquete presente -> INSTALLED"
    else
        fail "Open WebUI: debería dar INSTALLED. Obtenido: '${RUN_OUTPUT}' (código ${RUN_CODE})"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "fail"
    run_installer "${script}" "install"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "Open WebUI: 'install' sale con código 0"
    else
        fail "Open WebUI: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "mise install python@3.11" "${UCI_MOCK_LOG}"; then
        pass "Open WebUI: 'install' fija Python 3.11 vía Mise (no usa el del sistema)"
    else
        fail "Open WebUI: no instaló Python 3.11 vía Mise. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if grep -q "exec python@3.11 -- pip install --upgrade open-webui" "${UCI_MOCK_LOG}"; then
        pass "Open WebUI: 'install' corre pip sobre el Python de Mise"
    else
        fail "Open WebUI: no corrió pip sobre el Python de Mise. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if grep -q "mise reshim" "${UCI_MOCK_LOG}"; then
        pass "Open WebUI: 'install' corre 'reshim' (si no, el ejecutable no queda en el PATH)"
    else
        fail "Open WebUI: no corrió 'reshim'. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if [[ "${RUN_OUTPUT}" == *"open-webui serve"* ]]; then
        pass "Open WebUI: informa cómo arrancar el servicio (el instalador no lo gestiona)"
    else
        fail "Open WebUI: debería informar cómo arrancar el servicio. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "ok"
    run_installer "${script}" "uninstall"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "pip uninstall -y open-webui" "${UCI_MOCK_LOG}"; then
        pass "Open WebUI: 'uninstall' desinstala el paquete vía pip"
    else
        fail "Open WebUI: 'uninstall' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "ok"
    run_installer "${script}" "update"
    if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "pip install --upgrade open-webui" "${UCI_MOCK_LOG}"; then
        pass "Open WebUI: 'update' reinstala con '--upgrade'"
    else
        fail "Open WebUI: 'update' no se comportó como se esperaba (código ${RUN_CODE})"
    fi
    teardown_mocks

    setup_openwebui_mocks "presente" "ok"
    run_installer "${script}" "repair"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "Open WebUI: 'repair' se rechaza explícitamente (no implementado a propósito)"
    else
        fail "Open WebUI: 'repair' debería rechazarse (código ${RUN_CODE})"
    fi
    teardown_mocks
}

# ---------------------------------------------------------------------
# LM Studio — manager=appimage-direct
# ---------------------------------------------------------------------

setup_lmstudio_mocks() {
    setup_common_mocks
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then
        echo "fake-lmstudio-appimage" > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"
}

test_lmstudio() {
    local script="scripts/development/install_lmstudio.sh"
    local appimage="${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"

    echo ""
    echo "== LM Studio (appimage-direct) =="

    setup_lmstudio_mocks
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
        pass "LM Studio: estado inicial reporta NOT_INSTALLED"
    else
        fail "LM Studio: estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    setup_lmstudio_mocks
    run_installer "${script}" "install"
    appimage="${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "LM Studio: 'install' sale con código 0"
    else
        fail "LM Studio: 'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "apt-get install -y libfuse2" "${UCI_MOCK_LOG}"; then
        pass "LM Studio: 'install' instala libfuse2 (Ubuntu 24.04+ ya no lo trae y el AppImage lo necesita)"
    else
        fail "LM Studio: no instaló libfuse2. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if grep -q "curl .*lmstudio.ai/download/latest/linux/x64" "${UCI_MOCK_LOG}"; then
        pass "LM Studio: 'install' descarga desde la URL estable de última versión"
    else
        fail "LM Studio: no usó la URL estable esperada. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if [[ -x "${appimage}" ]]; then
        pass "LM Studio: el AppImage queda instalado y ejecutable"
    else
        fail "LM Studio: el AppImage no quedó ejecutable en la ruta esperada"
    fi
    if [[ -f "${UCI_TEST_HOME}/.local/share/applications/lmstudio.desktop" ]]; then
        pass "LM Studio: 'install' crea el .desktop (integración con el escritorio)"
    else
        fail "LM Studio: no creó el .desktop"
    fi
    teardown_mocks

    # BROKEN: AppImage presente sin permiso de ejecución
    setup_lmstudio_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/lmstudio"
    echo fake > "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    chmod -x "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "LM Studio: 'status' reporta BROKEN si el AppImage no es ejecutable"
    else
        fail "LM Studio: 'status' no reportó BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    run_installer "${script}" "repair"
    if [[ "${RUN_CODE}" -eq 0 ]] \
        && [[ -x "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage" ]] \
        && [[ -f "${UCI_TEST_HOME}/.local/share/applications/lmstudio.desktop" ]]; then
        pass "LM Studio: 'repair' restaura permisos y rehace el .desktop"
    else
        fail "LM Studio: 'repair' no restauró el estado esperado (código ${RUN_CODE})"
    fi
    teardown_mocks

    # BROKEN por .desktop faltante, aunque el AppImage esté bien
    setup_lmstudio_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/lmstudio"
    echo fake > "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    chmod +x "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    run_installer "${script}" "status"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
        pass "LM Studio: 'status' reporta BROKEN si falta el .desktop"
    else
        fail "LM Studio: 'status' debería reportar BROKEN sin .desktop. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    setup_lmstudio_mocks
    mkdir -p "${UCI_TEST_HOME}/.local/share/lmstudio" "${UCI_TEST_HOME}/.lmstudio"
    echo fake > "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    chmod +x "${UCI_TEST_HOME}/.local/share/lmstudio/LM-Studio.AppImage"
    run_installer "${script}" "uninstall"
    if [[ "${RUN_CODE}" -eq 0 && ! -d "${UCI_TEST_HOME}/.local/share/lmstudio" ]]; then
        pass "LM Studio: 'uninstall' elimina el AppImage y su directorio"
    else
        fail "LM Studio: 'uninstall' no eliminó el directorio (código ${RUN_CODE})"
    fi
    if [[ -d "${UCI_TEST_HOME}/.lmstudio" ]]; then
        pass "LM Studio: 'uninstall' NO borra los modelos del usuario (AGENT.md §2)"
    else
        fail "LM Studio: 'uninstall' no debería borrar ~/.lmstudio"
    fi
    if grep -q "apt-get purge.*libfuse2" "${UCI_MOCK_LOG}"; then
        fail "LM Studio: 'uninstall' no debería purgar libfuse2 (otros AppImage pueden depender de él)"
    else
        pass "LM Studio: 'uninstall' no purga libfuse2 (compartido con otros AppImage)"
    fi
    teardown_mocks

    setup_lmstudio_mocks
    run_installer "${script}" "update"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "LM Studio: 'update' rechaza si no está instalado"
    else
        fail "LM Studio: 'update' debería rechazar si no está instalado"
    fi
    teardown_mocks

    setup_lmstudio_mocks
    run_installer "${script}" "esto-no-existe"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "LM Studio: subcomando inválido sale con código distinto de cero"
    else
        fail "LM Studio: subcomando inválido debería fallar"
    fi
    teardown_mocks
}

test_anythingllm
test_open_webui
test_lmstudio

echo ""
echo "Nota: ninguno de los tres se prueba funcionalmente en CI — Open WebUI"
echo "requeriría descargar un runtime completo de Python, y AnythingLLM/LM"
echo "Studio son AppImages GUI que necesitan FUSE y un escritorio real."

print_test_summary
exit_with_test_summary
