#!/usr/bin/env bash
# tests/test_backup_move_dir.sh
#
# Pruebas de la verificación de integridad de backup_move_dir/backup_dir_manifest
# (auditoría de estabilización de los Hitos 2-7, punto 5: no eliminar el
# origen basándose solo en la cantidad de archivos). Corre contra
# directorios temporales, nunca contra $HOME real.
#
# Uso:
#   bash tests/test_backup_move_dir.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
# shellcheck source=../scripts/lib/logging.sh
source "${UCI_REPO_ROOT}/scripts/lib/logging.sh"
# shellcheck source=../scripts/lib/backup.sh
source "${UCI_REPO_ROOT}/scripts/lib/backup.sh"

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

check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        pass "${description}"
    else
        fail "${description}"
    fi
}

UCI_TMP_ROOT="$(mktemp -d)"
readonly UCI_TMP_ROOT
cleanup() {
    rm -rf "${UCI_TMP_ROOT}"
}
trap cleanup EXIT

# make_fixture_dir <dir>
# Crea un directorio con: un archivo regular, un subdirectorio con un
# archivo, un subdirectorio VACÍO, y un symlink — para ejercitar todos los
# tipos de entrada que backup_dir_manifest debe cubrir.
make_fixture_dir() {
    local dir="$1"
    rm -rf "${dir}"
    mkdir -p "${dir}/subdir_vacio"
    mkdir -p "${dir}/subdir_con_archivo"
    echo "contenido original" > "${dir}/archivo.txt"
    chmod 640 "${dir}/archivo.txt"
    echo "otro archivo" > "${dir}/subdir_con_archivo/otro.txt"
    ln -s "archivo.txt" "${dir}/enlace.link"
}

echo "== backup_dir_manifest: caso base (dos copias idénticas) =="
DIR_A="${UCI_TMP_ROOT}/base_a"
DIR_B="${UCI_TMP_ROOT}/base_b"
make_fixture_dir "${DIR_A}"
cp -a "${DIR_A}" "${DIR_B}"
MANIFEST_A="$(backup_dir_manifest "${DIR_A}")"
MANIFEST_B="$(backup_dir_manifest "${DIR_B}")"
check "dos copias idénticas producen el mismo manifiesto" '[[ "${MANIFEST_A}" == "${MANIFEST_B}" ]]'

echo ""
echo "== Caso negativo 1: contenido de un archivo alterado (mismo tamaño) =="
DIR_C="${UCI_TMP_ROOT}/neg_contenido"
cp -a "${DIR_A}" "${DIR_C}"
# "contenido original" (19) -> "contenido cambiado!" (19), mismo largo.
printf 'contenido cambiado!' > "${DIR_C}/archivo.txt"
MANIFEST_C="$(backup_dir_manifest "${DIR_C}")"
if [[ "$(stat -c%s "${DIR_A}/archivo.txt")" == "$(stat -c%s "${DIR_C}/archivo.txt")" ]]; then
    pass "el archivo alterado tiene el mismo tamaño que el original (para que la prueba sea representativa)"
else
    fail "no se pudo preparar un archivo alterado del mismo tamaño"
fi
check "backup_dir_manifest detecta contenido alterado con el mismo tamaño (hash distinto)" '[[ "${MANIFEST_A}" != "${MANIFEST_C}" ]]'

echo ""
echo "== Caso negativo 2: destino de un symlink alterado =="
DIR_D="${UCI_TMP_ROOT}/neg_symlink"
cp -a "${DIR_A}" "${DIR_D}"
rm "${DIR_D}/enlace.link"
ln -s "subdir_con_archivo/otro.txt" "${DIR_D}/enlace.link"
MANIFEST_D="$(backup_dir_manifest "${DIR_D}")"
check "backup_dir_manifest detecta un symlink que apunta a otro destino" '[[ "${MANIFEST_A}" != "${MANIFEST_D}" ]]'

echo ""
echo "== Caso negativo 3: falta un directorio vacío =="
DIR_E="${UCI_TMP_ROOT}/neg_dir_vacio"
cp -a "${DIR_A}" "${DIR_E}"
rmdir "${DIR_E}/subdir_vacio"
MANIFEST_E="$(backup_dir_manifest "${DIR_E}")"
check "backup_dir_manifest detecta que falta un directorio vacío" '[[ "${MANIFEST_A}" != "${MANIFEST_E}" ]]'

echo ""
echo "== Caso negativo 4: permiso relevante distinto =="
DIR_F="${UCI_TMP_ROOT}/neg_permiso"
cp -a "${DIR_A}" "${DIR_F}"
chmod 600 "${DIR_F}/archivo.txt"
MANIFEST_F="$(backup_dir_manifest "${DIR_F}")"
check "backup_dir_manifest detecta un permiso distinto (640 vs 600)" '[[ "${MANIFEST_A}" != "${MANIFEST_F}" ]]'

echo ""
echo "== Caso negativo 5: mismo tamaño, contenido distinto, en un archivo distinto del árbol =="
DIR_G="${UCI_TMP_ROOT}/neg_tamano_igual"
cp -a "${DIR_A}" "${DIR_G}"
printf 'otro-archivx\n' > "${DIR_G}/subdir_con_archivo/otro.txt"
if [[ "$(stat -c%s "${DIR_A}/subdir_con_archivo/otro.txt")" == "$(stat -c%s "${DIR_G}/subdir_con_archivo/otro.txt")" ]]; then
    pass "el archivo anidado alterado tiene el mismo tamaño que el original"
else
    fail "no se pudo preparar un archivo anidado alterado del mismo tamaño"
fi
MANIFEST_G="$(backup_dir_manifest "${DIR_G}")"
check "backup_dir_manifest detecta contenido distinto en un archivo anidado de igual tamaño" '[[ "${MANIFEST_A}" != "${MANIFEST_G}" ]]'

echo ""
echo "== backup_move_dir: camino feliz (archivo + symlink + directorio vacío) =="
HOME_HAPPY="${UCI_TMP_ROOT}/home_happy"
mkdir -p "${HOME_HAPPY}"
make_fixture_dir "${HOME_HAPPY}/origen"
SESSION_HAPPY="$(backup_init_session "${HOME_HAPPY}" "0")"
if backup_move_dir "${SESSION_HAPPY}" "${HOME_HAPPY}" "${HOME_HAPPY}/origen" "0" >/dev/null; then
    pass "'backup_move_dir' se completa sin error en el camino feliz"
else
    fail "'backup_move_dir' falló en el camino feliz"
fi
check "el origen ya no existe (se movió)" '[[ ! -e "${HOME_HAPPY}/origen" ]]'
check "el destino conserva el archivo" '[[ -f "${SESSION_HAPPY}/home/origen/archivo.txt" ]]'
check "el destino conserva el symlink" '[[ -L "${SESSION_HAPPY}/home/origen/enlace.link" ]]'
check "el destino conserva el subdirectorio vacío" '[[ -d "${SESSION_HAPPY}/home/origen/subdir_vacio" ]]'

echo ""
echo "== backup_move_dir: el origen cambia después de copiarlo (no debe eliminarse) =="
# Escenario real: algo modifica el origen entre el momento en que se copia
# y el momento en que se decidiría eliminarlo (por ejemplo, una migración
# interrumpida y reanudada, o un proceso externo). Se simula copiando
# manualmente con backup_copy_dir, alterando el origen después, y
# confirmando que el manifiesto ya no coincide (la misma comparación que
# usa backup_move_dir antes de un rm -rf).
HOME_RACE="${UCI_TMP_ROOT}/home_race"
mkdir -p "${HOME_RACE}"
make_fixture_dir "${HOME_RACE}/origen"
SESSION_RACE="$(backup_init_session "${HOME_RACE}" "0")"
backup_copy_dir "${SESSION_RACE}" "${HOME_RACE}" "${HOME_RACE}/origen" "0" >/dev/null
# El origen cambia DESPUÉS de haberse copiado (simula la condición de carrera).
printf 'contenido modificado tras la copia' > "${HOME_RACE}/origen/archivo.txt"
MANIFEST_ORIGEN_TRAS_CAMBIO="$(backup_dir_manifest "${HOME_RACE}/origen")"
MANIFEST_DESTINO_YA_COPIADO="$(backup_dir_manifest "${SESSION_RACE}/home/origen")"
check "el manifiesto detecta que el origen cambió después de la copia (no se debe eliminar)" \
    '[[ "${MANIFEST_ORIGEN_TRAS_CAMBIO}" != "${MANIFEST_DESTINO_YA_COPIADO}" ]]'
check "el origen sigue existiendo (nadie lo eliminó todavía en este escenario simulado)" \
    '[[ -e "${HOME_RACE}/origen" ]]'

echo ""
echo "== backup_move_dir: no reutiliza una sesión con un destino ya presente =="
HOME_REFUSE="${UCI_TMP_ROOT}/home_refuse"
mkdir -p "${HOME_REFUSE}"
make_fixture_dir "${HOME_REFUSE}/origen"
SESSION_REFUSE="$(backup_init_session "${HOME_REFUSE}" "0")"
mkdir -p "${SESSION_REFUSE}/home/origen"
echo "ya había algo acá" > "${SESSION_REFUSE}/home/origen/preexistente.txt"
set +e
backup_move_dir "${SESSION_REFUSE}" "${HOME_REFUSE}" "${HOME_REFUSE}/origen" "0" >/tmp/refuse_output.log 2>&1
REFUSE_CODE=$?
set -e
check "'backup_move_dir' sale con código distinto de cero si el destino ya existe" '[[ ${REFUSE_CODE} -ne 0 ]]'
check "el origen NO se elimina cuando se rechaza la copia" '[[ -e "${HOME_REFUSE}/origen" ]]'
rm -f /tmp/refuse_output.log

echo ""
echo "== Resumen =="
echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
echo "Fallos: ${UCI_TESTS_FAILED}"

if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi

exit 0
