#!/usr/bin/env bash
# tests/test_kernel_hwe_fallback.sh
#
# Prueba unitaria (Hito 9, Fase B) de scripts/system/install_kernel.sh:
# confirma que resolve_hwe_fallback_package_name() construye el nombre de
# paquete HWE con la VERSIÓN NUMÉRICA de Ubuntu (ej. "24.04"), nunca el
# codename (ej. "noble") — bug real detectado en
# docs/UBUNTU_COMPATIBILITY.md que dejaba el fallback apuntando siempre a
# un paquete inexistente.
#
# ALTO RIESGO: install_kernel.sh modifica el kernel de arranque del host.
# Esta prueba NUNCA invoca check_status/install_tool/uninstall_tool/
# update_tool ni el dispatcher (installer_run_cli) — solo sourcea el
# archivo (con guarda BASH_SOURCE==0 para evitar disparar el dispatcher) y
# llama directamente a la función pura de resolución de nombres, que no
# tiene ningún efecto secundario (no instala nada, no modifica GRUB, no
# reinicia, no toca el kernel real). Esta restricción se mantiene incluso
# después de migrar el script al dispatcher compartido en el Hito 11
# (grupo mantenimiento): la separación de responsabilidades entre
# 'install' (rechaza si el kernel ya está presente) y 'update' (upgradea
# uno ya instalado) queda sin cobertura automatizada a propósito, por el
# mismo criterio de riesgo. La instalación real de un kernel HWE requiere
# validación manual en una VM o máquina de prueba dedicada — ver
# docs/UBUNTU_COMPATIBILITY.md.
#
# Uso:
#   bash tests/test_kernel_hwe_fallback.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_KERNEL_SH="${UCI_REPO_ROOT}/scripts/system/install_kernel.sh"
readonly INSTALL_KERNEL_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
echo "== sourcear install_kernel.sh no dispara main() ni ninguna acción real =="
# shellcheck source=/dev/null
source "${INSTALL_KERNEL_SH}"
pass "install_kernel.sh se pudo sourcear sin salir del proceso ni ejecutar acciones"

echo ""
echo "== resolve_hwe_fallback_package_name usa la versión numérica, no el codename =="
RESULT_2404="$(resolve_hwe_fallback_package_name "24.04")"
check_eq() {
    local description="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        pass "${description}"
    else
        fail "${description} (esperado '${expected}', obtenido '${actual}')"
    fi
}
check_eq "24.04 -> linux-generic-hwe-24.04" "linux-generic-hwe-24.04" "${RESULT_2404}"

RESULT_2604="$(resolve_hwe_fallback_package_name "26.04")"
check_eq "26.04 -> linux-generic-hwe-26.04" "linux-generic-hwe-26.04" "${RESULT_2604}"

# Regresión explícita del bug original: si alguien pasara un codename por
# error, el resultado sería obviamente distinto del que arma apt — esta
# prueba documenta que la función NUNCA debe recibir un codename, no que
# lo maneje "bien" (no hay forma correcta de resolver un codename aquí:
# la responsabilidad de pasar la versión numérica es de quien llama).
RESULT_CODENAME="$(resolve_hwe_fallback_package_name "noble")"
check_eq "un codename pasado por error se refleja literal (documenta que NO debe pasarse)" "linux-generic-hwe-noble" "${RESULT_CODENAME}"

echo ""
echo "== el código (no los comentarios) ya no usa 'lsb_release -cs' (codename) =="
# Se ignoran los comentarios: el propio archivo documenta en prosa, en más
# de un lugar, qué patrón tenía el bug original — eso no debe confundirse
# con código real todavía presente (mismo criterio que
# tests/test_install_nodejs_legacy.sh).
install_kernel_code_only() {
    grep -vE '^\s*#' "${INSTALL_KERNEL_SH}"
}
if install_kernel_code_only | grep -q "lsb_release -cs"; then
    fail "install_kernel.sh todavía usa 'lsb_release -cs' (codename) en código real"
else
    pass "install_kernel.sh ya no usa 'lsb_release -cs' en ningún código real"
fi
if install_kernel_code_only | grep -q "lsb_release -rs"; then
    pass "install_kernel.sh usa 'lsb_release -rs' (versión numérica) para el fallback"
else
    fail "install_kernel.sh no usa 'lsb_release -rs' para el fallback"
fi

echo ""
echo "== ninguna acción de alto riesgo (GRUB, reinicio) está presente =="
for forbidden in "update-grub" "grub-mkconfig" "reboot" "shutdown"; do
    if grep -qi "${forbidden}" "${INSTALL_KERNEL_SH}"; then
        fail "install_kernel.sh contiene una referencia a '${forbidden}' (no debería)"
    else
        pass "install_kernel.sh no contiene ninguna referencia a '${forbidden}'"
    fi
done

print_test_summary
echo "Nota: la instalación real de un kernel HWE requiere validación manual"
echo "en una VM o máquina de prueba dedicada (ver docs/UBUNTU_COMPATIBILITY.md)."

exit_with_test_summary
