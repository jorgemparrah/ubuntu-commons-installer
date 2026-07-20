#!/usr/bin/env bash
# install_system_update.sh
#
# Instalador migrado en el Hito 11 (grupo mantenimiento) al dispatcher
# compartido (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa
# scripts/lib/installer_cli.sh, pero implementa ÚNICAMENTE
# `status`/`install` a propósito: esto es una acción de mantenimiento de
# una sola vía (actualizar el sistema), no la instalación de una
# herramienta con algo que "desinstalar" (ver
# docs/adr/0013-separar-mantenimiento-de-instaladores.md).
#
# Antes de esta migración, `uninstall` ya imprimía "no se puede
# desinstalar" pero salía con código 0 (éxito silencioso, un bug real:
# quien invocara `uninstall` en un flujo automatizado nunca se enteraría
# de que no pasó nada). Ahora `uninstall_tool` rechaza explícitamente con
# código de salida distinto de cero, y como no define su propia
# `reinstall_tool`, el fallback mecánico del dispatcher (que llama a
# `uninstall_tool` primero) falla exactamente por el mismo motivo — sin
# necesidad de código adicional. `update`/`repair` tampoco se implementan:
# "actualizar la actualización del sistema" no tiene una semántica propia
# distinta de `install`, y no hay un concepto de "estado roto" que
# justifique `repair` aquí. El dispatcher rechaza ambos con código 3.
#
# `status` es un diagnóstico real de solo lectura: reporta si hay
# actualizaciones pendientes según la última información de apt conocida,
# sin ejecutar `apt update` (eso sería una acción, no un diagnóstico).

set -Eeuo pipefail

UCI_SYSTEM_UPDATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SYSTEM_UPDATE_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="System Updates"

# Function to check status
check_status() {
    local upgradable_count
    upgradable_count="$(apt list --upgradable 2>/dev/null | grep -cv '^Listing' || true)"

    if [[ "${upgradable_count}" -eq 0 ]]; then
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

    sudo apt update
    sudo apt upgrade -y

    echo "Actualizaciones del sistema completadas."
}

# Function to uninstall
# 'uninstall' no aplica a una acción de mantenimiento de una sola vía: no
# hay nada que desinstalar. Se rechaza explícitamente (código de salida
# distinto de cero), en vez de fingir éxito como antes de esta migración.
uninstall_tool() {
    echo "'uninstall' no aplica a ${TOOL_NAME}: es una acción de mantenimiento (actualizar el sistema), no instala nada que se pueda desinstalar." >&2
    return 1
}

installer_run_cli "$@"
