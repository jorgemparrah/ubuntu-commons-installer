#!/usr/bin/env bash
# install_pipes_sh.sh
#
# Instalador nuevo (Hito 47, ver docs/ROADMAP.md): agrega pipes.sh
# (salvapantallas de terminal de tuberías animadas) al catálogo
# (category=system, subcategory=extras, mismo grupo que cmatrix). Usa el
# dispatcher compartido, los helpers APT (scripts/lib/apt.sh) y los
# helpers de clonado Git (scripts/lib/git_clone.sh, mismo mecanismo que
# Oh My Zsh/Powerlevel10k).
#
# pipes.sh no tiene paquete propio en Ubuntu. El repo oficial
# (github.com/pipeseroni/pipes.sh) publica un `Makefile` con target
# `install`/`uninstall` (confirmado leyendo el Makefile real, solo
# lectura, nunca ejecutado a ciegas): `make PREFIX=<prefijo> install`
# copia el script a `<prefijo>/bin/pipes.sh` — se usa
# `PREFIX="${HOME}/.local"` para instalar a nivel de usuario, sin sudo,
# consistente con el resto de las herramientas de este catálogo que
# dejan binarios en `~/.local/bin`.

set -Eeuo pipefail

UCI_PIPES_SH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_PIPES_SH_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/git_clone.sh
source "${UCI_PIPES_SH_SCRIPT_DIR}/../lib/git_clone.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_PIPES_SH_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="pipes.sh"
UCI_PIPES_SH_DIR="${HOME}/.local/share/pipes.sh"
UCI_PIPES_SH_REPO="https://github.com/pipeseroni/pipes.sh.git"
UCI_PIPES_SH_PREFIX="${HOME}/.local"

# Function to check status
check_status() {
    if ! command -v pipes.sh &> /dev/null; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ ! -d "${UCI_PIPES_SH_DIR}" ]] || ! git_clone_present "${UCI_PIPES_SH_DIR}"; then
        echo "BROKEN"
        return 1
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "INSTALLED" ]]; then
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install'." >&2
        return 1
    fi
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    apt_install_packages make git
    git_clone_ensure "${UCI_PIPES_SH_REPO}" "${UCI_PIPES_SH_DIR}"
    make -C "${UCI_PIPES_SH_DIR}" "PREFIX=${UCI_PIPES_SH_PREFIX}" install

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if [[ -d "${UCI_PIPES_SH_DIR}" ]]; then
        make -C "${UCI_PIPES_SH_DIR}" "PREFIX=${UCI_PIPES_SH_PREFIX}" uninstall || true
    fi
    rm -rf "${UCI_PIPES_SH_DIR}"

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    if ! git_clone_present "${UCI_PIPES_SH_DIR}"; then
        echo "${TOOL_NAME} no está instalado o está en estado BROKEN; usa 'install'/'repair' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    git_clone_update "${UCI_PIPES_SH_DIR}"
    make -C "${UCI_PIPES_SH_DIR}" "PREFIX=${UCI_PIPES_SH_PREFIX}" install
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if [[ ! -d "${UCI_PIPES_SH_DIR}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    rm -rf "${UCI_PIPES_SH_DIR}"
    git_clone_ensure "${UCI_PIPES_SH_REPO}" "${UCI_PIPES_SH_DIR}"
    make -C "${UCI_PIPES_SH_DIR}" "PREFIX=${UCI_PIPES_SH_PREFIX}" install
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
