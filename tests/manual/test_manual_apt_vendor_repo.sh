#!/usr/bin/env bash
# tests/manual/test_manual_apt_vendor_repo.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida los instaladores
# `manager=apt-vendor-repo` que no cubre ningún script manual previo.
# Cada uno agrega el repositorio APT oficial del proveedor (con su
# keyring) y luego instala el paquete desde ahí.
#
# VirtualBox y Tailscale NO están acá: van en
# test_manual_system_heavy.sh porque tocan el sistema mucho más a fondo
# (módulos del kernel / servicio de red).
#
# Lo que este grupo prueba y un contenedor no puede: que la clave GPG del
# proveedor sea la vigente, que el repo tenga paquete para ESTA versión de
# Ubuntu, y que 'apt-get update' no rompa por una firma inválida.
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop dedicada a esta
# prueba, NUNCA en la máquina de desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_apt_vendor_repo.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

# manual_vendor_repo_case <script> <etiqueta> <patrón_archivo_sources>
# Ciclo de vida completo + la verificación propia del mecanismo: que el
# instalador haya dejado un archivo de repositorio en
# /etc/apt/sources.list.d/ mientras la herramienta está instalada.
manual_vendor_repo_case() {
    local script="$1" label="$2" pattern="$3"

    manual_run_lifecycle "${script}" "${label}"

    # Se consulta DESPUÉS del ciclo: el repositorio del proveedor se deja
    # a propósito tras 'uninstall' (quitarlo rompería otras herramientas
    # que compartan el mismo repo, y APT lo tolera sin problema).
    local found
    found="$(find /etc/apt/sources.list.d -maxdepth 1 -name "${pattern}" 2>/dev/null | head -1)"
    manual_check "${label}: dejó su archivo de repositorio en /etc/apt/sources.list.d (${pattern})" '[[ -n "${found}" ]]'
}

manual_section "Estado de APT antes de empezar"
manual_note "Si 'apt-get update' ya falla acá, cualquier fallo posterior es consecuencia de eso."
sudo apt-get update 2>&1 | tail -20 || true

manual_section "Instaladores manager=apt-vendor-repo"

manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_brave.sh"          "Brave"             "brave*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_signal_desktop.sh" "Signal Desktop"    "signal*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_slack.sh"          "Slack"             "slack*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_element.sh"        "Element"           "element*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_keepassxc.sh"      "KeePassXC"         "keepassxc*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_onlyoffice.sh"     "OnlyOffice"        "onlyoffice*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_syncthing.sh"      "Syncthing"         "syncthing*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/system/install_inkscape.sh"             "Inkscape"          "inkscape*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/system/install_fastfetch.sh"            "fastfetch"         "fastfetch*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/system/install_cloudflared.sh"          "Cloudflare Tunnel" "cloudflare*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/editors/install_vscodium.sh"            "VSCodium"          "vscodium*"
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/development/install_ngrok.sh"           "ngrok"             "ngrok*"

manual_section "Albert (repositorio con URL dependiente de la versión de Ubuntu)"
manual_note "Albert publica en OBS con una ruta distinta por release (xUbuntu_24.04 / xUbuntu_26.04)."
manual_note "Si falla SOLO en una versión de Ubuntu, el problema es que OBS todavía no publicó para ese release."
manual_vendor_repo_case "${UCI_REPO_ROOT}/scripts/productivity/install_albert.sh"         "Albert"            "albert*"

manual_section "APT sigue sano tras agregar todos los repositorios"
UCI_APT_FINAL_CODE=0
sudo apt-get update > /tmp/uci-apt-final.log 2>&1 || UCI_APT_FINAL_CODE=$?
tail -20 /tmp/uci-apt-final.log || true
manual_check "'apt-get update' sigue terminando bien con todos los repos agregados" '[[ ${UCI_APT_FINAL_CODE} -eq 0 ]]'
UCI_APT_WARNINGS="$(grep -ciE "^(W:|E:)" /tmp/uci-apt-final.log 2>/dev/null || true)"
UCI_APT_WARNINGS="${UCI_APT_WARNINGS:-0}"
manual_check "'apt-get update' no emite advertencias ni errores (W:/E:)" '[[ "${UCI_APT_WARNINGS}" -eq 0 ]]'
if [[ "${UCI_APT_WARNINGS}" -ne 0 ]]; then
    manual_note "Detalle de las advertencias/errores:"
    grep -E "^(W:|E:)" /tmp/uci-apt-final.log || true
fi

manual_exit_with_summary
