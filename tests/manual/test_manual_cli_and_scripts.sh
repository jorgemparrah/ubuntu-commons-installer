#!/usr/bin/env bash
# tests/manual/test_manual_cli_and_scripts.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida los instaladores livianos que no
# pasan por APT y que ningún script manual previo cubre. Agrupa tres
# mecanismos que comparten el mismo perfil (descarga rápida, sin tocar el
# sistema):
#
#   - curl-script   : Starship, Joplin
#   - archive-direct: procs, xh
#   - git-clone     : pipes.sh, pokemon-colorscripts
#
# Es el grupo más rápido y de menor riesgo de toda la batería: un buen
# primer script para correr y confirmar que el entorno de la VM está bien
# antes de meterse con los pesados.
#
# Incluye además la validación del verbo `configure` de Starship (Hito
# 54): instalar la Nerd Font MesloLGS NF. Es el único `configure` del
# catálogo sin cobertura manual junto al de Flameshot (ese ya lo cubre
# test_manual_flameshot_configure.sh).
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_cli_and_scripts.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

manual_section "curl-script: instaladores oficiales descargados y ejecutados"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_starship.sh"      "Starship"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_joplin.sh"  "Joplin"

manual_section "archive-direct: binarios desde un tarball del release oficial"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_procs.sh"         "procs"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_xh.sh"            "xh"

manual_section "git-clone: clonado del repositorio oficial"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_pipes_sh.sh"      "pipes.sh"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_pokemon_colorscripts.sh" "pokemon-colorscripts"

# ---------------------------------------------------------------------
# Verbo `configure` de Starship (Hito 54): instala la Nerd Font MesloLGS
# NF en ~/.local/share/fonts y refresca el cache de fuentes.
#
# Se exige el set completo de 4 variantes: así una descarga cortada se
# repara al volver a correr 'configure' en vez de darse por buena.
# ---------------------------------------------------------------------
manual_section "Starship: verbo 'configure' (Nerd Font MesloLGS NF)"

UCI_FONT_DIR="${HOME}/.local/share/fonts"
UCI_STARSHIP_SH="${UCI_REPO_ROOT}/scripts/system/install_starship.sh"

manual_step "configure debe RECHAZAR si Starship no está instalado"
manual_run_action "${UCI_STARSHIP_SH}" configure
UCI_CONFIGURE_CODE_ANTES="${UCI_MANUAL_LAST_CODE}"
manual_check "Starship: 'configure' rechaza con código distinto de cero si no está instalado" '[[ ${UCI_CONFIGURE_CODE_ANTES} -ne 0 ]]'

manual_step "Instalar Starship para poder configurarlo"
manual_run_action "${UCI_STARSHIP_SH}" install
UCI_STARSHIP_INSTALL_CODE="${UCI_MANUAL_LAST_CODE}"
manual_check "Starship: 'install' previo a 'configure' sale con código 0" '[[ ${UCI_STARSHIP_INSTALL_CODE} -eq 0 ]]'

if [[ "${UCI_STARSHIP_INSTALL_CODE}" -eq 0 ]]; then
    manual_step "configure: primera corrida (descarga la fuente)"
    manual_run_action "${UCI_STARSHIP_SH}" configure
    UCI_CONFIGURE_CODE="${UCI_MANUAL_LAST_CODE}"
    manual_check "Starship: 'configure' sale con código 0 con la herramienta instalada" '[[ ${UCI_CONFIGURE_CODE} -eq 0 ]]'

    UCI_FONT_COUNT="$(find "${UCI_FONT_DIR}" -maxdepth 1 -name 'MesloLGS NF *.ttf' 2>/dev/null | wc -l)"
    manual_note "Variantes de MesloLGS NF encontradas en ${UCI_FONT_DIR}: ${UCI_FONT_COUNT}"
    manual_check "Starship: quedaron las 4 variantes de la Nerd Font instaladas" '[[ "${UCI_FONT_COUNT}" -eq 4 ]]'

    UCI_FC_FOUND=1
    if command -v fc-list &> /dev/null && fc-list 2>/dev/null | grep -qi "MesloLGS"; then
        UCI_FC_FOUND=0
    fi
    manual_check "Starship: fontconfig ya reconoce la fuente (fc-cache corrió de verdad)" '[[ ${UCI_FC_FOUND} -eq 0 ]]'

    manual_step "configure: segunda corrida (debe ser idempotente, sin volver a descargar)"
    manual_run_action "${UCI_STARSHIP_SH}" configure
    UCI_CONFIGURE_CODE_2="${UCI_MANUAL_LAST_CODE}"
    manual_check "Starship: 'configure' es idempotente (segunda corrida también sale 0)" '[[ ${UCI_CONFIGURE_CODE_2} -eq 0 ]]'

    UCI_FONT_COUNT_2="$(find "${UCI_FONT_DIR}" -maxdepth 1 -name 'MesloLGS NF *.ttf' 2>/dev/null | wc -l)"
    manual_check "Starship: la segunda corrida no duplicó ni borró archivos de fuente" '[[ "${UCI_FONT_COUNT_2}" -eq 4 ]]'

    manual_step "Limpieza: desinstalar Starship"
    manual_run_action "${UCI_STARSHIP_SH}" uninstall
    manual_note "La Nerd Font se deja instalada a propósito: es del usuario y la comparte con Powerlevel10k."
fi

manual_section "Paso que NO se puede automatizar"
manual_skip "Confirmar que la terminal MUESTRA los íconos del prompt" \
    "requiere configurar a mano la fuente del emulador de terminal a 'MesloLGS NF' y mirar el resultado"

manual_exit_with_summary
