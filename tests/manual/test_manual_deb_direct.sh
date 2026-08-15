#!/usr/bin/env bash
# tests/manual/test_manual_deb_direct.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida los instaladores
# `manager=deb-direct` que no cubre ningún script manual previo. Todos
# descargan un `.deb` (varios resolviendo la URL contra la API de GitHub
# Releases) y lo instalan con APT para que resuelva dependencias.
#
# Lo que este grupo prueba y un contenedor no puede: que la URL del
# último release siga viva y con el nombre de asset esperado, que el
# `.deb` real instale sin dependencias rotas en ESTA versión de Ubuntu, y
# que los `postinst` hagan lo que se supone.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_deb_direct.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

manual_section "Instaladores manager=deb-direct"
manual_note "Heroic y Lutris son las descargas más pesadas de este grupo."

manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_dust.sh"                     "dust"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_localsend.sh"          "LocalSend"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_discord.sh"            "Discord"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_beekeeper_studio.sh"    "Beekeeper Studio"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_dbgate.sh"              "DbGate"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_hoppscotch.sh"          "Hoppscotch"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_lutris.sh"             "Lutris"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_heroic.sh"             "Heroic Games Launcher"

# ---------------------------------------------------------------------
# Orca — caso con verificaciones propias
#
# Dos cosas que solo se pueden comprobar en una máquina real:
#
#   1. El binario del PATH (/usr/bin/orca-ide) NO viene dentro del .deb:
#      lo crea el postinst como symlink hacia /opt/Orca. Si el postinst
#      cambiara, 'status' debería pasar a BROKEN.
#   2. Ubuntu ya trae un paquete llamado 'orca' (el lector de pantalla de
#      GNOME, normalmente instalado en Desktop). El instalador gestiona
#      'orca-ide' y NO debe tocarlo. Un error acá dejaría a alguien sin
#      lector de pantalla, así que se verifica de verdad.
# ---------------------------------------------------------------------
manual_section "Orca (ADE) — y el lector de pantalla 'orca' de GNOME"

UCI_GNOME_ORCA_BEFORE="$(dpkg-query -W -f='${Status}' orca 2>/dev/null || echo "no-instalado")"
manual_note "Estado del paquete 'orca' (lector de pantalla GNOME) ANTES: ${UCI_GNOME_ORCA_BEFORE}"

manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_orca.sh" "Orca"

UCI_GNOME_ORCA_AFTER="$(dpkg-query -W -f='${Status}' orca 2>/dev/null || echo "no-instalado")"
manual_note "Estado del paquete 'orca' (lector de pantalla GNOME) DESPUÉS: ${UCI_GNOME_ORCA_AFTER}"
manual_check "Orca: el paquete 'orca' de GNOME quedó igual que antes (no se tocó accesibilidad)" \
    '[[ "${UCI_GNOME_ORCA_BEFORE}" == "${UCI_GNOME_ORCA_AFTER}" ]]'

manual_step "Orca: el postinst crea /usr/bin/orca-ide (se reinstala para comprobarlo)"
manual_run_action "${UCI_REPO_ROOT}/scripts/development/install_orca.sh" install
UCI_ORCA_INSTALL_CODE="${UCI_MANUAL_LAST_CODE}"
manual_check "Orca: reinstalación para la verificación del symlink sale con código 0" '[[ ${UCI_ORCA_INSTALL_CODE} -eq 0 ]]'

if [[ "${UCI_ORCA_INSTALL_CODE}" -eq 0 ]]; then
    manual_check "Orca: '/usr/bin/orca-ide' existe y es un symlink (lo crea el postinst)" '[[ -L /usr/bin/orca-ide ]]'
    UCI_ORCA_TARGET="$(readlink -f /usr/bin/orca-ide 2>/dev/null || echo "")"
    manual_note "El symlink apunta a: ${UCI_ORCA_TARGET:-(no resuelve)}"
    manual_check "Orca: el symlink apunta dentro del directorio de instalación de Orca" '[[ "${UCI_ORCA_TARGET}" == /opt/Orca/* ]]'
    manual_check "Orca: el ejecutable del PATH se llama 'orca-ide', no 'orca'" '! [[ -e /usr/bin/orca ]] || [[ "$(readlink -f /usr/bin/orca 2>/dev/null)" != /opt/Orca/* ]]'

    manual_step "Orca: limpieza final (uninstall)"
    manual_run_action "${UCI_REPO_ROOT}/scripts/development/install_orca.sh" uninstall
    manual_check "Orca: el postrm quitó '/usr/bin/orca-ide'" '[[ ! -e /usr/bin/orca-ide ]]'

    UCI_GNOME_ORCA_FINAL="$(dpkg-query -W -f='${Status}' orca 2>/dev/null || echo "no-instalado")"
    manual_check "Orca: tras desinstalar, el 'orca' de GNOME sigue intacto" \
        '[[ "${UCI_GNOME_ORCA_BEFORE}" == "${UCI_GNOME_ORCA_FINAL}" ]]'
fi

manual_exit_with_summary
