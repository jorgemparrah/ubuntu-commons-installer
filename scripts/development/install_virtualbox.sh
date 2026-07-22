#!/usr/bin/env bash
# install_virtualbox.sh
#
# Instalador nuevo (Hito 24, ver docs/ROADMAP.md): agrega VirtualBox al
# catálogo. Usa el dispatcher compartido (scripts/lib/installer_cli.sh),
# los helpers APT (scripts/lib/apt.sh) y los helpers de repositorio de
# proveedor (scripts/lib/apt_vendor_repo.sh) — mismo mecanismo
# `apt-vendor-repo` que Docker/VS Code/Cursor/Brave.
#
# Fuente: el paquete `virtualbox` de los repositorios oficiales de Ubuntu
# (universe/multiverse) suele quedar varias versiones atrás de la última
# de Oracle — se usa el repositorio APT oficial de Oracle
# (download.virtualbox.org), nunca el de Ubuntu (ver criterio explícito
# del dueño del proyecto: priorizar siempre la fuente más actualizada).
#
# Oracle NO publica un paquete meta "virtualbox" genérico en su
# repositorio: cada versión mayor tiene su propio nombre de paquete
# (`virtualbox-7.1`, `virtualbox-7.2`, etc.), que cambiaría y quedaría
# obsoleto si se hardcodeara acá. Por eso, tras agregar el repositorio, el
# nombre del paquete a instalar se resuelve dinámicamente con
# `vbox_latest_available_package` (mismo criterio ya usado por
# `install_kernel.sh::get_latest_hwe_kernel` para no hardcodear un nombre
# de paquete que cambia con el tiempo). `vbox_installed_package` hace lo
# mismo para `status`/`uninstall`/`update`/`repair`, detectando CUALQUIER
# paquete `virtualbox-X.Y` ya instalado, sin asumir cuál.
#
# Primer instalador de este proyecto que depende de compilar/cargar un
# módulo de kernel (`vboxdrv`, vía DKMS) — requiere
# `linux-headers-$(uname -r)` además de `dkms`. `status` distingue BROKEN
# (paquete instalado pero `/dev/vboxdrv` ausente: el módulo no cargó) de
# INSTALLED (módulo cargado y funcional) — algo que ningún instalador
# anterior necesitaba, porque ninguno tocaba el kernel. Por el mismo
# motivo, `requires_manual_validation=yes` en tools_catalog.sh: ningún
# contenedor Docker de este proyecto puede cargar un módulo de kernel de
# verdad (comparten el kernel del host, sin garantía de que
# linux-headers-$(uname -r) esté disponible ahí) — la validación real
# queda para tests/manual/ (Hito 19), no para CI.
#
# El "VirtualBox Extension Pack" (licencia PUEL, no libre, distinta a la
# del núcleo de VirtualBox) queda deliberadamente fuera de este
# instalador — es un componente aparte con su propia licencia, que no se
# instala sin que se pida explícitamente.
#
# Semántica de los 6 verbos (mismo patrón que install_docker.sh):
#   status    — NOT_INSTALLED si no hay ningún paquete `virtualbox-X.Y`
#               instalado. BROKEN si el paquete está instalado pero
#               `/dev/vboxdrv` no existe (módulo de kernel no cargado).
#               OUTDATED si hay candidato de actualización para ESE
#               paquete puntual. INSTALLED en cualquier otro caso.
#   install   — agrega la clave GPG + el repositorio de Oracle, detecta el
#               paquete `virtualbox-X.Y` más nuevo disponible, instala
#               `linux-headers-$(uname -r)`/`dkms`/el paquete, y agrega el
#               usuario al grupo `vboxusers` (igual criterio que
#               install_docker.sh con el grupo `docker`). Rechaza sobre
#               INSTALLED/OUTDATED (pide 'update') y sobre BROKEN (pide
#               'repair').
#   uninstall — purga el paquete detectado + limpia clave/repo/grupo.
#   reinstall — 'apt-get install --reinstall' del paquete detectado.
#   update    — 'apt-get install --only-upgrade' del paquete detectado.
#   repair    — 'dpkg --configure -a' + reinstalación de
#               linux-headers/dkms/el paquete + 'dkms autoinstall', para
#               el caso BROKEN (típicamente: el kernel se actualizó y el
#               módulo quedó sin recompilar contra el nuevo).

set -Eeuo pipefail

UCI_VIRTUALBOX_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_VIRTUALBOX_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/apt_vendor_repo.sh
source "${UCI_VIRTUALBOX_SCRIPT_DIR}/../lib/apt_vendor_repo.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_VIRTUALBOX_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="VirtualBox"
VIRTUALBOX_KEYRING=/usr/share/keyrings/oracle-virtualbox-2016.gpg
VIRTUALBOX_REPO_LIST=/etc/apt/sources.list.d/virtualbox.list
VIRTUALBOX_KEY_URL="https://www.virtualbox.org/download/oracle_vbox_2016.asc"
VIRTUALBOX_REPO_URL="https://download.virtualbox.org/virtualbox/debian"
# Ruta del dispositivo del módulo de kernel, simulable para pruebas
# (mismo criterio que UCI_HOME_DIR para $HOME, ver
# docs/adr/0023-variable-uci-home-dir-para-pruebas.md, extendido acá por
# primera vez a un dispositivo en vez de un directorio): ningún
# contenedor Docker de este proyecto puede cargar un módulo de kernel de
# verdad, así que las pruebas mockeadas simulan su presencia/ausencia
# apuntando esta variable a un archivo temporal en vez de /dev/vboxdrv.
VIRTUALBOX_VBOXDRV_PATH="${UCI_VIRTUALBOX_VBOXDRV_PATH:-/dev/vboxdrv}"

# vbox_installed_package
# Cualquier paquete 'virtualbox-X.Y' que dpkg reporte instalado ('ii'),
# sin asumir cuál (puede cambiar de una versión mayor a otra con el
# tiempo). Vacío si no hay ninguno.
vbox_installed_package() {
    dpkg -l 2>/dev/null | awk '$1 == "ii" && $2 ~ /^virtualbox-[0-9]/ { print $2; exit }'
}

# vbox_latest_available_package
# El paquete 'virtualbox-X.Y' más nuevo que ofrezca el repositorio ya
# agregado (requiere que 'apt-get update' ya haya corrido contra él).
vbox_latest_available_package() {
    apt-cache search '^virtualbox-[0-9]' 2>/dev/null | awk '{print $1}' | sort -V | tail -1
}

# Function to check status
check_status() {
    local pkg
    pkg="$(vbox_installed_package)"
    if [[ -z "${pkg}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ ! -e "${VIRTUALBOX_VBOXDRV_PATH}" ]]; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${pkg}/"; then
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
    if [[ "${current_status}" == "INSTALLED" || "${current_status}" == "OUTDATED" ]]; then
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install'." >&2
        return 1
    fi
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    apt_vendor_repo_ensure_gnupg
    apt_vendor_repo_fetch_key_dearmored "${VIRTUALBOX_KEY_URL}" "${VIRTUALBOX_KEYRING}"
    apt_vendor_repo_write_list "${VIRTUALBOX_REPO_LIST}" \
        "deb [arch=$(dpkg --print-architecture) signed-by=${VIRTUALBOX_KEYRING}] ${VIRTUALBOX_REPO_URL} $(. /etc/os-release && echo "${VERSION_CODENAME}") contrib"

    sudo apt-get update

    local package
    package="$(vbox_latest_available_package)"
    if [[ -z "${package}" ]]; then
        echo "No se encontró ningún paquete 'virtualbox-X.Y' disponible tras agregar el repositorio de Oracle; abortando." >&2
        return 1
    fi

    apt_install_packages "linux-headers-$(uname -r)" dkms "${package}"

    sudo groupadd vboxusers 2>/dev/null || true
    sudo usermod -aG vboxusers "$(id -un)"

    echo "${TOOL_NAME} instalado correctamente (paquete ${package}). Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto."
    if [[ ! -e "${VIRTUALBOX_VBOXDRV_PATH}" ]]; then
        echo "Advertencia: el módulo del kernel (vboxdrv) no parece haber cargado. Puede requerir reiniciar la máquina." >&2
    fi
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    local pkg
    pkg="$(vbox_installed_package)"
    if [[ -n "${pkg}" ]]; then
        apt_purge_packages "${pkg}"
    fi
    sudo rm -f "${VIRTUALBOX_REPO_LIST}" "${VIRTUALBOX_KEYRING}"

    # Match exacto de nombre de grupo, no una coincidencia de substring
    # (mismo criterio que install_docker.sh con el grupo 'docker').
    if groups | grep -qw vboxusers; then
        sudo gpasswd -d "$(id -un)" vboxusers
    fi

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    local pkg
    pkg="$(vbox_installed_package)"
    if [[ -z "${pkg}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'reinstall'." >&2
        return 1
    fi

    echo "Reinstalando ${TOOL_NAME}..."
    sudo apt-get install --reinstall -y "${pkg}"
    echo "${TOOL_NAME} reinstalado correctamente."
}

# Function to update (para el estado OUTDATED)
update_tool() {
    local pkg
    pkg="$(vbox_installed_package)"
    if [[ -z "${pkg}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    sudo apt-get update
    sudo apt-get install --only-upgrade -y "${pkg}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    local pkg
    pkg="$(vbox_installed_package)"
    if [[ -z "${pkg}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
    apt_install_packages "linux-headers-$(uname -r)" dkms
    sudo apt-get install --reinstall -y "${pkg}"
    sudo dkms autoinstall 2>/dev/null || true
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
