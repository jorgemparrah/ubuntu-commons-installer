#!/usr/bin/env bash
# install_cmatrix.sh
#
# Instalador piloto de la Fase 1 del Hito 11 (modernización de
# instaladores, ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh) y los helpers APT
# compartidos (scripts/lib/apt.sh) en vez de duplicar su propio bloque
# main()/case y su propia lógica de dpkg (que hasta esta migración
# repetía, línea por línea, en ~29 instaladores del proyecto).
#
# Se eligió cmatrix como piloto (sugerido explícitamente al iniciar esta
# fase): un solo paquete APT, sin archivo de configuración propio, sin
# servicio de sistema, sin GUI — la señal más simple posible para validar
# la infraestructura compartida antes de migrar instaladores más
# complejos en los próximos grupos del Hito 11.
#
# Cambio de comportamiento respecto a la versión anterior de este script:
# ya NO tiene fallback a Snap en check_status(). La instalación
# oficialmente gestionada por este proyecto para cmatrix es exclusivamente
# APT (nunca se instala vía Snap en install_tool()); ese fallback
# (agregado en el cierre de la revisión técnica de 2026-07-19, hallazgo
# M7, "por si alguien lo instaló manualmente por Snap") queda retirado a
# propósito en la migración completa: mantenerlo mezclaría dos fuentes de
# verdad para una herramienta cuya única fuente gestionada es APT.
#
# Semántica de los 6 verbos para esta herramienta:
#   status    — INSTALLED / NOT_INSTALLED siempre. OUTDATED si el cache
#               LOCAL de apt (`apt list --upgradable`, sin forzar un
#               `apt-get update` desde acá — 'status' debe ser liviano,
#               ver docs/ARCHITECTURE.md §21) muestra una versión más
#               nueva disponible. BROKEN si dpkg reporta el paquete
#               instalado (`ii`) pero el binario no resuelve en PATH
#               (instalación corrupta o parcial).
#               Limitación honesta, documentada explícitamente en vez de
#               inventar una detección más fuerte: si nadie corrió
#               `apt-get update` recientemente, un OUTDATED real puede no
#               detectarse (falso negativo) — nunca se reporta un
#               OUTDATED falso. Mismo criterio exacto que el instalador de
#               referencia, scripts/editors/install_vim.sh.
#   install   — `apt_install_packages` (apt-get update + install -y).
#   uninstall — `apt_purge_packages` (apt-get purge, no remove, + autoremove).
#   reinstall — sin función propia: usa el fallback mecánico del
#               dispatcher (uninstall_tool + install_tool). cmatrix no
#               tiene estado propio que preservar entre una desinstalación
#               y la siguiente instalación, así que ese fallback genérico
#               es suficiente y correcto para esta herramienta.
#   update    — `apt-get update` + `apt-get install --only-upgrade`, para
#               el caso OUTDATED.
#   repair    — `dpkg --configure -a` + `apt-get install -f` + reinstalación
#               forzada del paquete, para el caso BROKEN. Mismo
#               procedimiento que install_vim.sh.

set -Eeuo pipefail

UCI_CMATRIX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_CMATRIX_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_CMATRIX_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="cmatrix"
PACKAGE_NAME="cmatrix"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v cmatrix &> /dev/null; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    apt_install_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
