#!/usr/bin/env bash
# install_wireshark.sh
#
# Instalador nuevo (Hito 52, ver docs/ROADMAP.md): agrega Wireshark al
# catálogo (category=system, subcategory=network-analysis — NUEVA, ver la
# nota de decisión abajo). Usa el dispatcher y los helpers APT
# compartidos.
#
# El paquete `wireshark` está en los repositorios oficiales de Ubuntu
# (universe), con binario homónimo (confirmado inspeccionando el `.deb`
# real). Pero NO es un apt-simple más: tiene dos pasos de configuración
# que sin gestionarlos dejan la herramienta a medias.
#
# ── Captura de paquetes sin root ────────────────────────────────────
# `wireshark-common` pregunta vía debconf (`wireshark-common/install-setuid`,
# **Default: false**, confirmado leyendo su `templates` real) si los
# usuarios no-root deben poder capturar. Su `postinst` (leído en vivo)
# hace lo siguiente según la respuesta:
#   - false → `dumpcap` queda root:root 0755: SOLO root captura.
#   - true  → crea el grupo de sistema `wireshark`, hace
#             `chown root:wireshark` sobre `dumpcap` y le aplica
#             `setcap cap_net_raw,cap_net_admin=eip`.
#
# Como el default es `false`, un `apt-get install -y wireshark` a secas
# deja una instalación donde la persona usuaria no puede capturar sin
# sudo — no es un detalle cosmético, es la función principal de la
# herramienta. Por eso este instalador preconfigura la respuesta en
# `true` con `debconf-set-selections` ANTES de instalar, y usa
# `DEBIAN_FRONTEND=noninteractive` para que apt no se cuelgue esperando
# la pregunta (mismo criterio que install_ubuntu_restricted_extras.sh
# con el EULA de las fuentes de Microsoft).
#
# El paquete crea el grupo pero NO agrega a nadie: este instalador agrega
# al usuario actual a `wireshark`, mismo patrón que
# install_virtualbox.sh con `vboxusers` (Hito 24). Igual que allí, el
# cambio de grupo recién surte efecto al reiniciar la sesión, y se avisa.
#
# ── Decisión de subcategoría ────────────────────────────────────────
# El objetivo del Hito dejaba abierto si encaja en `networking` (ámbito
# ampliado en el Hito 46) o merece una propia. Se opta por
# `subcategory=network-analysis` nueva: `networking` agrupa VPNs y
# túneles (WireGuard, OpenVPN, Tailscale, Cloudflare Tunnel, ngrok) —
# herramientas que MUEVEN tráfico. Wireshark lo INSPECCIONA; son
# propósitos distintos, y el catálogo ya usa subcategorías granulares
# (cli-utils/terminals/extras/launchers/iac/cloud-cli/...) en vez de
# bolsas amplias.

set -Eeuo pipefail

UCI_WIRESHARK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_WIRESHARK_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_WIRESHARK_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Wireshark"
PACKAGE_NAME="wireshark"
UCI_WIRESHARK_GROUP="wireshark"

# wireshark_preseed_capture_permissions
# Preconfigura la respuesta debconf para que el propio postinst de
# wireshark-common cree el grupo y aplique setcap sobre dumpcap. Sin
# esto, el default (`false`) deja la captura restringida a root.
wireshark_preseed_capture_permissions() {
    echo "wireshark-common wireshark-common/install-setuid boolean true" \
        | sudo debconf-set-selections
}

# Function to check status
check_status() {
    if ! apt_package_installed "${PACKAGE_NAME}"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v wireshark &> /dev/null; then
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

    wireshark_preseed_capture_permissions
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGE_NAME}"

    # El paquete crea el grupo 'wireshark' (vía su postinst, con la
    # respuesta debconf ya preconfigurada arriba) pero no agrega a nadie.
    sudo usermod -aG "${UCI_WIRESHARK_GROUP}" "$(id -un)"

    echo "${TOOL_NAME} instalado correctamente. Es necesario cerrar sesión y volver a iniciar para que la pertenencia al grupo '${UCI_WIRESHARK_GROUP}' surta efecto y puedas capturar paquetes sin sudo."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    apt_purge_packages "${PACKAGE_NAME}"

    # Match exacto de nombre de grupo, no una coincidencia de substring
    # (mismo criterio que install_virtualbox.sh con 'vboxusers').
    if groups | grep -qw "${UCI_WIRESHARK_GROUP}"; then
        sudo gpasswd -d "$(id -un)" "${UCI_WIRESHARK_GROUP}"
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "${PACKAGE_NAME}"
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
    wireshark_preseed_capture_permissions
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
