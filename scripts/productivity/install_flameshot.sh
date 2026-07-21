#!/usr/bin/env bash
# install_flameshot.sh
#
# Instalador migrado en la Fase 2 del Hito 11 (modernización de
# instaladores, ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher y los helpers APT compartidos, misma infraestructura que el
# piloto de la Fase 1 (scripts/system/install_cmatrix.sh).
#
# Comparación con install_cmatrix.sh (antes de esta migración, ambos
# tenían exactamente la misma estructura: dispatcher main()/case, mismo
# fallback a Snap guardado con 'command -v snap'): sin diferencias en la
# gestión del PAQUETE — mismo perfil de riesgo que cmatrix. La única
# diferencia real es conceptual, no de código: ver la nota sobre el atajo
# de PrintScreen más abajo.
#
# Cambio de comportamiento respecto a la versión anterior: se retira el
# fallback a Snap en check_status() (misma razón que cmatrix: la fuente
# oficialmente gestionada por este proyecto es exclusivamente APT).
#
# === Estado del paquete vs. configuración del atajo PrintScreen ===
#
# docs/adr/0019-flameshot-atajo-printscreen.md decide que este instalador
# "debe verificar/configurar el atajo de teclado PrintScreen" apuntando a
# Flameshot. Ese trabajo NUNCA se implementó (confirmado al auditar este
# script para el Hito 9, ver docs/UBUNTU_COMPATIBILITY.md: "brecha
# funcional ya conocida y fuera de alcance") — el script, antes y después
# de esta migración, solo instala/gestiona el PAQUETE `flameshot`, nunca
# toca `gsettings`/`dconf` ni ningún atajo de teclado.
#
# Retomado en el Hito 17 (2026-07-21, ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md): el
# atajo PrintScreen se implementa como `configure_tool()`, el verbo nuevo
# `configure` del contrato — separado de `check_status()`/`install_tool()`
# del paquete, tal como se había previsto acá. Rechaza explícitamente si
# Flameshot no está instalado; respalda la lista de atajos personalizados
# de GNOME antes de tocarla (ADR 0005); es idempotente (no duplica el
# atajo si ya existe). Requiere `gsettings` y una sesión GNOME real — no
# hay prueba automatizada para este verbo (no se puede simular dbus/GNOME
# en los contenedores Docker de este proyecto), validación manual
# pendiente.
#
# Semántica de los 6 verbos del paquete (todos se refieren únicamente al
# paquete `flameshot`, nunca al atajo — el atajo lo maneja el 7° verbo,
# `configure`, documentado por separado más abajo junto a su función):
#   status    — NOT_INSTALLED si el paquete no está instalado (incluye el
#               estado residual 'rc' de dpkg, que apt_package_installed ya
#               distingue). BROKEN si dpkg lo marca instalado pero el
#               binario no resuelve en PATH (instalación corrupta o
#               parcial). OUTDATED si 'apt list --upgradable' (cache LOCAL
#               de apt, sin forzar 'apt-get update' — status debe ser
#               liviano, ver docs/ARCHITECTURE.md §21) muestra una versión
#               candidata más nueva para ESTE paquete puntual — nunca se
#               infiere de que exista una actualización general del
#               sistema pendiente. INSTALLED en cualquier otro caso.
#               Deliberadamente NO reporta nada sobre si el atajo
#               PrintScreen está configurado o no (ver nota arriba).
#               UNSUPPORTED/UNKNOWN no se usan: es un paquete apt simple,
#               sin restricción de arquitectura ni fuente ambigua que
#               justifique esos estados.
#   install   — instala vía apt_install_packages. Si el estado actual es
#               BROKEN, rechaza explícitamente y pide 'repair' en vez de
#               instalar encima de una instalación corrupta.
#   uninstall — apt_purge_packages (purge, no remove, + autoremove).
#   reinstall — 'apt-get install --reinstall' directo, NO el fallback
#               mecánico del dispatcher (uninstall_tool + install_tool):
#               reinstala los archivos del paquete sin el ciclo completo
#               de purge+autoremove.
#   update    — 'apt-get update' + 'apt-get install --only-upgrade', solo
#               este paquete, nunca una actualización general del
#               sistema. Si ya está en la versión más nueva, apt no hace
#               ningún cambio (comportamiento nativo, exit 0).
#   repair    — 'dpkg --configure -a' + 'apt-get install -f' +
#               reinstalación forzada, para el caso BROKEN. Si el paquete
#               no está instalado, rechaza explícitamente en vez de
#               instalarlo desde cero (esa es responsabilidad de
#               'install', no de 'repair').

set -Eeuo pipefail

UCI_FLAMESHOT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_FLAMESHOT_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_FLAMESHOT_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Flameshot"
PACKAGE_NAME="flameshot"

UCI_FLAMESHOT_KEYBINDING_SCHEMA="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
UCI_FLAMESHOT_KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/"
UCI_FLAMESHOT_BACKUP_DIR="${HOME}/.local/state/ubuntu-workstation/backups"

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v flameshot &> /dev/null; then
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
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."
    apt_install_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
    echo "Nota: el atajo PrintScreen no se configura automáticamente durante 'install'. Corre '$0 configure' para configurarlo (ver docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md)." >&2
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    apt_purge_packages "${PACKAGE_NAME}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reinstalado correctamente."
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
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    sudo apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

# Function to configure (atajo de teclado PrintScreen, Hito 17 — ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md).
# Requiere una sesión GNOME real (gsettings/dconf); no hay prueba
# automatizada para este verbo.
configure_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" != "INSTALLED" && "${current_status}" != "OUTDATED" ]]; then
        echo "${TOOL_NAME} no está instalado; corre 'install' antes de 'configure'." >&2
        return 1
    fi

    if ! command -v gsettings &> /dev/null; then
        echo "'gsettings' no está disponible (¿no hay una sesión de escritorio GNOME activa?); no se puede configurar el atajo PrintScreen." >&2
        return 1
    fi

    local current_list
    if ! current_list="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null)"; then
        echo "No se pudo leer la lista de atajos personalizados de GNOME; no se puede configurar el atajo PrintScreen." >&2
        return 1
    fi

    if [[ "${current_list}" == *"${UCI_FLAMESHOT_KEYBINDING_PATH}"* ]]; then
        echo "El atajo PrintScreen para ${TOOL_NAME} ya está configurado."
        return 0
    fi

    mkdir -p "${UCI_FLAMESHOT_BACKUP_DIR}"
    local backup_file="${UCI_FLAMESHOT_BACKUP_DIR}/gnome-custom-keybindings-$(date +%Y%m%d%H%M%S).bak"
    printf '%s\n' "${current_list}" > "${backup_file}"
    echo "Se respaldó la lista de atajos personalizados de GNOME en ${backup_file}."

    local new_list
    if [[ "${current_list}" == "@as []" || "${current_list}" == "[]" ]]; then
        new_list="['${UCI_FLAMESHOT_KEYBINDING_PATH}']"
    else
        new_list="${current_list%]*}, '${UCI_FLAMESHOT_KEYBINDING_PATH}']"
    fi

    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${new_list}"
    gsettings set "${UCI_FLAMESHOT_KEYBINDING_SCHEMA}:${UCI_FLAMESHOT_KEYBINDING_PATH}" name "${TOOL_NAME}"
    gsettings set "${UCI_FLAMESHOT_KEYBINDING_SCHEMA}:${UCI_FLAMESHOT_KEYBINDING_PATH}" command "flameshot gui"
    gsettings set "${UCI_FLAMESHOT_KEYBINDING_SCHEMA}:${UCI_FLAMESHOT_KEYBINDING_PATH}" binding "Print"

    echo "Atajo PrintScreen configurado para lanzar ${TOOL_NAME}."
}

installer_run_cli "$@"
