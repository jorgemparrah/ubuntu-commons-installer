#!/usr/bin/env bash
# tests/manual/test_manual_flameshot_configure.sh
#
# Hito 18 (ver docs/ROADMAP.md): valida el verbo `configure` nuevo de
# scripts/productivity/install_flameshot.sh (Hito 17, ADR 0042) contra
# una sesión GNOME REAL (gsettings/dbus). Ningún contenedor Docker de
# este proyecto tiene una sesión de escritorio real, así que esto nunca
# se pudo probar de punta a punta hasta ahora (ver docs/TESTING.md, "Qué
# no reemplaza esto").
#
# Este script confirma que 'configure' deja el atajo bien escrito en
# GNOME (vía 'gsettings get', sin asumir nada). Lo único que NO puede
# automatizar es apretar físicamente la tecla PrintScreen y confirmar que
# Flameshot realmente se abre — ese último paso queda para que lo
# confirmes vos mismo al final.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop con sesión GNOME real
# (no en modo headless, no por SSH sin sesión gráfica activa), nunca en
# la máquina de desarrollo de este repositorio.
#
# Uso (desde una terminal DENTRO de la sesión gráfica de la VM):
#   bash tests/manual/test_manual_flameshot_configure.sh 2>&1 | tee /tmp/manual-flameshot-configure.log
set -Eeuo pipefail

if [[ -f /.dockerenv ]]; then
    echo "Este script necesita una sesión GNOME real (gsettings/dbus) y está" >&2
    echo "pensado para una VM Desktop, nunca un contenedor Docker. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/productivity/install_flameshot.sh"
readonly INSTALL_SH
readonly UCI_KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"

manual_section "gsettings disponible (sesión GNOME real)"
if command -v gsettings &> /dev/null && gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings &> /dev/null; then
    echo "  OK    - 'gsettings' responde en esta sesión, se puede continuar"
else
    echo "  FALLO - 'gsettings' no responde. ¿Estás dentro de una sesión gráfica GNOME real (no headless/SSH sin X)?" >&2
    exit 1
fi

manual_section "Flameshot: asegurar que el paquete esté instalado"
"${INSTALL_SH}" status
STATUS_BEFORE_CODE=$?
if [[ "${STATUS_BEFORE_CODE}" -ne 0 ]]; then
    manual_step "install (Flameshot no estaba instalado)"
    "${INSTALL_SH}" install
    INSTALL_CODE=$?
    manual_check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'
fi

manual_section "configure: primera corrida (debe agregar el atajo)"
CONFIGURE_LIST_BEFORE="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
echo "Lista de atajos ANTES: ${CONFIGURE_LIST_BEFORE}"

"${INSTALL_SH}" configure
CONFIGURE_CODE=$?
echo "(código: ${CONFIGURE_CODE})"
manual_check "'configure' sale con código 0" '[[ ${CONFIGURE_CODE} -eq 0 ]]'

CONFIGURE_LIST_AFTER="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
echo "Lista de atajos DESPUÉS: ${CONFIGURE_LIST_AFTER}"
manual_check "la lista de custom-keybindings de GNOME incluye el atajo de Flameshot" '[[ "${CONFIGURE_LIST_AFTER}" == *"${UCI_KEYBINDING_PATH}"* ]]'

KEYBINDING_COMMAND="$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${UCI_KEYBINDING_PATH}" command 2>&1)"
KEYBINDING_BINDING="$(gsettings get "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${UCI_KEYBINDING_PATH}" binding 2>&1)"
echo "Comando configurado: ${KEYBINDING_COMMAND}"
echo "Tecla configurada: ${KEYBINDING_BINDING}"
manual_check "el comando configurado es 'flameshot gui'" '[[ "${KEYBINDING_COMMAND}" == *"flameshot gui"* ]]'
manual_check "la tecla configurada es 'Print'" '[[ "${KEYBINDING_BINDING}" == *"Print"* ]]'

manual_section "configure: segunda corrida (debe ser idempotente, no duplicar)"
"${INSTALL_SH}" configure
CONFIGURE_CODE_2=$?
echo "(código: ${CONFIGURE_CODE_2})"
manual_check "'configure' sale con código 0 la segunda vez" '[[ ${CONFIGURE_CODE_2} -eq 0 ]]'

CONFIGURE_LIST_TWICE="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
OCCURRENCES="$(grep -o "${UCI_KEYBINDING_PATH}" <<< "${CONFIGURE_LIST_TWICE}" | wc -l)"
echo "Ocurrencias del atajo en la lista tras la segunda corrida: ${OCCURRENCES}"
manual_check "el atajo aparece una sola vez (no se duplicó)" '[[ "${OCCURRENCES}" -eq 1 ]]'

manual_section "Respaldo previo a la primera modificación"
if find "${HOME}/.local/state/ubuntu-workstation/backups" -maxdepth 1 -name 'gnome-custom-keybindings-*.bak' 2>/dev/null | grep -q .; then
    echo "  OK    - hay al menos un respaldo de la lista de atajos en ~/.local/state/ubuntu-workstation/backups"
    find "${HOME}/.local/state/ubuntu-workstation/backups" -maxdepth 1 -name 'gnome-custom-keybindings-*.bak'
else
    echo "  FALLO - no se encontró ningún respaldo de la lista de atajos" >&2
    UCI_MANUAL_CHECKS=$((UCI_MANUAL_CHECKS + 1))
    UCI_MANUAL_FAILS=$((UCI_MANUAL_FAILS + 1))
fi

echo ""
echo "======================================================================"
echo "== Último paso, MANUAL (no automatizable): confirmalo vos mismo"
echo "======================================================================"
echo "Apretá la tecla PrintScreen ahora en esta VM y confirmá a mano que"
echo "Flameshot se abre para capturar pantalla. Anotá el resultado (SI/NO)"
echo "al pasarme el log de este script."

manual_exit_with_summary
