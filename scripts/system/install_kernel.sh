#!/usr/bin/env bash
# install_kernel.sh
#
# ALTO RIESGO: modifica el kernel de arranque del host. Nunca se prueba
# instalando de verdad (ni en Docker ni en CI) — solo la lógica de
# resolución de nombres de paquete se prueba de forma unitaria/simulada
# (ver tests/test_kernel_hwe_fallback.sh). La instalación real requiere
# validación manual en una VM o máquina de prueba dedicada, nunca en la
# máquina de desarrollo ni en un contenedor compartido.
#
# Instalador migrado en el Hito 11 (grupo mantenimiento) al dispatcher
# compartido (scripts/lib/installer_cli.sh, ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). A
# diferencia de install_system_update.sh/install_final_update.sh, este sí
# tiene un `install`/`uninstall` con sentido real (instalar/quitar
# paquetes de kernel HWE), así que conserva los 6 verbos.
#
# Aprovechando la migración, se separó una responsabilidad que antes vivía
# mezclada dentro de `install_tool`: si el kernel ya estaba instalado,
# `install` upgradeaba automáticamente sobre él — contradiciendo el
# mapeo por defecto del proyecto (ADR 0004: INSTALLED/OUTDATED → skip/
# update, nunca 'install' de nuevo). Ahora `install_tool` rechaza
# explícitamente si el kernel HWE ya está presente (sugiere `update`), y
# la lógica de actualización quedó en `update_tool`.
#
# `status` no distingue BROKEN: a diferencia de un paquete simple, no hay
# una forma barata de detectar una instalación de kernel "parcial" sin
# arriesgo (por ejemplo, sin regenerar la configuración de arranque) —
# limitación honesta, no una detección inventada. `repair` no se
# implementa por el mismo motivo;
# el dispatcher lo rechaza explícitamente (código 3).

set -Eeuo pipefail
TOOL_NAME="Kernel & Headers"
UCI_KERNEL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_KERNEL_SCRIPT_DIR}/../lib/installer_cli.sh"

# Function to check status
#
# OUTDATED se basa en el cache LOCAL de apt ('apt list --upgradable', sin
# forzar un 'apt update' desde acá — 'status' debe ser liviano, ver
# docs/ARCHITECTURE.md §21). Si nadie corrió 'apt update' recientemente,
# un OUTDATED real puede no detectarse (falso negativo) — nunca se reporta
# un OUTDATED falso.
check_status() {
    if ! dpkg -l | grep -q "linux-generic-hwe"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "linux-generic-hwe"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

# resolve_hwe_fallback_package_name <ubuntu_release_version>
# Construye el nombre del paquete HWE de fallback a partir de la VERSIÓN
# NUMÉRICA de Ubuntu (ej. "24.04"), nunca el codename (ej. "noble") — el
# paquete real se llama linux-generic-hwe-24.04, no linux-generic-hwe-noble.
# Bug real encontrado en la auditoría de docs/UBUNTU_COMPATIBILITY.md:
# antes se usaba 'lsb_release -cs' (codename) para este fallback, generando
# un nombre de paquete que nunca existe. Extraída como función pura (sin
# I/O) para poder probarla sin instalar nada.
resolve_hwe_fallback_package_name() {
    local ubuntu_release_version="$1"
    echo "linux-generic-hwe-${ubuntu_release_version}"
}

# Function to get the latest available HWE kernel
get_latest_hwe_kernel() {
    # Update package list to get latest available kernels
    sudo apt update

    # Find the latest HWE kernel available
    local latest_kernel
    latest_kernel="$(apt list --upgradable 2>/dev/null | grep "linux-generic-hwe" | tail -1 | cut -d'/' -f1)"

    if [[ -n "$latest_kernel" ]]; then
        echo "$latest_kernel"
    else
        # Fallback a la versión numérica de Ubuntu (lsb_release -rs), NUNCA
        # el codename (lsb_release -cs) — ver resolve_hwe_fallback_package_name.
        local ubuntu_release_version
        ubuntu_release_version="$(lsb_release -rs)"
        resolve_hwe_fallback_package_name "${ubuntu_release_version}"
    fi
}

# Function to install
install_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "INSTALLED" || "${current_status}" == "OUTDATED" ]]; then
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install' para actualizarlo." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."
    echo "HWE Kernel no encontrado. Instalando última versión..."

    # 'local var=$(cmd)' enmascara el código de salida de cmd bajo el modo
    # estricto (set -e no vería un fallo de get_latest_hwe_kernel, porque
    # el propio 'local' siempre sale 0) — se separa en dos líneas.
    local latest_kernel
    latest_kernel="$(get_latest_hwe_kernel)"
    echo "Instalando: $latest_kernel"

    sudo apt install -y --install-recommends "$latest_kernel"
    sudo apt install -y linux-firmware linux-headers-generic

    echo "${TOOL_NAME} instalado correctamente."
    echo "Es posible que necesites reiniciar para que el nuevo kernel surta efecto."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    echo "ADVERTENCIA: Desinstalar el kernel puede hacer que el sistema no arranque."
    echo "Este comando solo eliminará kernels HWE específicos, manteniendo el kernel base."

    sudo apt remove -y linux-generic-hwe* linux-headers-generic-hwe*
    sudo apt autoremove -y

    echo "Kernels HWE desinstalados correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    if ! dpkg -l | grep -q "linux-generic-hwe"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    sudo apt update

    if apt list --upgradable 2>/dev/null | grep -q "linux-generic-hwe"; then
        sudo apt upgrade -y linux-generic-hwe* linux-headers-generic linux-firmware
        echo "${TOOL_NAME} actualizado correctamente."
        echo "Es posible que necesites reiniciar para que el nuevo kernel surta efecto."
    else
        echo "${TOOL_NAME} ya está actualizado."
    fi
}

# Permite sourcear este archivo desde una prueba (para llamar directamente
# a resolve_hwe_fallback_package_name) sin disparar installer_run_cli, que
# de otro modo terminaría el proceso que lo sourcea con 'exit 1' si no
# recibe un subcomando válido.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    installer_run_cli "$@"
fi
