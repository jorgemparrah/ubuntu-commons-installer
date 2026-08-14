#!/usr/bin/env bash
# tests/test_apt_sources_repair.sh
#
# Prueba simulada (mocks) de scripts/lib/apt_sources.sh y
# scripts/maintenance/repair_apt_sources.sh (ver docs/ROADMAP.md Hito 19).
#
# Contexto: en la primera ejecución real del instalador (2026-08-14) dos
# repositorios de terceros mal configurados hicieron que 'apt-get update'
# devolviera error de forma permanente, y como todos los instaladores APT
# dependen de ese comando, el instalador completo quedó inutilizable —
# hasta `cmatrix` dejó de poder instalarse. Esto valida las dos piezas que
# se agregaron para eso: detectar el problema y limpiarlo.
#
# No toca /etc en ningún momento: la biblioteca acepta
# UCI_APT_SOURCES_DIR / UCI_APT_SOURCES_MAIN, que acá apuntan a
# directorios temporales.
#
# Uso:
#   bash tests/test_apt_sources_repair.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
REPAIR_SH="${UCI_REPO_ROOT}/scripts/maintenance/repair_apt_sources.sh"
readonly REPAIR_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

UCI_FAKE_ETC=""
UCI_MOCK_BIN=""

# La salida real de 'apt-get update' de la ejecución del 2026-08-14, en
# español, con los dos repositorios que rompieron todo. Se usa tal cual
# para verificar que la detección no dependa del idioma del sistema.
readonly UCI_REAL_APT_OUTPUT='Obj:1 https://dl.google.com/linux/chrome-stable/deb stable InRelease
Ign:3 https://packages.microsoft.com/repos/azure-cli resolute InRelease
Err:7 https://packages.microsoft.com/repos/azure-cli resolute Release
  404  Not Found [IP: 2620:1ec:46::33 443]
Des:15 https://ngrok-agent.s3.amazonaws.com bookworm InRelease [20,3 kB]
Err:15 https://ngrok-agent.s3.amazonaws.com bookworm InRelease
  Las firmas siguientes no se pudieron verificar porque su clave pública no está disponible: NO_PUBKEY 0E61D3BBAAEE37FE
Obj:16 http://archive.ubuntu.com/ubuntu resolute-updates InRelease
Leyendo lista de paquetes... Hecho
E: El repositorio «https://packages.microsoft.com/repos/azure-cli resolute Release» no tiene un fichero de Publicación.
W: https://ngrok-agent.s3.amazonaws.com/dists/bookworm/InRelease: The key(s) in the keyring /usr/share/keyrings/ngrok-archive-keyring.gpg are ignored as the file has an unsupported filetype.
E: El repositorio «https://ngrok-agent.s3.amazonaws.com bookworm InRelease» no está firmado.'

setup_fixture() {
    UCI_FAKE_ETC="$(mktemp -d)"
    UCI_MOCK_BIN="$(mktemp -d)"
    mkdir -p "${UCI_FAKE_ETC}/sources.list.d" "${UCI_FAKE_ETC}/keyrings"

    echo "deb http://archive.ubuntu.com/ubuntu resolute main" > "${UCI_FAKE_ETC}/sources.list"
    echo "deb [signed-by=${UCI_FAKE_ETC}/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com bookworm main" \
        > "${UCI_FAKE_ETC}/sources.list.d/ngrok.list"
    printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/azure-cli\nSuites: resolute\n' \
        > "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources"
    echo "deb https://sano.example stable main" > "${UCI_FAKE_ETC}/sources.list.d/sano.list"

    # PPA de Launchpad tal como lo escribe 'add-apt-repository': la clave
    # va EMBEBIDA en línea, no como ruta a un keyring. Formato real,
    # copiado de una máquina de verdad. Debe ignorarse por completo.
    cat > "${UCI_FAKE_ETC}/sources.list.d/ppa-embebida.sources" <<'PPA'
Types: deb
URIs: https://ppa.launchpadcontent.net/ejemplo/app/ubuntu/
Suites: noble
Components: main
Signed-By: -----BEGIN PGP PUBLIC KEY BLOCK-----
 .
 mQINBFU7uhABEADX+dREIrFMc7DmSXZ5uu8D5Rl9dcmOF1qRvbkGbhfSgmQGG3d4
 -----END PGP PUBLIC KEY BLOCK-----
PPA

    # Clave en ASCII armor guardada como .gpg: exactamente el bug de ngrok.
    printf -- "-----BEGIN PGP PUBLIC KEY BLOCK-----\nmQINB\n" > "${UCI_FAKE_ETC}/keyrings/ngrok.gpg"

    # 'sudo' transparente y 'apt-get update' que reproduce la salida real.
    cat > "${UCI_MOCK_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
while [[ "$#" -gt 0 && "$1" == *=* && "$1" != -* ]]; do
    export "$1"
    shift
done
"$@"
EOF
    cat > "${UCI_MOCK_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "update" ]]; then
    if [[ -f "${UCI_FAKE_ETC}/sources.list.d/ngrok.list" || -f "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources" ]]; then
        cat <<'SALIDA'
${UCI_REAL_APT_OUTPUT}
SALIDA
        exit 100
    fi
    echo "Obj:1 http://archive.ubuntu.com/ubuntu resolute InRelease"
    echo "Leyendo lista de paquetes... Hecho"
    exit 0
fi
exit 0
EOF
    chmod +x "${UCI_MOCK_BIN}/sudo" "${UCI_MOCK_BIN}/apt-get"
}

teardown_fixture() {
    rm -rf "${UCI_FAKE_ETC}" "${UCI_MOCK_BIN}"
}

# run_repair [args...]
RUN_CODE=0
RUN_OUTPUT=""
run_repair() {
    set +e
    RUN_OUTPUT="$(PATH="${UCI_MOCK_BIN}:${PATH}" \
        HOME="${UCI_FAKE_ETC}/home" \
        UCI_APT_SOURCES_DIR="${UCI_FAKE_ETC}/sources.list.d" \
        UCI_APT_SOURCES_MAIN="${UCI_FAKE_ETC}/sources.list" \
        bash "${REPAIR_SH}" "$@" 2>&1)"
    RUN_CODE=$?
    set -e
}

echo "== 1. detección: extrae las URIs rotas de una salida real en español =="
setup_fixture
UCI_OUT_FILE="$(mktemp)"
printf '%s\n' "${UCI_REAL_APT_OUTPUT}" > "${UCI_OUT_FILE}"
UCI_DETECTED="$(
    UCI_APT_SOURCES_DIR="${UCI_FAKE_ETC}/sources.list.d" \
    UCI_APT_SOURCES_MAIN="${UCI_FAKE_ETC}/sources.list" \
    bash -c "source '${UCI_REPO_ROOT}/scripts/lib/apt_sources.sh'; apt_sources_broken_uris '${UCI_OUT_FILE}'"
)"
rm -f "${UCI_OUT_FILE}"

if [[ "$(printf '%s\n' "${UCI_DETECTED}" | grep -c .)" -eq 2 ]]; then
    pass "detecta exactamente los 2 repositorios rotos"
else
    fail "debería detectar 2 repositorios rotos. Obtenido: '${UCI_DETECTED}'"
fi
if [[ "${UCI_DETECTED}" == *"packages.microsoft.com/repos/azure-cli"* ]]; then
    pass "detecta el repositorio sin fichero Release (Azure CLI en 26.04)"
else
    fail "no detectó el repositorio de Azure CLI. Obtenido: '${UCI_DETECTED}'"
fi
if [[ "${UCI_DETECTED}" == *"ngrok-agent.s3.amazonaws.com"* ]]; then
    pass "detecta el repositorio sin firmar (ngrok)"
else
    fail "no detectó el repositorio de ngrok. Obtenido: '${UCI_DETECTED}'"
fi
# La detección se basa en las líneas 'Err:', que APT no traduce; los
# mensajes largos de esta salida están en español a propósito.
if [[ "${UCI_DETECTED}" != *"Obj:"* && "${UCI_DETECTED}" != *"Leyendo"* ]]; then
    pass "no confunde líneas normales ('Obj:', texto suelto) con errores"
else
    fail "arrastró líneas que no son errores. Obtenido: '${UCI_DETECTED}'"
fi
teardown_fixture

echo ""
echo "== 2. sin --apply: reporta y NO modifica nada =="
setup_fixture
run_repair
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "'repair-apt' sin --apply sale con código 0"
else
    fail "debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if [[ -f "${UCI_FAKE_ETC}/sources.list.d/ngrok.list" && -f "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources" ]]; then
    pass "no tocó ningún archivo de repositorio (modo reporte)"
else
    fail "el modo reporte NO debe modificar archivos"
fi
if [[ "${RUN_OUTPUT}" == *"--apply"* ]]; then
    pass "explica cómo aplicar la limpieza"
else
    fail "debería mencionar --apply. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 3. con --apply: respalda, deshabilita y no borra nada =="
setup_fixture
run_repair --apply
if [[ ! -f "${UCI_FAKE_ETC}/sources.list.d/ngrok.list" && -f "${UCI_FAKE_ETC}/sources.list.d/ngrok.list.disabled" ]]; then
    pass "deshabilitó ngrok.list renombrando a .disabled (no lo borró)"
else
    fail "ngrok.list debería quedar como .disabled. Salida: ${RUN_OUTPUT}"
fi
if [[ ! -f "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources" && -f "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources.disabled" ]]; then
    pass "deshabilitó azure-cli.sources (formato DEB822) igual que el .list"
else
    fail "azure-cli.sources debería quedar como .disabled. Salida: ${RUN_OUTPUT}"
fi
if [[ -f "${UCI_FAKE_ETC}/sources.list.d/sano.list" ]]; then
    pass "NO tocó el repositorio sano"
else
    fail "no debe tocar repositorios que no fallaron"
fi
if [[ -f "${UCI_FAKE_ETC}/sources.list" ]]; then
    pass "NO tocó /etc/apt/sources.list (dejaría el sistema sin repos base)"
else
    fail "el archivo principal de APT nunca debe deshabilitarse"
fi
UCI_BACKUP_COUNT="$(find "${UCI_FAKE_ETC}/home" -type f -name '*.list' -o -type f -name '*.sources' 2>/dev/null | wc -l)"
if [[ "${UCI_BACKUP_COUNT}" -ge 2 ]]; then
    pass "respaldó los archivos antes de deshabilitarlos (${UCI_BACKUP_COUNT} en el backup)"
else
    fail "debería haber respaldado los 2 archivos antes de tocarlos (encontrados: ${UCI_BACKUP_COUNT})"
fi
teardown_fixture

echo ""
echo "== 4. sin repositorios rotos: no hace nada y lo dice =="
setup_fixture
rm -f "${UCI_FAKE_ETC}/sources.list.d/ngrok.list" "${UCI_FAKE_ETC}/sources.list.d/azure-cli.sources"
run_repair --apply
if [[ "${RUN_CODE}" -eq 0 ]]; then
    pass "sale con código 0 cuando no hay nada roto"
else
    fail "debería salir con código 0 (fue ${RUN_CODE}). Salida: ${RUN_OUTPUT}"
fi
if [[ "${RUN_OUTPUT}" == *"No hay repositorios APT rotos"* ]]; then
    pass "informa explícitamente que no hay nada que limpiar"
else
    fail "debería informar que no hay repositorios rotos. Salida: ${RUN_OUTPUT}"
fi
teardown_fixture

echo ""
echo "== 5. revisión estática de keyrings: encuentra el bug sin red ni sudo =="
setup_fixture
UCI_PROBLEMS="$(
    UCI_APT_SOURCES_DIR="${UCI_FAKE_ETC}/sources.list.d" \
    UCI_APT_SOURCES_MAIN="${UCI_FAKE_ETC}/sources.list" \
    bash -c "source '${UCI_REPO_ROOT}/scripts/lib/apt_sources.sh'; apt_sources_keyring_problems"
)"
if [[ "${UCI_PROBLEMS}" == *"armored-como-gpg"* ]]; then
    pass "detecta una clave ASCII armor guardada como .gpg (el bug de ngrok)"
else
    fail "debería detectar la clave mal guardada. Obtenido: '${UCI_PROBLEMS}'"
fi
if [[ "${UCI_PROBLEMS}" == *"ngrok.gpg"* ]]; then
    pass "nombra el keyring concreto que APT va a ignorar"
else
    fail "debería nombrar el keyring. Obtenido: '${UCI_PROBLEMS}'"
fi

# Regresión de un falso positivo real (reportado por el dueño del proyecto
# al correr 'doctor' en su máquina): los .sources de los PPA de Launchpad
# traen la clave embebida en línea ('Signed-By: -----BEGIN PGP...'), no una
# ruta. La primera versión de esta comprobación tomaba '-----BEGIN' como un
# archivo y reportaba 4 "keyrings ausentes" que no existían como problema.
if [[ "${UCI_PROBLEMS}" != *"-----BEGIN"* ]]; then
    pass "no confunde una clave embebida en línea con una ruta de keyring"
else
    fail "reportó '-----BEGIN' como si fuera un archivo: falso positivo con los PPA de Launchpad. Obtenido: '${UCI_PROBLEMS}'"
fi
if [[ "${UCI_PROBLEMS}" != *"ppa-embebida.sources"* ]]; then
    pass "ignora por completo los .sources con clave embebida (configuración válida)"
else
    fail "un .sources con clave embebida no debe reportarse. Obtenido: '${UCI_PROBLEMS}'"
fi

# Un keyring binario bien guardado no debe reportarse.
printf '\x99\x01\x0a binario falso' > "${UCI_FAKE_ETC}/keyrings/ngrok.gpg"
UCI_PROBLEMS_OK="$(
    UCI_APT_SOURCES_DIR="${UCI_FAKE_ETC}/sources.list.d" \
    UCI_APT_SOURCES_MAIN="${UCI_FAKE_ETC}/sources.list" \
    bash -c "source '${UCI_REPO_ROOT}/scripts/lib/apt_sources.sh'; apt_sources_keyring_problems"
)"
if [[ "${UCI_PROBLEMS_OK}" != *"armored-como-gpg"* ]]; then
    pass "no marca falso positivo con una clave binaria correcta"
else
    fail "una clave binaria válida no debería reportarse. Obtenido: '${UCI_PROBLEMS_OK}'"
fi

# 'signed-by' apuntando a un archivo inexistente.
rm -f "${UCI_FAKE_ETC}/keyrings/ngrok.gpg"
UCI_PROBLEMS_MISSING="$(
    UCI_APT_SOURCES_DIR="${UCI_FAKE_ETC}/sources.list.d" \
    UCI_APT_SOURCES_MAIN="${UCI_FAKE_ETC}/sources.list" \
    bash -c "source '${UCI_REPO_ROOT}/scripts/lib/apt_sources.sh'; apt_sources_keyring_problems"
)"
if [[ "${UCI_PROBLEMS_MISSING}" == *"keyring-ausente"* ]]; then
    pass "detecta un 'signed-by' que apunta a un keyring inexistente"
else
    fail "debería detectar el keyring ausente. Obtenido: '${UCI_PROBLEMS_MISSING}'"
fi
teardown_fixture

print_test_summary
exit_with_test_summary
