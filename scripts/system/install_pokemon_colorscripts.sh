#!/usr/bin/env bash
# install_pokemon_colorscripts.sh
#
# Instalador nuevo (Hito 47, ver docs/ROADMAP.md): agrega
# pokemon-colorscripts (arte ASCII de Pokémon coloreado en terminal) al
# catálogo (category=system, subcategory=extras, mismo grupo que
# cmatrix). Usa el dispatcher compartido, los helpers APT
# (scripts/lib/apt.sh) y los helpers de clonado Git
# (scripts/lib/git_clone.sh), mismo mecanismo que Oh My Zsh/pipes.sh.
#
# Sin paquete oficial de Ubuntu. El repositorio original
# (gitlab.com/phoneybadger/pokemon-colorscripts) publica un `install.sh`
# que se leyó (solo lectura, nunca ejecutado a ciegas) para entender
# exactamente qué hace: copia `colorscripts/`, `pokemon-colorscripts.py`
# y `pokemon.json` a un directorio de instalación, y crea un symlink al
# `.py` en un directorio del PATH. Este instalador replica esa misma
# lógica directamente (sin descargar ni ejecutar el `install.sh` remoto),
# a nivel de usuario en vez de `/usr/local` (sin sudo): clona el repo en
# `~/.local/share/pokemon-colorscripts` y crea el symlink en
# `~/.local/bin/pokemon-colorscripts`, mismo criterio que el resto de las
# herramientas de este catálogo que usan esa convención (grupo
# curl-script).

set -Eeuo pipefail

UCI_POKEMON_CS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_POKEMON_CS_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/git_clone.sh
source "${UCI_POKEMON_CS_SCRIPT_DIR}/../lib/git_clone.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_POKEMON_CS_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="pokemon-colorscripts"
UCI_POKEMON_CS_DIR="${HOME}/.local/share/pokemon-colorscripts"
UCI_POKEMON_CS_REPO="https://gitlab.com/phoneybadger/pokemon-colorscripts.git"
UCI_POKEMON_CS_BIN_DIR="${HOME}/.local/bin"
UCI_POKEMON_CS_LINK="${UCI_POKEMON_CS_BIN_DIR}/pokemon-colorscripts"

# Function to check status
check_status() {
    if [[ ! -e "${UCI_POKEMON_CS_LINK}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! git_clone_present "${UCI_POKEMON_CS_DIR}" || [[ ! -x "${UCI_POKEMON_CS_LINK}" ]]; then
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

    apt_install_packages python3 git
    git_clone_ensure "${UCI_POKEMON_CS_REPO}" "${UCI_POKEMON_CS_DIR}"
    chmod +x "${UCI_POKEMON_CS_DIR}/pokemon-colorscripts.py"
    mkdir -p "${UCI_POKEMON_CS_BIN_DIR}"
    ln -sf "${UCI_POKEMON_CS_DIR}/pokemon-colorscripts.py" "${UCI_POKEMON_CS_LINK}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    rm -f "${UCI_POKEMON_CS_LINK}"
    rm -rf "${UCI_POKEMON_CS_DIR}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    if ! git_clone_present "${UCI_POKEMON_CS_DIR}"; then
        echo "${TOOL_NAME} no está instalado o está en estado BROKEN; usa 'install'/'repair' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    git_clone_update "${UCI_POKEMON_CS_DIR}"
    chmod +x "${UCI_POKEMON_CS_DIR}/pokemon-colorscripts.py"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if [[ ! -e "${UCI_POKEMON_CS_LINK}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    rm -rf "${UCI_POKEMON_CS_DIR}"
    git_clone_ensure "${UCI_POKEMON_CS_REPO}" "${UCI_POKEMON_CS_DIR}"
    chmod +x "${UCI_POKEMON_CS_DIR}/pokemon-colorscripts.py"
    mkdir -p "${UCI_POKEMON_CS_BIN_DIR}"
    ln -sf "${UCI_POKEMON_CS_DIR}/pokemon-colorscripts.py" "${UCI_POKEMON_CS_LINK}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
