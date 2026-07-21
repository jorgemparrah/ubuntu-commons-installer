#!/usr/bin/env bash
# tests/manual/test_manual_snap_apps.sh
#
# Hito 18 (ver docs/ROADMAP.md): valida contra un snapd REAL los 8
# instaladores `manager=snap` del catálogo, que ningún contenedor Docker
# de este proyecto puede probar de verdad sin systemd (ver ADR 0039 para
# el intento experimental en CI, y docs/TESTING.md "Qué no reemplaza
# esto"). Instala y desinstala cada uno de verdad, contra el Snap Store
# real — consume ancho de banda real y tarda varios minutos.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_snap_apps.sh 2>&1 | tee /tmp/manual-snap-apps.log
set -Eeuo pipefail

if [[ -f /.dockerenv ]]; then
    echo "Este script instala software real y está pensado para una VM Ubuntu" >&2
    echo "Desktop, no para un contenedor Docker (no tiene snapd real). Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"

manual_section "Snap disponible en esta máquina"
if command -v snap &> /dev/null && snap list &> /dev/null; then
    echo "  OK    - 'snap' responde en esta máquina, se puede continuar"
else
    echo "  FALLO - 'snap' no está disponible o no responde en esta máquina. Instalar/activar snapd antes de continuar." >&2
    exit 1
fi

manual_section "Los 8 instaladores manager=snap del catálogo"

manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_dbeaver.sh" "DBeaver"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_gitkraken.sh" "GitKraken"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_insomnia.sh" "Insomnia"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_postman.sh" "Postman"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_gimp.sh" "GIMP"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_spotify.sh" "Spotify"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_zoom.sh" "Zoom"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_yazi.sh" "Yazi"

manual_exit_with_summary
