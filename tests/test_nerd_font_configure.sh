#!/usr/bin/env bash
# tests/test_nerd_font_configure.sh
#
# Prueba simulada (mocks) del verbo `configure` de Powerlevel10k y
# Starship (Hito 54, ver docs/ROADMAP.md): ambos instalan la Nerd Font
# MesloLGS NF vía scripts/lib/nerd_font.sh, la biblioteca compartida que
# se extrajo justamente porque son dos casos reales idénticos (ADR 0032).
#
# No descarga nada real ni toca el HOME real: `curl` y `fc-cache` se
# interceptan en un PATH temporal y `$HOME` apunta a un directorio
# temporal (mismo criterio que tests/test_powerlevel10k_dependency.sh).
#
# El verbo `configure` es el 7° del contrato (ADR 0042) y hasta ahora
# solo lo implementaba Flameshot; este test cubre los dos consumidores
# nuevos, incluyendo el rechazo cuando la herramienta no está instalada
# y la idempotencia — los dos criterios que fijó Flameshot.
#
# Uso:
#   bash tests/test_nerd_font_configure.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

readonly UCI_FONT_FILES=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_TEST_HOME=""

# setup_mocks [<curl_falla: no|si>]
setup_mocks() {
    local curl_falla="${1:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_TEST_HOME="$(mktemp -d)"

    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
if [[ "${curl_falla}" == "si" ]]; then
    exit 22
fi
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then
        echo "fake-ttf-bytes" > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    cat > "${UCI_MOCK_BIN}/fc-cache" <<EOF
#!/usr/bin/env bash
echo "fc-cache \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/fc-cache"

    # apt-get/dpkg/git/zsh: los instaladores los tocan en otros verbos;
    # acá solo interesa 'configure', pero deben existir para que el
    # sourceo y check_status no exploten.
    for cmd in apt-get dpkg git; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mocks() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_TEST_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# fuentes_presentes: 0 si están los 4 archivos en el HOME simulado
fuentes_presentes() {
    local f
    for f in "${UCI_FONT_FILES[@]}"; do
        [[ -f "${UCI_TEST_HOME}/.local/share/fonts/${f}" ]] || return 1
    done
    return 0
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

# simular_p10k_instalado: Powerlevel10k está instalado si existe zsh y el
# directorio del tema es un repo git válido (lo único que mira
# git_clone_present).
simular_p10k_instalado() {
    mkdir -p "${UCI_TEST_HOME}/.oh-my-zsh/custom/themes/powerlevel10k/.git"
    cat > "${UCI_MOCK_BIN}/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/zsh"
}

# simular_starship_instalado: basta con que el binario resuelva en PATH.
simular_starship_instalado() {
    cat > "${UCI_MOCK_BIN}/starship" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/starship"
}

# ---------------------------------------------------------------------

test_configure() {
    local script="$1" nombre="$2" simular_fn="$3"

    echo ""
    echo "== ${nombre}: verbo 'configure' =="

    # 1. Rechazo si la herramienta no está instalada (criterio Flameshot)
    setup_mocks
    run_installer "${script}" "configure"
    if [[ "${RUN_CODE}" -ne 0 && "${RUN_OUTPUT}" == *"install"* ]]; then
        pass "${nombre}: 'configure' rechaza y pide 'install' si la herramienta no está instalada"
    else
        fail "${nombre}: 'configure' debería rechazar si no está instalada (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if [[ -d "${UCI_TEST_HOME}/.local/share/fonts" ]]; then
        fail "${nombre}: no debería crear el directorio de fuentes si rechazó"
    else
        pass "${nombre}: no instala la fuente cuando rechaza (no deja basura)"
    fi
    teardown_mocks

    # 2. Instala las cuatro variantes y refresca el cache
    setup_mocks
    "${simular_fn}"
    run_installer "${script}" "configure"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "${nombre}: 'configure' sale con código 0 con la herramienta instalada"
    else
        fail "${nombre}: 'configure' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if fuentes_presentes; then
        pass "${nombre}: instala las CUATRO variantes (Regular/Bold/Italic/Bold Italic)"
    else
        fail "${nombre}: faltan variantes de la fuente en ~/.local/share/fonts"
    fi
    if grep -q "powerlevel10k-media/raw/master/MesloLGS%20NF" "${UCI_MOCK_LOG}"; then
        pass "${nombre}: descarga desde el repositorio oficial, con el nombre URL-codificado"
    else
        fail "${nombre}: no descargó desde la URL oficial esperada. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if grep -q "fc-cache -f" "${UCI_MOCK_LOG}"; then
        pass "${nombre}: refresca el cache de fuentes con 'fc-cache'"
    else
        fail "${nombre}: no refrescó el cache. Log: $(cat "${UCI_MOCK_LOG}")"
    fi
    if [[ "${RUN_OUTPUT}" == *"MesloLGS NF"* && "${RUN_OUTPUT}" == *"terminal"* ]]; then
        pass "${nombre}: informa el paso manual de configurar la terminal (fuera de alcance a propósito)"
    else
        fail "${nombre}: debería informar el paso manual restante. Salida: ${RUN_OUTPUT}"
    fi
    teardown_mocks

    # 3. Idempotencia (criterio Flameshot): no vuelve a descargar
    setup_mocks
    "${simular_fn}"
    mkdir -p "${UCI_TEST_HOME}/.local/share/fonts"
    for f in "${UCI_FONT_FILES[@]}"; do
        echo ya-estaba > "${UCI_TEST_HOME}/.local/share/fonts/${f}"
    done
    run_installer "${script}" "configure"
    if [[ "${RUN_CODE}" -eq 0 ]]; then
        pass "${nombre}: 'configure' vuelve a salir con 0 si la fuente ya estaba"
    else
        fail "${nombre}: segunda corrida debería salir con 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
    fi
    if grep -q "curl" "${UCI_MOCK_LOG}"; then
        fail "${nombre}: NO debería volver a descargar si la fuente ya está (idempotencia). Log: $(cat "${UCI_MOCK_LOG}")"
    else
        pass "${nombre}: es idempotente — no vuelve a descargar la fuente ya instalada"
    fi
    if [[ "$(cat "${UCI_TEST_HOME}/.local/share/fonts/MesloLGS NF Regular.ttf")" == "ya-estaba" ]]; then
        pass "${nombre}: no sobrescribe los archivos existentes"
    else
        fail "${nombre}: sobrescribió una fuente que ya estaba instalada"
    fi
    teardown_mocks

    # 4. Instalación parcial: se completan las variantes faltantes
    setup_mocks
    "${simular_fn}"
    mkdir -p "${UCI_TEST_HOME}/.local/share/fonts"
    echo parcial > "${UCI_TEST_HOME}/.local/share/fonts/MesloLGS NF Regular.ttf"
    run_installer "${script}" "configure"
    if [[ "${RUN_CODE}" -eq 0 ]] && fuentes_presentes; then
        pass "${nombre}: completa una instalación parcial (se exige el set de 4, no solo Regular)"
    else
        fail "${nombre}: no completó la instalación parcial (código ${RUN_CODE})"
    fi
    teardown_mocks

    # 5. Un fallo real de descarga se propaga
    setup_mocks "si"
    "${simular_fn}"
    run_installer "${script}" "configure"
    if [[ "${RUN_CODE}" -ne 0 ]]; then
        pass "${nombre}: un fallo real de descarga se propaga como código distinto de cero"
    else
        fail "${nombre}: un fallo de curl debería propagarse (código ${RUN_CODE})"
    fi
    teardown_mocks
}

test_configure "scripts/system/install_powerlevel10k.sh" "Powerlevel10k" "simular_p10k_instalado"
test_configure "scripts/system/install_starship.sh" "Starship" "simular_starship_instalado"

print_test_summary
exit_with_test_summary
