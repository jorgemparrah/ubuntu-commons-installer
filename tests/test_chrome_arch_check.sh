#!/usr/bin/env bash
# tests/test_chrome_arch_check.sh
#
# Prueba simulada (Hito 9, Fase B) de scripts/productivity/install_chrome.sh:
# confirma que la instalación se permite en amd64 (arquitectura
# oficialmente soportada, ver docs/adr/0028-arquitectura-soportada-amd64.md)
# y se rechaza explícitamente en cualquier otra arquitectura (arm64 como
# caso de prueba), sin descargar nada — antes este script instalaba el
# .deb amd64 sin verificar la arquitectura real (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md). No descarga nada real: dpkg/wget/apt se
# interceptan con comandos falsos en un PATH temporal.
#
# Uso:
#   bash tests/test_chrome_arch_check.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_CHROME_SH="${UCI_REPO_ROOT}/scripts/productivity/install_chrome.sh"
readonly INSTALL_CHROME_SH

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
UCI_MOCK_LOG=""

# setup_mock_bin <arch> <dpkg_installed: yes|no>
setup_mock_bin() {
    local arch="$1" dpkg_installed="$2"
    UCI_MOCK_BIN="$(mktemp -d)"
    UCI_MOCK_LOG="$(mktemp)"

    cat > "${UCI_MOCK_BIN}/dpkg" <<EOF
#!/usr/bin/env bash
echo "dpkg \$*" >> "${UCI_MOCK_LOG}"
if [[ "\$1" == "--print-architecture" ]]; then
    echo "${arch}"
    exit 0
fi
if [[ "\$1" == "-l" ]]; then
    if [[ "${dpkg_installed}" == "yes" ]]; then
        echo "ii  google-chrome-stable  1.0  ${arch}  Google Chrome"
        exit 0
    else
        exit 1
    fi
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/dpkg"

    cat > "${UCI_MOCK_BIN}/wget" <<EOF
#!/usr/bin/env bash
echo "wget \$*" >> "${UCI_MOCK_LOG}"
touch "google-chrome-stable_current_amd64.deb"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/wget"

    cat > "${UCI_MOCK_BIN}/apt" <<EOF
#!/usr/bin/env bash
echo "apt \$*" >> "${UCI_MOCK_LOG}"
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/apt"

    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo"
}

teardown_mock_bin() {
    rm -f "${UCI_MOCK_BIN}/google-chrome-stable_current_amd64.deb" 2>/dev/null || true
    rm -rf "${UCI_MOCK_BIN}"
    rm -f "${UCI_MOCK_LOG}"
    rm -f "google-chrome-stable_current_amd64.deb" 2>/dev/null || true
}

echo "== amd64 (arquitectura soportada, ADR 0028): status y install proceden normalmente =="
setup_mock_bin "amd64" "no"
OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" "${INSTALL_CHROME_SH}" status 2>&1)" || true
if [[ "${OUTPUT}" == "NOT_INSTALLED" ]]; then
    pass "amd64: 'status' reporta NOT_INSTALLED (no UNSUPPORTED)"
else
    fail "amd64: 'status' debería reportar NOT_INSTALLED, reportó: ${OUTPUT}"
fi

set +e
INSTALL_OUTPUT="$(cd "${UCI_MOCK_BIN}" && PATH="${UCI_MOCK_BIN}:${PATH}" "${INSTALL_CHROME_SH}" install 2>&1)"
INSTALL_CODE=$?
set -e
if [[ "${INSTALL_CODE}" -eq 0 ]]; then
    pass "amd64: 'install' sale con código 0"
else
    fail "amd64: 'install' debería salir con código 0. Salida: ${INSTALL_OUTPUT}"
fi
if grep -q "wget" "${UCI_MOCK_LOG}"; then
    pass "amd64: 'install' sí intenta descargar el .deb"
else
    fail "amd64: 'install' debería haber intentado descargar el .deb"
fi
teardown_mock_bin

echo ""
echo "== arm64 (no soportada, ver ADR 0028): status y install se rechazan sin descargar nada =="
setup_mock_bin "arm64" "no"
OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" "${INSTALL_CHROME_SH}" status 2>&1)" || true
if [[ "${OUTPUT}" == "UNSUPPORTED" ]]; then
    pass "arm64: 'status' reporta UNSUPPORTED"
else
    fail "arm64: 'status' debería reportar UNSUPPORTED, reportó: ${OUTPUT}"
fi

set +e
INSTALL_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" "${INSTALL_CHROME_SH}" install 2>&1)"
INSTALL_CODE=$?
set -e
if [[ "${INSTALL_CODE}" -ne 0 ]]; then
    pass "arm64: 'install' sale con código distinto de cero"
else
    fail "arm64: 'install' debería salir con código distinto de cero"
fi
if [[ "${INSTALL_OUTPUT}" == *"amd64"* ]]; then
    pass "arm64: el mensaje de error menciona que solo se soporta amd64"
else
    fail "arm64: no se encontró un mensaje claro. Salida: ${INSTALL_OUTPUT}"
fi
if grep -q "wget" "${UCI_MOCK_LOG}" 2>/dev/null; then
    fail "arm64: no debería haber intentado descargar nada"
else
    pass "arm64: no se intentó descargar ningún .deb"
fi
teardown_mock_bin

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
