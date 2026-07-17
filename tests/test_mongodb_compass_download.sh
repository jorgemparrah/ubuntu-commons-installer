#!/usr/bin/env bash
# tests/test_mongodb_compass_download.sh
#
# Prueba simulada (comandos interceptados/mocks) para el Hito 9, Fase B:
# confirma que scripts/development/install_mongodb_compass.sh falla con
# un mensaje claro y limpia el .deb parcial cuando la descarga de la
# versión fija falla (riesgo documentado en docs/UBUNTU_COMPATIBILITY.md
# — MongoDB no publica un alias "latest" estable). No descarga nada real:
# wget/sudo/apt se interceptan con comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_mongodb_compass_download.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/development/install_mongodb_compass.sh"
readonly INSTALL_SH

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

UCI_MOCK_BIN=""
UCI_MOCK_WORKDIR=""

# setup_mock_bin <wget_exit_code> <apt_exit_code>
setup_mock_bin() {
    local wget_code="$1" apt_code="$2"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_WORKDIR="$(mktemp -d)"

    cat > "${UCI_MOCK_BIN}/wget" <<EOF
#!/usr/bin/env bash
if [[ "${wget_code}" -eq 0 ]]; then
    # simula una descarga exitosa: crea un archivo .deb falso (no vacío)
    for arg in "\$@"; do
        if [[ "\$arg" == *.deb ]]; then
            echo "contenido falso de .deb" > "\$arg"
        fi
    done
fi
exit ${wget_code}
EOF
    chmod +x "${UCI_MOCK_BIN}/wget"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
exit ${apt_code}
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mock_bin() {
    rm -rf "${UCI_MOCK_BIN}" "${UCI_MOCK_WORKDIR}"
}

echo "== install: la descarga falla (wget devuelve error) =="
setup_mock_bin "1" "0"
set +e
OUTPUT="$(cd "${UCI_MOCK_WORKDIR}" && PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" install 2>&1)"
CODE=$?
set -e
check_leftover_deb="$(find "${UCI_MOCK_WORKDIR}" -maxdepth 1 -name '*.deb' 2>/dev/null | wc -l)"
teardown_mock_bin

if [[ "${CODE}" -ne 0 ]]; then
    pass "'install' sale con código distinto de cero si la descarga falla"
else
    fail "'install' debería salir con código distinto de cero si la descarga falla"
fi
if [[ "${OUTPUT}" == *"No se pudo descargar"* ]]; then
    pass "'install' muestra un mensaje claro cuando la descarga falla"
else
    fail "no se encontró un mensaje claro de fallo de descarga. Salida: ${OUTPUT}"
fi
if [[ "${check_leftover_deb}" -eq 0 ]]; then
    pass "no queda ningún .deb parcial tras una descarga fallida"
else
    fail "quedó un .deb parcial tras una descarga fallida"
fi

echo ""
echo "== install: la descarga funciona pero la instalación del .deb falla =="
setup_mock_bin "0" "1"
set +e
OUTPUT="$(cd "${UCI_MOCK_WORKDIR}" && PATH="${UCI_MOCK_BIN}:${PATH}" bash "${INSTALL_SH}" install 2>&1)"
CODE=$?
set -e
check_leftover_deb="$(find "${UCI_MOCK_WORKDIR}" -maxdepth 1 -name '*.deb' 2>/dev/null | wc -l)"
teardown_mock_bin

if [[ "${CODE}" -ne 0 ]]; then
    pass "'install' sale con código distinto de cero si 'apt install' del .deb falla"
else
    fail "'install' debería salir con código distinto de cero si 'apt install' falla"
fi
if [[ "${check_leftover_deb}" -eq 0 ]]; then
    pass "el .deb descargado se limpia incluso si la instalación falla"
else
    fail "quedó el .deb descargado tras un fallo de instalación"
fi

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
