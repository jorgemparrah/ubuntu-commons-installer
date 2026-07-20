#!/usr/bin/env bash
# tests/docker/test_snap_installers_functional.sh
#
# Prueba funcional REAL de los 8 instaladores Snap del catálogo (DBeaver,
# GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi): instala y
# desinstala cada snap de verdad contra el Snap Store real. SOLO debe
# correr dentro de un contenedor con systemd+snapd reales
# (tests/docker/Dockerfile.snapd), nunca en esta workstation ni en la
# imagen base sin systemd — ver
# tests/docker/run_snap_functional.sh y
# docs/adr/0039-snapd-en-docker-para-ci-experimental.md.
#
# EXPERIMENTAL: primera vez que este proyecto prueba snapd de punta a
# punta en CI. Instala 8 apps GUI reales (algunas pesadas, ej. GIMP) —
# puede tardar varios minutos y consumir ancho de banda/almacenamiento
# real, a diferencia del resto de la matriz. No reemplaza la pauta de
# validación manual en Ubuntu 26.04 Desktop (docs/TEST_CASES.md) hasta
# que este mecanismo demuestre estabilidad sostenida en CI.
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script instala snaps reales. Solo debe correr dentro de un" >&2
    echo "contenedor Docker desechable con systemd+snapd. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

FAILED=0
check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        echo "  OK  - ${description}"
    else
        echo "FALLO - ${description}"
        FAILED=1
    fi
}

# test_snap_installer <script> <label> <snap_package>
test_snap_installer() {
    local script="${UCI_REPO_ROOT}/$1" label="$2" pkg="$3"

    echo ""
    echo "== ${label} (${pkg}) =="

    set +e
    OUTPUT="$("${script}" status 2>&1)"
    CODE=$?
    set -e
    check "${label}: 'status' inicial reporta NOT_INSTALLED" '[[ ${CODE} -ne 0 && "${OUTPUT}" == *"NOT_INSTALLED"* ]]'

    "${script}" install
    INSTALL_CODE=$?
    check "${label}: 'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

    OUTPUT="$("${script}" status 2>&1)"
    CODE=$?
    check "${label}: 'status' reporta INSTALLED después de instalar" '[[ ${CODE} -eq 0 && "${OUTPUT}" == *"INSTALLED"* && "${OUTPUT}" != *"NOT_INSTALLED"* ]]'

    "${script}" uninstall
    UNINSTALL_CODE=$?
    check "${label}: 'uninstall' sale con código 0" '[[ ${UNINSTALL_CODE} -eq 0 ]]'

    set +e
    OUTPUT="$("${script}" status 2>&1)"
    CODE=$?
    set -e
    check "${label}: 'status' vuelve a NOT_INSTALLED después de desinstalar" '[[ ${CODE} -ne 0 && "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
}

test_snap_installer "scripts/development/install_dbeaver.sh" "DBeaver" "dbeaver-ce"
test_snap_installer "scripts/development/install_gitkraken.sh" "GitKraken" "gitkraken"
test_snap_installer "scripts/development/install_insomnia.sh" "Insomnia" "insomnia"
test_snap_installer "scripts/development/install_postman.sh" "Postman" "postman"
test_snap_installer "scripts/system/install_gimp.sh" "GIMP" "gimp"
test_snap_installer "scripts/productivity/install_spotify.sh" "Spotify" "spotify"
test_snap_installer "scripts/productivity/install_zoom.sh" "Zoom" "zoom-client"
test_snap_installer "scripts/system/install_yazi.sh" "Yazi" "yazi"

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: los 8 instaladores Snap instalan/desinstalan de verdad contra snapd real."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
