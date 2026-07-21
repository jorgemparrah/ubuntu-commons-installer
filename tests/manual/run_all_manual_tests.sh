#!/usr/bin/env bash
# tests/manual/run_all_manual_tests.sh
#
# Hito 18 (ver docs/ROADMAP.md): punto de entrada único para correr toda
# la batería de tests/manual/ en una VM Ubuntu 24.04/26.04 Desktop
# dedicada a esta prueba. Mismo patrón de log que
# tests/docker/build-and-test-all.sh: toda la salida se ve en vivo por
# terminal y además queda guardada en disco, sin necesitar redirección
# manual.
#
# Por defecto corre, en este orden:
#   1. test_manual_snap_apps.sh          (8 instaladores Snap)
#   2. test_manual_ai_and_ide.sh          (Antigravity IDE + 7 candidatas de IA)
#   3. test_manual_flameshot_configure.sh (atajo PrintScreen, requiere sesión GNOME real)
#   4. test_manual_kernel_hwe.sh          (SOLO 'status', sin --install: seguro por defecto)
#
# El kernel HWE NUNCA se instala automáticamente acá: ese paso es de alto
# riesgo (ver el propio script) y se corre aparte, a mano, cuando estés
# listo para asumirlo:
#   bash tests/manual/test_manual_kernel_hwe.sh --install
#
# SOLO correr en una VM Ubuntu Desktop desechable, NUNCA en la máquina de
# desarrollo de este repositorio.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#   bash tests/manual/run_all_manual_tests.sh
set -Eeuo pipefail

if [[ -f /.dockerenv ]]; then
    echo "Estos scripts instalan software real y algunos necesitan una sesión" >&2
    echo "GNOME real. Están pensados para una VM Desktop, no un contenedor" >&2
    echo "Docker. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR

UCI_LOG_DIR="/tmp/ubuntu-workstation-manual-tests"
mkdir -p "${UCI_LOG_DIR}"
UCI_LOG_FILE="${UCI_LOG_DIR}/manual-tests-$(date +%Y%m%dT%H%M%S).log"
readonly UCI_LOG_FILE
UCI_LOG_LATEST="${UCI_LOG_DIR}/manual-tests-latest.log"
readonly UCI_LOG_LATEST

exec > >(tee "${UCI_LOG_FILE}") 2>&1
ln -sf "${UCI_LOG_FILE}" "${UCI_LOG_LATEST}"

echo "Log completo de esta corrida: ${UCI_LOG_FILE}"
echo "(siempre disponible también en: ${UCI_LOG_LATEST}, apunta a la corrida más reciente)"
echo ""
echo "Ubuntu Workstation — batería de pruebas manuales (Hito 18)"
echo "Fecha: $(date)"
echo "Host: $(hostname 2>/dev/null || echo desconocido)"
echo "Ubuntu: $(lsb_release -ds 2>/dev/null || echo desconocido)"

FAILED=0

echo ""
echo "############################################################"
echo "# 1/4 — Instaladores Snap"
echo "############################################################"
if ! bash "${UCI_TEST_DIR}/test_manual_snap_apps.sh"; then
    FAILED=1
fi

echo ""
echo "############################################################"
echo "# 2/4 — Antigravity IDE y candidatas de IA"
echo "############################################################"
if ! bash "${UCI_TEST_DIR}/test_manual_ai_and_ide.sh"; then
    FAILED=1
fi

echo ""
echo "############################################################"
echo "# 3/4 — Flameshot: atajo PrintScreen (requiere sesión GNOME real)"
echo "############################################################"
if ! bash "${UCI_TEST_DIR}/test_manual_flameshot_configure.sh"; then
    FAILED=1
fi

echo ""
echo "############################################################"
echo "# 4/4 — Kernel HWE (solo 'status', seguro por defecto)"
echo "############################################################"
if ! bash "${UCI_TEST_DIR}/test_manual_kernel_hwe.sh"; then
    FAILED=1
fi

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "RESULTADO: TODO PASÓ (salvo lo que solo puede confirmarse a mano, ver arriba)"
else
    echo "RESULTADO: HUBO FALLOS. Revisar la salida arriba."
fi

echo ""
echo "Log completo guardado en: ${UCI_LOG_FILE}"
echo "(symlink a la corrida más reciente: ${UCI_LOG_LATEST})"

exit "${FAILED}"
