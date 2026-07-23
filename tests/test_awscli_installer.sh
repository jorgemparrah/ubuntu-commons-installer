#!/usr/bin/env bash
# tests/test_awscli_installer.sh
#
# Prueba simulada (mocks) de scripts/development/install_awscli.sh (Hito
# 42, ver docs/ROADMAP.md). Primer instalador de este catálogo con
# mecanismo `manager=aws-cli-installer` (ver el propio instalador): no
# instala nada real. `curl`/`unzip`/`sudo`/`uname` se interceptan con
# comandos falsos en un PATH temporal. `unzip` simula la extracción
# creando un script `aws/install` FALSO ejecutable dentro del directorio
# temporal que el propio instalador crea con `mktemp -d` (mismo criterio
# que tests/test_xh_installer.sh/tests/test_procs_installer.sh: simular
# el resultado de la extracción en vez de generar un .zip real) — ese
# script falso solo registra sus argumentos en el log, nunca toca rutas
# reales del sistema.
#
# Uso:
#   bash tests/test_awscli_installer.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_awscli.sh"
readonly INSTALL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_MOCK_BIN=""
UCI_MOCK_LOG=""

# setup_mock_bin <binary: auto|yes|no|broken>
# binary=yes: 'aws' resuelve y '--version' funciona (ya instalado, sano).
# binary=broken: 'aws' resuelve pero '--version' falla (BROKEN).
# binary=no: 'aws' no existe en el PATH simulado (NOT_INSTALLED).
setup_mock_bin() {
    local binary="${1:-no}"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"

    cat > "${UCI_MOCK_BIN}/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-m" ]]; then
    echo "x86_64"
    exit 0
fi
exit 1
EOF
    chmod +x "${UCI_MOCK_BIN}/uname"

    # curl: escribe contenido falso en el destino tras '-o' (el .zip
    # nunca se descomprime de verdad, ver 'unzip' más abajo).
    cat > "${UCI_MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "${UCI_MOCK_LOG}"
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-o" ]]; then
        echo "contenido-zip-falso" > "\${arg}"
    fi
    prev="\${arg}"
done
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/curl"

    # unzip: en vez de descomprimir un .zip real, crea directamente el
    # árbol 'aws/install' esperado dentro del destino ('-d'), con un
    # script instalador FALSO que solo registra sus argumentos.
    cat > "${UCI_MOCK_BIN}/unzip" <<EOF
#!/usr/bin/env bash
echo "unzip \$*" >> "${UCI_MOCK_LOG}"
dest=""
prev=""
for arg in "\$@"; do
    if [[ "\${prev}" == "-d" ]]; then dest="\${arg}"; fi
    prev="\${arg}"
done
mkdir -p "\${dest}/aws"
{
    echo '#!/usr/bin/env bash'
    echo 'echo "aws-install \$@" >> "${UCI_MOCK_LOG}"'
    echo 'exit 0'
} > "\${dest}/aws/install"
chmod +x "\${dest}/aws/install"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/unzip"

    case "${binary}" in
        yes)
            cat > "${UCI_MOCK_BIN}/aws" <<'EOF'
#!/usr/bin/env bash
echo "aws-cli/2.27.41 Python/3.12.0 Linux/6.8.0"
exit 0
EOF
            chmod +x "${UCI_MOCK_BIN}/aws"
            ;;
        broken)
            cat > "${UCI_MOCK_BIN}/aws" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
            chmod +x "${UCI_MOCK_BIN}/aws"
            ;;
        no) ;;
    esac
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
}

# run_installer <acción> <binary>
RUN_CODE=0
RUN_OUTPUT=""
run_installer() {
    local action="$1" binary="${2:-no}"
    setup_mock_bin "${binary}"
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" "${action}" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. estado inicial ausente: NOT_INSTALLED =="
run_installer "status" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"NOT_INSTALLED"* ]]; then
    pass "estado inicial reporta NOT_INSTALLED con código distinto de cero"
else
    fail "estado inicial no reportó NOT_INSTALLED (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 2. install: descarga el .zip, lo extrae y corre el instalador oficial =="
run_installer "install" "no"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'install' sale con código 0"
else
    fail "'install' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if grep -q "curl .*awscli-exe-linux-x86_64.zip" "${UCI_MOCK_LOG}"; then
    pass "'install' descarga la URL fija para x86_64"
else
    fail "'install' no descargó la URL esperada. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q "aws-install .*--bin-dir /usr/local/bin --install-dir /usr/local/aws-cli" "${UCI_MOCK_LOG}"; then
    pass "'install' corre el instalador oficial de AWS con --bin-dir/--install-dir"
else
    fail "'install' no corrió el instalador oficial esperado. Log: $(cat "${UCI_MOCK_LOG}")"
fi
if grep -q -- "--update" "${UCI_MOCK_LOG}"; then
    fail "'install' NO debería pasar '--update' (solo 'update' lo hace)"
else
    pass "'install' no pasa '--update' (instalación nueva)"
fi
teardown_mock_bin

echo ""
echo "== 3. status con 'aws' resoluble y funcional: INSTALLED =="
run_installer "status" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && [[ "${RUN_OUTPUT}" == *"INSTALLED"* ]] && [[ "${RUN_OUTPUT}" != *"NOT_INSTALLED"* ]]; then
    pass "'status' reporta INSTALLED con código 0"
else
    fail "'status' no reportó INSTALLED correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 4. status con 'aws' presente pero '--version' fallando: BROKEN =="
run_installer "status" "broken"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"BROKEN"* ]]; then
    pass "'status' reporta BROKEN si 'aws --version' falla"
else
    fail "'status' no reportó BROKEN correctamente (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 5. install rechaza si ya está instalado (pide 'update') =="
run_installer "install" "yes"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"update"* ]]; then
    pass "'install' rechaza y sugiere 'update' si ya está instalado"
else
    fail "'install' debería rechazar si ya está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 6. install rechaza si está BROKEN (pide 'repair') =="
run_installer "install" "broken"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"repair"* ]]; then
    pass "'install' rechaza y sugiere 'repair' si está BROKEN"
else
    fail "'install' debería rechazar y sugerir 'repair' si está BROKEN (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 7. uninstall: elimina el directorio de instalación y los symlinks =="
run_installer "uninstall" "yes"
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'uninstall' sale con código 0"
else
    fail "'uninstall' debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 8. update: vuelve a descargar y corre el instalador con --update =="
run_installer "update" "yes"
if [[ "${RUN_CODE}" -eq 0 ]] && grep -q -- "--update" "${UCI_MOCK_LOG}"; then
    pass "'update' corre el instalador oficial con '--update'"
else
    fail "'update' no se comportó como se esperaba (código ${RUN_CODE}). Log: $(cat "${UCI_MOCK_LOG}")"
fi
teardown_mock_bin

echo ""
echo "== 9. update rechaza si no está instalado =="
run_installer "update" "no"
if [[ "${RUN_CODE}" -ne 0 ]] && [[ "${RUN_OUTPUT}" == *"install"* ]]; then
    pass "'update' rechaza y sugiere 'install' si no está instalado"
else
    fail "'update' debería rechazar si no está instalado (código ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
teardown_mock_bin

echo ""
echo "== 10. repair se rechaza explícitamente (no implementado a propósito) =="
run_installer "repair" "yes"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "'repair' se rechaza (no implementado)"
else
    fail "'repair' debería rechazarse (código ${RUN_CODE})"
fi
teardown_mock_bin

echo ""
echo "== 11. subcomando inválido falla =="
run_installer "esto-no-existe" "no"
if [[ "${RUN_CODE}" -ne 0 ]]; then
    pass "subcomando inválido sale con código distinto de cero"
else
    fail "subcomando inválido debería salir con código distinto de cero"
fi
teardown_mock_bin

print_test_summary
exit_with_test_summary
