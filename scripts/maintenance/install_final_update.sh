#!/usr/bin/env bash
# install_final_update.sh
#
# Instalador migrado en el Hito 11 (grupo mantenimiento) al dispatcher
# compartido (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa
# scripts/lib/installer_cli.sh, pero implementa ÚNICAMENTE
# `status`/`install` a propósito — mismo criterio que
# scripts/system/install_system_update.sh: esto es una acción de
# mantenimiento de una sola vía (actualizar y limpiar el sistema), no la
# instalación de una herramienta con algo que "desinstalar" (ver
# docs/adr/0013-separar-mantenimiento-de-instaladores.md).
#
# `uninstall_tool` rechaza explícitamente con código de salida distinto de
# cero (antes de esta migración salía con código 0 sin haber hecho nada,
# un bug real); al no definir `reinstall_tool` propia, el fallback
# mecánico del dispatcher falla por el mismo motivo, sin código adicional.
# `update`/`repair` tampoco se implementan (el dispatcher los rechaza con
# código 3): no hay una semántica de "actualizar la actualización final" ni
# un concepto de "estado roto" aquí.
#
# `status` es un diagnóstico real de solo lectura: reporta si hay
# actualizaciones o paquetes huérfanos pendientes, usando `apt-get
# --simulate` (nunca modifica nada) para el chequeo de autoremove.

set -Eeuo pipefail

UCI_FINAL_UPDATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_FINAL_UPDATE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Final System Update"

# Function to check status
check_status() {
    local upgradable_count autoremovable_count
    upgradable_count="$(apt list --upgradable 2>/dev/null | grep -cv '^Listing' || true)"
    autoremovable_count="$(sudo apt-get --simulate autoremove 2>/dev/null | grep -c '^Remv' || true)"

    if [[ "${upgradable_count}" -eq 0 && "${autoremovable_count}" -eq 0 ]]; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    echo "Esto actualizará y limpiará el sistema."

    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y

    echo "Actualización final del sistema completada."
}

# Function to uninstall
# 'uninstall' no aplica a una acción de mantenimiento de una sola vía: no
# hay nada que desinstalar. Se rechaza explícitamente (código de salida
# distinto de cero), en vez de fingir éxito como antes de esta migración.
uninstall_tool() {
    echo "'uninstall' no aplica a ${TOOL_NAME}: es una acción de mantenimiento (actualizar y limpiar el sistema), no instala nada que se pueda desinstalar." >&2
    return 1
}

installer_run_cli "$@"
