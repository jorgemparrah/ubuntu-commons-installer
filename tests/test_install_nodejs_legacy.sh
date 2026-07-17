#!/usr/bin/env bash
# tests/test_install_nodejs_legacy.sh
#
# Prueba de Nivel 1 (segura en cualquier máquina, no instala nada real):
# confirma que scripts/development/install_nodejs.sh (legado/deprecado) no
# puede borrar ~/.nvm ni modificar los archivos de shell bajo ninguna
# circunstancia — ni siquiera con variables de entorno. Ver
# docs/adr/0003-migracion-nvm-sin-borrado-directo.md y la fase de cierre
# del Hito 7 (docs/ROADMAP.md).
#
# Usa un HOME temporal con un ~/.nvm y archivos de shell de prueba; nunca
# toca el $HOME real.
#
# Uso:
#   bash tests/test_install_nodejs_legacy.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_NODEJS_SH="${UCI_REPO_ROOT}/scripts/development/install_nodejs.sh"
readonly INSTALL_NODEJS_SH

UCI_TESTS_RUN=0
UCI_TESTS_FAILED=0

pass() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    echo "  OK  - $1"
}

fail() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    UCI_TESTS_FAILED=$((UCI_TESTS_FAILED + 1))
    echo "FALLO - $1"
}

# fake_home_hash <dir>
# Hash del contenido completo de un directorio (rutas + contenido), para
# detectar cualquier modificación, no solo la cantidad de archivos.
fake_home_hash() {
    local dir="$1"
    find "${dir}" -type f -exec sha256sum {} \; | sort | sha256sum
}

setup_fake_home() {
    local home_dir="$1"
    mkdir -p "${home_dir}/.nvm/versions/node/v18.20.8/lib/node_modules"
    echo "contenido de prueba de un binario de node" > "${home_dir}/.nvm/versions/node/v18.20.8/bin_falso"
    echo '{"version":"1.0.0"}' > "${home_dir}/.nvm/versions/node/v18.20.8/lib/node_modules/package.json"

    cat > "${home_dir}/.bashrc" <<'EOF'
# .bashrc de prueba
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
echo "linea que no debe tocarse, aunque mencione nvm de forma ambigua"
EOF
    cat > "${home_dir}/.zshrc" <<'EOF'
# .zshrc de prueba
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF
    cat > "${home_dir}/.profile" <<'EOF'
# .profile de prueba
export NVM_DIR="$HOME/.nvm"
EOF
}

# assert_action_refused <accion> [env_extra...]
# Corre install_nodejs.sh <accion> contra un HOME temporal recién armado,
# con cualquier variable de entorno adicional que se le pase, y confirma
# que se niega a operar y que el HOME queda byte a byte idéntico.
assert_action_refused() {
    local action="$1"
    shift
    local extra_env=("$@")

    local tmp_home
    tmp_home="$(mktemp -d)"
    setup_fake_home "${tmp_home}"
    local hash_before
    hash_before="$(fake_home_hash "${tmp_home}")"

    local output
    local exit_code=0
    output="$(HOME="${tmp_home}" env "${extra_env[@]}" "${INSTALL_NODEJS_SH}" "${action}" 2>&1)" || exit_code=$?

    if [[ "${exit_code}" -eq 0 ]]; then
        fail "'install_nodejs.sh ${action}' (env: ${extra_env[*]:-ninguna}) debería salir con código distinto de cero"
    else
        pass "'install_nodejs.sh ${action}' (env: ${extra_env[*]:-ninguna}) sale con código distinto de cero"
    fi

    if [[ "${output}" == *"deshabilitada"* || "${output}" == *"deprecado"* || "${output}" == *"migrate"* ]]; then
        pass "'install_nodejs.sh ${action}' muestra un mensaje claro (menciona migrate/Mise)"
    else
        fail "'install_nodejs.sh ${action}' no mostró el mensaje esperado. Salida: ${output}"
    fi

    if [[ -d "${tmp_home}/.nvm" ]]; then
        pass "'install_nodejs.sh ${action}' no eliminó ~/.nvm"
    else
        fail "'install_nodejs.sh ${action}' eliminó ~/.nvm"
    fi

    local hash_after
    hash_after="$(fake_home_hash "${tmp_home}")"
    if [[ "${hash_after}" == "${hash_before}" ]]; then
        pass "'install_nodejs.sh ${action}' no modificó ni un byte del HOME de prueba (.nvm ni archivos de shell)"
    else
        fail "'install_nodejs.sh ${action}' modificó el HOME de prueba"
    fi

    rm -rf "${tmp_home}"
}

echo "== install/uninstall/reinstall se niegan a operar, sin variables de entorno =="
assert_action_refused "install"
assert_action_refused "uninstall"
assert_action_refused "reinstall"

echo ""
echo "== ninguna variable de entorno puede reactivar las acciones destructivas =="
assert_action_refused "install" "UCI_ALLOW_LEGACY_NVM=1"
assert_action_refused "uninstall" "UCI_ALLOW_LEGACY_NVM=1"
assert_action_refused "reinstall" "UCI_ALLOW_LEGACY_NVM=1"

echo ""
echo "== el código no contiene los patrones destructivos que tenía antes =="
# Se ignoran los comentarios (líneas que empiezan con '#' tras espacios en
# blanco): el propio archivo documenta en su encabezado, en prosa, qué
# patrones destructivos tenía antes — eso no debe confundirse con código
# real todavía presente.
install_nodejs_code_only() {
    grep -vE '^[[:space:]]*#' "${INSTALL_NODEJS_SH}"
}

if install_nodejs_code_only | grep -q 'rm -rf.*\.nvm'; then
    fail "install_nodejs.sh todavía contiene código con un 'rm -rf' sobre .nvm"
else
    pass "install_nodejs.sh ya no contiene código con ningún 'rm -rf' sobre .nvm"
fi

if install_nodejs_code_only | grep -qE "sed -i .*(bashrc|zshrc|profile|NVM_DIR|nvm)"; then
    fail "install_nodejs.sh todavía contiene código con un 'sed -i' sobre archivos de shell"
else
    pass "install_nodejs.sh ya no contiene código con ningún 'sed -i' sobre archivos de shell"
fi

echo ""
echo "== 'status' se mantiene funcional (de solo lectura) =="
tmp_home_status="$(mktemp -d)"
status_output="$(HOME="${tmp_home_status}" "${INSTALL_NODEJS_SH}" status 2>&1)" || true
if [[ "${status_output}" == "NOT_INSTALLED" || "${status_output}" == "INSTALLED" ]]; then
    pass "'install_nodejs.sh status' sigue respondiendo INSTALLED/NOT_INSTALLED"
else
    fail "'install_nodejs.sh status' no respondió lo esperado. Salida: ${status_output}"
fi
rm -rf "${tmp_home_status}"

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
