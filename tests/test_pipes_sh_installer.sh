#!/usr/bin/env bash
# tests/test_pipes_sh_installer.sh
#
# Prueba simulada (mocks) de scripts/system/install_pipes_sh.sh (Hito
# 47, ver docs/ROADMAP.md). No instala nada real: apt-get/dpkg/sudo/git/
# make se interceptan con comandos falsos en un PATH temporal; `$HOME`
# apuntado a un directorio temporal (mismo criterio que
# tests/test_powerlevel10k_dependency.sh). El mock de `git clone` crea
# el directorio destino con un `.git` (lo único que revisa
# `git_clone_present`); el mock de `make` simula el target `install`
# creando el binario ejecutable en `$PREFIX/bin/pipes.sh` (parseando el
# argumento `PREFIX=...`), y el target `uninstall` lo elimina.
#
# Uso:
#   bash tests/test_pipes_sh_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_pipes_sh.sh"
readonly INSTALL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""
UCI_TEST_HOME=""

# setup_mock_bin <cloned: yes|no> <installed: yes|no>
# <cloned>: si "yes", pre-crea ~/.local/share/pipes.sh/.git antes de correr.
# <installed>: si "yes", pre-crea el binario ~/.local/bin/pipes.sh antes de correr.
setup_mock_bin() {
    local cloned="${1:-no}" installed="${2:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"
    UCI_TEST_HOME="$(mktemp -d)"

    for cmd in apt-get dpkg sudo; do
        cat > "${UCI_MOCK_BIN}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${UCI_MOCK_LOG}"
"\$@" 2>/dev/null || true
exit 0
EOF
        chmod +x "${UCI_MOCK_BIN}/${cmd}"
    done
    # sudo real: passthrough (no privilegios reales, mismo criterio que otros tests).
    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    cat > "${UCI_MOCK_BIN}/git" <<EOF
#!/usr/bin/env bash
echo "git \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "clone" ]]; then
    dest="\${@: -1}"
    mkdir -p "\${dest}/.git"
    exit 0
fi
if [[ "\$1" == "-C" ]]; then
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/git"

    cat > "${UCI_MOCK_BIN}/make" <<EOF
#!/usr/bin/env bash
echo "make \$*" >> "${UCI_MOCK_LOG}"
prefix=""
target=""
for arg in "\$@"; do
    case "\$arg" in
        PREFIX=*) prefix="\${arg#PREFIX=}" ;;
        install|uninstall) target="\$arg" ;;
    esac
done
if [[ "\$target" == "install" ]]; then
    mkdir -p "\${prefix}/bin"
    cat > "\${prefix}/bin/pipes.sh" <<'INNER'
#!/usr/bin/env bash
exit 0
INNER
    chmod +x "\${prefix}/bin/pipes.sh"
elif [[ "\$target" == "uninstall" ]]; then
    rm -f "\${prefix}/bin/pipes.sh"
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/make"

    if [[ "${cloned}" == "yes" ]]; then
        mkdir -p "${UCI_TEST_HOME}/.local/share/pipes.sh/.git"
    fi
    if [[ "${installed}" == "yes" ]]; then
        mkdir -p "${UCI_TEST_HOME}/.local/bin"
        cat > "${UCI_TEST_HOME}/.local/bin/pipes.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
        chmod +x "${UCI_TEST_HOME}/.local/bin/pipes.sh"
    fi
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_TEST_HOME}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <accion> <cloned> <installed>
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" cloned="${2:-no}" installed="${3:-no}"
    setup_mock_bin "${cloned}" "${installed}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${UCI_TEST_HOME}/.local/bin:${PATH}" HOME="${UCI_TEST_HOME}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. install: clona el repo y corre 'make install' con PREFIX=\$HOME/.local =="
run_installer "install" "no" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "git clone" "${UCI_MOCK_LOG}"; then
    pass "'install' clona el repositorio oficial"
else
    fail "'install' no clonó el repositorio. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -qE "make.*PREFIX=.*/\.local install" "${UCI_MOCK_LOG}"; then
    pass "'install' corre 'make install' con PREFIX=\$HOME/.local"
else
    fail "'install' no corrió 'make install' esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 3. status con el binario y el clon presentes: INSTALLED =="
run_installer "status" "yes" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED"
else
    fail "'status' no reportó INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. status con binario presente pero clon corrupto/ausente: BROKEN =="
run_installer "status" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si el clon no es un repositorio Git válido"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. install rechaza si ya está instalado (sugiere 'update') =="
run_installer "install" "yes" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"update"* ]]; then
    pass "'install' rechaza y sugiere 'update' si ya está instalado"
else
    fail "'install' debería rechazar si ya está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. install rechaza si está BROKEN (sugiere 'repair') =="
run_installer "install" "no" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. uninstall corre 'make uninstall' y elimina el clon =="
run_installer "uninstall" "yes" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "make.*uninstall" "${UCI_MOCK_LOG}" && [[ ! -d "${UCI_TEST_HOME}/.local/share/pipes.sh" ]]; then
    pass "'uninstall' corre 'make uninstall' y elimina el directorio clonado"
else
    fail "'uninstall' no se comportó como se esperaba. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 8. update hace 'git pull' y vuelve a correr 'make install' =="
run_installer "update" "yes" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "git -C" "${UCI_MOCK_LOG}" && grep -qE "make.*install" "${UCI_MOCK_LOG}"; then
    pass "'update' hace 'git pull' y vuelve a correr 'make install'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 9. update rechaza si no está instalado =="
run_installer "update" "no" "no"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'update' rechaza si no está instalado"
else
    fail "'update' debería rechazar si no está instalado"
fi
teardown_mock_bin

echo ""
echo "== 10. repair re-clona y vuelve a correr 'make install' =="
run_installer "repair" "no" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q "git clone" "${UCI_MOCK_LOG}" && grep -qE "make.*install" "${UCI_MOCK_LOG}"; then
    pass "'repair' re-clona el repositorio y vuelve a correr 'make install'"
else
    fail "'repair' no ejecutó los pasos esperados. Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
