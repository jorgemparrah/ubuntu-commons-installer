#!/usr/bin/env bash
# tests/manual/test_manual_system_heavy.sh
#
# Hito 19 (ver docs/ROADMAP.md): valida los instaladores que modifican el
# SISTEMA más allá de instalar un paquete — grupos de usuario, arquitecturas
# de dpkg, servicios, permisos de captura. Son los que más justifican una
# VM desechable y los que peor se pueden simular con mocks.
#
#   - Wireshark   : preseed de debconf + grupo 'wireshark' (permisos de captura)
#   - Steam       : habilita la arquitectura i386 en dpkg
#   - virt-manager: instala 6 paquetes y agrega a los grupos 'libvirt' y 'kvm'
#   - Tailscale   : servicio systemd de red
#   - LibreOffice : suite completa desde los repos de Ubuntu (descarga grande)
#   - SoapUI      : instalador IzPack (Java) fuera del gestor de paquetes
#
# VirtualBox queda FUERA por defecto: compila módulos del kernel y, con
# Secure Boot activo, abre un diálogo interactivo de inscripción de clave
# (MOK) que puede dejar la VM esperando input o sin poder levantar las
# VMs hasta reiniciar. Se corre aparte, a conciencia:
#
#   bash tests/manual/test_manual_system_heavy.sh --include-virtualbox
#
# Mismo criterio que test_manual_kernel_hwe.sh con su '--install'.
#
# ⚠️ Varios de estos cambios NO se revierten del todo al desinstalar (la
# arquitectura i386, los grupos de usuario). Es esperable, pero es otra
# razón para correr esto solo en una VM que puedas descartar.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/test_manual_system_heavy.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT

UCI_INCLUDE_VIRTUALBOX=0
if [[ "${1:-}" == "--include-virtualbox" ]]; then
    UCI_INCLUDE_VIRTUALBOX=1
fi

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"
manual_require_vm

UCI_CURRENT_USER="$(id -un)"

# ---------------------------------------------------------------------
# Wireshark: el punto real no es que instale, sino que la captura de
# paquetes quede utilizable SIN sudo. El default de debconf es 'false', y
# con ese default la función principal de la herramienta queda rota; el
# instalador hace un preseed para forzar 'true'.
# ---------------------------------------------------------------------
manual_section "Wireshark (grupo de captura y preseed de debconf)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_wireshark.sh" "Wireshark"

manual_step "Wireshark: reinstalar para inspeccionar los permisos de captura"
manual_run_action "${UCI_REPO_ROOT}/scripts/system/install_wireshark.sh" install
UCI_WS_CODE="${UCI_MANUAL_LAST_CODE}"
manual_check "Wireshark: reinstalación para la verificación sale con código 0" '[[ ${UCI_WS_CODE} -eq 0 ]]'

if [[ "${UCI_WS_CODE}" -eq 0 ]]; then
    manual_check "Wireshark: existe el grupo 'wireshark'" 'getent group wireshark > /dev/null'
    manual_note "Miembros del grupo 'wireshark': $(getent group wireshark | cut -d: -f4)"
    manual_check "Wireshark: el usuario actual (${UCI_CURRENT_USER}) quedó en el grupo 'wireshark'" \
        'id -nG "${UCI_CURRENT_USER}" | tr " " "\n" | grep -qx wireshark'

    manual_note "Permisos de /usr/bin/dumpcap:"
    ls -l /usr/bin/dumpcap 2>/dev/null || echo "  (no existe)"
    getcap /usr/bin/dumpcap 2>/dev/null || true
    manual_check "Wireshark: 'dumpcap' pertenece al grupo 'wireshark' (el preseed tomó efecto)" \
        '[[ "$(stat -c %G /usr/bin/dumpcap 2>/dev/null)" == "wireshark" ]]'
    manual_note "El cambio de grupo recién aplica tras cerrar y reabrir sesión."

    manual_run_action "${UCI_REPO_ROOT}/scripts/system/install_wireshark.sh" uninstall
fi

manual_section "Steam (habilita la arquitectura i386)"
manual_note "Arquitecturas dpkg ANTES: $(dpkg --print-foreign-architectures | tr '\n' ' ')"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_steam.sh" "Steam"
manual_note "Arquitecturas dpkg DESPUÉS: $(dpkg --print-foreign-architectures | tr '\n' ' ')"
manual_check "Steam: la arquitectura 'i386' quedó habilitada (sin ella steam-libs-i386 no resuelve)" \
    'dpkg --print-foreign-architectures | grep -qx i386'
manual_note "i386 NO se deshabilita al desinstalar: otras herramientas pueden depender de ella."

manual_section "virt-manager (6 paquetes + grupos 'libvirt' y 'kvm')"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_virt_manager.sh" "virt-manager"

manual_step "virt-manager: reinstalar para inspeccionar grupos y servicio"
manual_run_action "${UCI_REPO_ROOT}/scripts/development/install_virt_manager.sh" install
UCI_VM_CODE="${UCI_MANUAL_LAST_CODE}"
if [[ "${UCI_VM_CODE}" -eq 0 ]]; then
    manual_check "virt-manager: el usuario quedó en el grupo 'libvirt'" 'id -nG "${UCI_CURRENT_USER}" | tr " " "\n" | grep -qx libvirt'
    manual_check "virt-manager: el usuario quedó en el grupo 'kvm'" 'id -nG "${UCI_CURRENT_USER}" | tr " " "\n" | grep -qx kvm'
    manual_note "Estado de libvirtd:"
    systemctl is-active libvirtd 2>&1 || true
    manual_note "kvm-ok (si la VM no tiene virtualización anidada, dará negativo y es esperable):"
    kvm-ok 2>&1 || true
    manual_run_action "${UCI_REPO_ROOT}/scripts/development/install_virt_manager.sh" uninstall
fi

manual_section "Tailscale (servicio systemd de red)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/system/install_tailscale.sh" "Tailscale"
manual_skip "Autenticar el nodo con 'tailscale up'" "requiere credenciales reales de una tailnet"

manual_section "LibreOffice (suite completa, descarga grande)"
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/productivity/install_libreoffice.sh" "LibreOffice"

manual_section "SoapUI (instalador IzPack sobre Java)"
manual_note "Único caso del mecanismo izpack-installer: corre un instalador Java en modo desatendido."
manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_soapui.sh" "SoapUI"

manual_section "VirtualBox (módulos del kernel — opt-in)"
if [[ "${UCI_INCLUDE_VIRTUALBOX}" -eq 1 ]]; then
    manual_note "Corriendo VirtualBox por pedido explícito (--include-virtualbox)."
    manual_note "Si Secure Boot está activo, puede abrirse un diálogo de inscripción de clave (MOK)."
    manual_run_lifecycle "${UCI_REPO_ROOT}/scripts/development/install_virtualbox.sh" "VirtualBox"
    manual_note "Módulos del kernel cargados (puede requerir reiniciar para verlos):"
    lsmod | grep -i vbox || echo "  (ninguno cargado todavía)"
else
    manual_skip "VirtualBox" "no se corre por defecto; usar --include-virtualbox en una VM que puedas descartar"
fi

manual_exit_with_summary
