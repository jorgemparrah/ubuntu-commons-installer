#!/usr/bin/env bash
# install_docker.sh
#
# Instalador migrado en el Hito 11 (grupo vendor-repo) al contrato
# completo de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de repositorio de proveedor
# (scripts/lib/apt_vendor_repo.sh, nuevos en esta migración).
#
# La clave de Docker se descarga ya lista para 'signed-by' (no requiere
# 'gpg --dearmor', a diferencia de VS Code/Cursor) — se usa
# apt_vendor_repo_fetch_key_plain.
#
# Semántica de los 6 verbos (mismo criterio que scripts/system/install_ranger.sh):
#   status    — basado en el paquete 'docker-ce' (representativo del
#               conjunto: docker-ce-cli/containerd.io/*-plugin siempre se
#               instalan/purgan junto con él en este script). BROKEN si
#               dpkg lo marca instalado pero 'docker' no resuelve en PATH.
#               OUTDATED si hay candidato de actualización para
#               'docker-ce' puntualmente.
#   install   — prerequisitos (ca-certificates, curl) + clave + repo +
#               los 5 paquetes. Rechaza sobre BROKEN.
#   uninstall — purga los 5 paquetes (no remove) + limpia clave/repo +
#               grupo 'docker' del usuario, igual que antes de esta
#               migración.
#   reinstall — 'apt-get install --reinstall' de los 5 paquetes, sin
#               volver a tocar clave/repo/grupo.
#   update    — 'apt-get install --only-upgrade' de los 5 paquetes.
#   repair    — 'dpkg --configure -a' + reinstalación forzada de los 5
#               paquetes.

set -Eeuo pipefail

UCI_DOCKER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_DOCKER_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_DOCKER_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_DOCKER_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Docker"
DOCKER_KEYRING=/etc/apt/keyrings/docker.asc
DOCKER_REPO_LIST=/etc/apt/sources.list.d/docker.list
DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)

# Function to check status
check_status() {
    if ! apt_package_installed "docker-ce"; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! command -v docker &> /dev/null; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^docker-ce/"; then
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

    apt_install_packages ca-certificates curl
    apt_vendor_repo_fetch_key_plain "https://download.docker.com/linux/ubuntu/gpg" "${DOCKER_KEYRING}"
    apt_vendor_repo_write_list "${DOCKER_REPO_LIST}" \
        "deb [arch=$(dpkg --print-architecture) signed-by=${DOCKER_KEYRING}] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable"
    apt_install_packages "${DOCKER_PACKAGES[@]}"

    # Se usa 'id -un' en vez de "${USER}": esa variable de entorno no está
    # garantizada (ausente en el contenedor Docker de prueba), y bajo
    # 'set -u' referenciarla sin estar definida aborta el script.
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$(id -un)"

    echo "${TOOL_NAME} instalado correctamente. Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    apt_purge_packages "${DOCKER_PACKAGES[@]}"
    sudo rm -f "${DOCKER_REPO_LIST}" "${DOCKER_KEYRING}"

    # Match exacto de nombre de grupo, no una coincidencia de substring
    # (evita un falso positivo con un grupo hipotético "docker-foo").
    if groups | grep -qw docker; then
        sudo gpasswd -d "$(id -un)" docker
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${DOCKER_PACKAGES[@]}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${DOCKER_PACKAGES[@]}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if ! apt_package_installed "docker-ce"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    sudo apt-get install --reinstall -y "${DOCKER_PACKAGES[@]}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
