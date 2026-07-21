#!/usr/bin/env bash
# tests/manual/test_manual_kernel_hwe.sh
#
# Hito 18 (ver docs/ROADMAP.md): scripts/system/install_kernel.sh es ALTO
# RIESGO (modifica el kernel de arranque) y por diseño nunca se prueba
# instalando de verdad, ni en Docker ni en CI (ver el propio encabezado
# del instalador y tests/test_kernel_hwe_fallback.sh, que solo prueba la
# resolución de nombres de paquete de forma pura, sin tocar nada). La
# única forma de validarlo de verdad es en una VM desechable.
#
# A diferencia de los otros scripts de tests/manual/, este es
# DELIBERADAMENTE de solo lectura por defecto: sin argumentos, únicamente
# corre 'status' (seguro, no modifica nada). Instalar de verdad requiere
# el flag --install Y una confirmación interactiva explícita.
#
# Este script NUNCA corre 'uninstall' automáticamente: desinstalar un
# kernel HWE puede dejar la VM sin arrancar. Si querés probar 'uninstall'
# o 'update', hacelo manualmente después, con una VM que puedas
# reiniciar/descartar sin problema, y revisando vos mismo cada paso:
#
#   ./scripts/system/install_kernel.sh update
#   ./scripts/system/install_kernel.sh uninstall
#
# SOLO correr en una VM Ubuntu 24.04/26.04 Desktop DESECHABLE (idealmente
# con snapshot previo), NUNCA en la máquina de desarrollo de este
# repositorio ni en una VM que te importe conservar intacta.
#
# Uso:
#   bash tests/manual/test_manual_kernel_hwe.sh              # solo status, seguro
#   bash tests/manual/test_manual_kernel_hwe.sh --install     # instala de verdad, pide confirmación
set -Eeuo pipefail

if [[ -f /.dockerenv ]]; then
    echo "Este script puede modificar el kernel de arranque y está pensado para" >&2
    echo "una VM desechable, nunca un contenedor Docker. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_SH="${UCI_REPO_ROOT}/scripts/system/install_kernel.sh"
readonly INSTALL_SH

# shellcheck source=lib_manual.sh
source "${UCI_TEST_DIR}/lib_manual.sh"

DO_INSTALL="no"
if [[ "${1:-}" == "--install" ]]; then
    DO_INSTALL="yes"
fi

manual_section "Kernel & Headers HWE: status inicial (siempre seguro, no modifica nada)"
"${INSTALL_SH}" status
STATUS_CODE=$?
echo "(código: ${STATUS_CODE})"

if [[ "${DO_INSTALL}" == "no" ]]; then
    echo ""
    echo "Solo se corrió 'status' (por defecto, sin --install). Para probar la"
    echo "instalación real (ALTO RIESGO, puede requerir reiniciar), volvé a"
    echo "correr este script con --install en una VM desechable:"
    echo ""
    echo "  bash tests/manual/test_manual_kernel_hwe.sh --install"
    exit 0
fi

manual_section "ADVERTENCIA: vas a instalar un kernel HWE de verdad"
echo "Esto modifica el kernel de arranque de esta máquina."
echo "Puede requerir reiniciar. Solo continuar en una VM desechable."
echo ""
read -r -p "Escribí exactamente SI (mayúsculas) para continuar: " CONFIRMACION
if [[ "${CONFIRMACION}" != "SI" ]]; then
    echo "Cancelado por la persona usuaria (no se escribió 'SI' exacto). Nada se modificó."
    exit 1
fi

manual_step "install"
"${INSTALL_SH}" install
INSTALL_CODE=$?
echo "(código: ${INSTALL_CODE})"
manual_check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'

manual_step "status tras instalar"
STATUS_AFTER="$("${INSTALL_SH}" status 2>&1)"
STATUS_AFTER_CODE=$?
echo "${STATUS_AFTER}"
echo "(código: ${STATUS_AFTER_CODE})"
manual_check "'status' reporta INSTALLED tras instalar" '[[ "${STATUS_AFTER}" == *"INSTALLED"* ]]'

echo ""
echo "Recordatorio: puede que necesites reiniciar la VM para que el kernel"
echo "nuevo surta efecto. 'update'/'uninstall' NO se corrieron automáticamente"
echo "— si querés probarlos, hacelo manualmente y con cuidado (ver encabezado)."

manual_exit_with_summary
