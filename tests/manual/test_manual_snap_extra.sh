#!/usr/bin/env bash
# tests/manual/test_manual_snap_extra.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida contra un snapd REAL los 8
# instaladores `manager=snap` incorporados DESPUÉS del Hito 18, que no
# cubre tests/manual/test_manual_snap_apps.sh (ese cubre los 8
# originales: DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom,
# Yazi). Juntos cubren los 16 instaladores Snap del catálogo.
#
# Ningún contenedor Docker de este proyecto puede probar esto de verdad
# sin systemd (ver ADR 0039 y docs/TESTING.md, "Qué no reemplaza esto").
# Instala y desinstala cada app de verdad contra el Snap Store real.
#
# Peso aproximado: Chromium, Krita, Obsidian y Telegram son las pesadas
# (cientos de MB cada una). Contar con banda ancha y ~20-30 min.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_snap_extra.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

manual_section "Snap disponible en esta máquina"
if command -v snap &> /dev/null && snap list &> /dev/null; then
    echo "  OK    - 'snap' responde en esta máquina, se puede continuar"
else
    echo "  FALLO - 'snap' no está disponible o no responde en esta máquina. Instalar/activar snapd antes de continuar." >&2
    exit 1
fi

manual_section "Instaladores manager=snap posteriores al Hito 18"
manual_note "Los 8 originales los cubre test_manual_snap_apps.sh; estos son los que faltaban."

manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_bitwarden.sh" "Bitwarden"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_bruno.sh" "Bruno"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_chromium.sh" "Chromium"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/editors/install_helix.sh" "Helix"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_krita.sh" "Krita"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_obsidian.sh" "Obsidian"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_telegram_desktop.sh" "Telegram Desktop"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_yq.sh" "yq"

manual_section "Verificación cruzada: qué snaps quedaron en el sistema"
manual_note "Tras un ciclo completo no debería quedar ninguno de los 8 instalados."
snap list 2>/dev/null || true

manual_exit_with_summary
