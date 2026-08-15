#!/usr/bin/env bash
# tests/manual/test_manual_ai_local.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida las herramientas de IA local de
# los Hitos 53 y 56, que estrenan tres mecanismos nuevos y por lo tanto
# son las que más conviene probar de verdad:
#
#   - AnythingLLM : curl-script     (instalador oficial que baja un AppImage)
#   - Ollama      : curl-script     (instalador oficial, crea un servicio systemd)
#   - LM Studio   : appimage-direct (AppImage crudo + libfuse2 + .desktop)
#   - Open WebUI  : pip-mise        (pip sobre un Python 3.11 fijado por Mise)
#   - OmniRoute   : npm-mise        (npm -g sobre un Node 24 fijado por Mise)
#
# ⚠️ ES EL GRUPO MÁS PESADO DE LA BATERÍA. Entre el modelo runtime de
# Ollama, el AppImage de LM Studio, el paquete npm de OmniRoute (~700 MB
# desempaquetado) y los runtimes que Mise tenga que instalar, esto puede
# descargar varios GB y tardar bastante. Correrlo con tiempo y espacio en
# disco de sobra.
#
# Lo que este grupo prueba y ningún mock puede: que `pip-mise` y
# `npm-mise` de verdad usen el runtime de Mise y no el del sistema, que es
# la razón de existir de ambos mecanismos.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_ai_local.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

UCI_MISE_BIN="${HOME}/.local/bin/mise"

manual_section "Estado de Mise antes de empezar"
if [[ -x "${UCI_MISE_BIN}" ]] || command -v mise &> /dev/null; then
    manual_note "Mise ya está disponible: $("${UCI_MISE_BIN}" --version 2>/dev/null || mise --version 2>/dev/null || echo '?')"
else
    manual_note "Mise NO está instalado todavía. Open WebUI y OmniRoute deben instalarlo por su cuenta."
    manual_note "Antes de eso, el 'status' de ambos debe decir UNKNOWN (no NOT_INSTALLED)."

    manual_step "Open WebUI: status sin Mise disponible"
    manual_capture_status "${UCI_REPO_ROOT}/scripts/development/install_open_webui.sh"
    UCI_OWUI_NOMISE="${UCI_MANUAL_LAST_OUTPUT}"
    manual_check "Open WebUI: sin Mise, 'status' dice UNKNOWN (no afirma NOT_INSTALLED)" '[[ "${UCI_OWUI_NOMISE}" == *"UNKNOWN"* ]]'

    manual_step "OmniRoute: status sin Mise disponible"
    manual_capture_status "${UCI_REPO_ROOT}/scripts/development/install_omniroute.sh"
    UCI_OMNI_NOMISE="${UCI_MANUAL_LAST_OUTPUT}"
    manual_check "OmniRoute: sin Mise, 'status' dice UNKNOWN (no afirma NOT_INSTALLED)" '[[ "${UCI_OMNI_NOMISE}" == *"UNKNOWN"* ]]'
fi

manual_section "AnythingLLM (curl-script)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_anythingllm.sh" "AnythingLLM"
manual_note "Los datos en ~/.config/anythingllm-desktop se conservan a propósito tras desinstalar."

manual_section "Ollama (curl-script, instala un servicio systemd)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_ollama.sh" "Ollama"
manual_note "Estado del servicio de Ollama tras el ciclo completo:"
systemctl status ollama --no-pager 2>&1 | head -5 || echo "  (sin unidad 'ollama', que es lo esperado tras desinstalar)"

manual_section "LM Studio (appimage-direct)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_lmstudio.sh" "LM Studio"
manual_check "LM Studio: 'libfuse2' quedó instalado (los AppImage lo necesitan en Ubuntu 24.04+)" \
    'dpkg-query -W -f="\${Status}" libfuse2 2>/dev/null | grep -q "install ok installed" || dpkg-query -W -f="\${Status}" libfuse2t64 2>/dev/null | grep -q "install ok installed"'
manual_check "LM Studio: el AppImage se retiró de ~/.local/share/lmstudio al desinstalar" '[[ ! -e "${HOME}/.local/share/lmstudio/LM-Studio.AppImage" ]]'
manual_check "LM Studio: el lanzador .desktop se retiró al desinstalar" '[[ ! -f "${HOME}/.local/share/applications/lmstudio.desktop" ]]'
manual_note "libfuse2 NO se purga a propósito: lo comparten otros AppImage del catálogo."

# ---------------------------------------------------------------------
# Open WebUI y OmniRoute: lo importante no es solo que instalen, sino que
# usen el runtime de MISE y no el del sistema. Esa es la razón de existir
# de `pip-mise` y `npm-mise` (ADR 0046 y 0047), y es justo lo que los
# tests mockeados no pueden demostrar.
# ---------------------------------------------------------------------
manual_section "Open WebUI (pip-mise): pip sobre el Python 3.11 de Mise"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_open_webui.sh" "Open WebUI"

UCI_MISE_PY="$(find "${HOME}/.local/share/mise/installs/python" -maxdepth 1 -name '3.11*' 2>/dev/null | head -1)"
manual_note "Python de Mise encontrado en: ${UCI_MISE_PY:-(ninguno)}"
manual_check "Open WebUI: Mise instaló un Python 3.11 propio (no se usó el del sistema)" '[[ -n "${UCI_MISE_PY}" ]]'

manual_section "OmniRoute (npm-mise): npm -g sobre el Node 24 de Mise"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_omniroute.sh" "OmniRoute"

UCI_MISE_NODE="$(find "${HOME}/.local/share/mise/installs/node" -maxdepth 1 -name '24*' 2>/dev/null | head -1)"
manual_note "Node de Mise encontrado en: ${UCI_MISE_NODE:-(ninguno)}"
manual_check "OmniRoute: Mise instaló un Node 24 propio (no se usó el del sistema)" '[[ -n "${UCI_MISE_NODE}" ]]'

manual_section "Pasos que NO se pueden automatizar"
manual_skip "Levantar 'omniroute' y abrir el dashboard en localhost:20128" \
    "los instaladores no gestionan servicios a propósito; hay que arrancarlo a mano"
manual_skip "Levantar 'open-webui serve' y abrir localhost:8080" \
    "mismo motivo"
manual_skip "Abrir LM Studio y AnythingLLM y comprobar que la ventana levanta" \
    "requiere sesión gráfica e interacción real"

manual_exit_with_summary
