#!/usr/bin/env bash
# tests/manual/test_manual_ai_and_ide.sh
#
# Hito 18 (ver docs/ROADMAP.md): valida contra la red real Antigravity IDE
# (manager=apt-vendor-repo, ver ADR 0041) y los 7 candidatos de IA del
# Hito 16 (manager=curl-script para 6 de ellos, ver ADR 0037; Claude
# Desktop es apt-vendor-repo). Ninguno de estos mecanismos se puede
# verificar de punta a punta en CI: los mocks de docs/TEST_CASES.md (I27,
# I30-I33) confirman que cada instalador invoca el mecanismo correcto,
# pero no que el script/repositorio oficial del proveedor siga vigente ni
# que el binario resultante realmente funcione.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_ai_and_ide.sh 2>&1 | tee /tmp/manual-ai-and-ide.log
set -Eeuo pipefail

if [[ -f /.dockerenv ]]; then
    echo "Este script instala software real (repos APT/binarios de terceros" >&2
    echo "vía curl) y está pensado para una VM, no un contenedor Docker. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"

manual_section "Antigravity IDE (manager=apt-vendor-repo, ADR 0041)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/editors/install_antigravity_ide.sh" "Antigravity IDE"

manual_section "CLIs de IA vía curl-script (ADR 0037)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_claude_code.sh" "Claude Code"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_codex_cli.sh" "Codex CLI"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_opencode.sh" "OpenCode"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_antigravity.sh" "Antigravity CLI (agy)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_openclaw.sh" "OpenClaw"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_hermes_agent.sh" "Hermes Agent"

manual_section "Claude Desktop (manager=apt-vendor-repo)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_claude_desktop.sh" "Claude Desktop"

manual_exit_with_summary
