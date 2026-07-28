#!/usr/bin/env bash
# tests/manual/test_manual_flatpak_apps.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida los 3 instaladores
# `manager=flatpak` del catálogo (Hitos 50/51, ver ADR 0045). Ningún
# contenedor de este proyecto los prueba de verdad: Flatpak necesita
# bubblewrap y espacios de nombres de usuario que el CI no da.
#
# ATENCIÓN AL TIEMPO: la PRIMERA app que se instale va a arrastrar el
# runtime de GNOME de Flathub (más de 1 GB). Las otras dos reutilizan ese
# runtime y son rápidas. Que la primera tarde muchísimo más que las otras
# dos es lo esperado, no un fallo.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_flatpak_apps.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

manual_section "Estado de Flatpak antes de empezar"
if command -v flatpak &> /dev/null; then
    manual_note "'flatpak' ya está presente: $(flatpak --version 2>/dev/null || echo '?')"
else
    manual_note "'flatpak' NO está instalado todavía; los instaladores deben encargarse de eso."
fi
manual_note "Remotos configurados ahora mismo:"
flatpak remotes 2>/dev/null || echo "  (ninguno / flatpak no disponible)"

manual_section "Instaladores manager=flatpak"
manual_note "La primera instalación descarga el runtime de GNOME (>1 GB). Paciencia."

manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_kooha.sh"          "Kooha"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_logseq.sh"   "Logseq"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_papers.sh"   "Papers"

manual_section "Verificaciones propias del mecanismo Flatpak"

manual_check "'flatpak' quedó disponible en el sistema" 'command -v flatpak &> /dev/null'

UCI_FLATHUB_PRESENT=1
if command -v flatpak &> /dev/null && flatpak remotes 2>/dev/null | grep -q "flathub"; then
    UCI_FLATHUB_PRESENT=0
fi
manual_check "el remoto 'flathub' quedó configurado" '[[ ${UCI_FLATHUB_PRESENT} -eq 0 ]]'

manual_note "Apps Flatpak instaladas al terminar (no debería quedar ninguna de las tres):"
flatpak list --app 2>/dev/null || echo "  (ninguna)"

manual_note "El runtime de GNOME queda instalado a propósito tras desinstalar las apps:"
manual_note "quitarlo rompería cualquier otra app Flatpak del sistema."

manual_exit_with_summary
