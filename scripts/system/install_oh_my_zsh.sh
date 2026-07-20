#!/usr/bin/env bash
# install_oh_my_zsh.sh
#
# Instalador migrado en el Hito 11 (grupo git-clone) al contrato completo
# de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de clonado Git (scripts/lib/git_clone.sh,
# nuevos en esta migración).
#
# Instala zsh y el framework Oh My Zsh, clonado directamente desde su repo
# oficial, sin correr su script remoto de instalación (`curl | sh` no se
# usa nunca aquí, ver scripts/lib/git_clone.sh). No toca `.zshrc` ni
# cambia el shell por defecto: si `/home` se reutiliza, la personalización
# existente (ver docs/adr/0021-reutilizar-personalizacion-shell-en-home.md)
# no se sobreescribe — solo se clona el framework si `~/.oh-my-zsh` todavía
# no es un repositorio Git válido.
#
# Semántica de los 6 verbos:
#   status    — NOT_INSTALLED si falta el paquete `zsh` o el directorio
#               del framework; BROKEN si el directorio existe pero no es
#               un repositorio Git válido (clon interrumpido a mitad de
#               camino). No distingue OUTDATED: eso requeriría un 'git
#               fetch' contra la red en cada 'status', violando que debe
#               ser liviano — limitación honesta, no una detección
#               inventada.
#   install   — instala `zsh`/`git` vía apt y clona el framework si falta.
#               Rechaza sobre BROKEN.
#   uninstall — elimina el directorio del framework y purga `zsh` (antes
#               de esta migración usaba `apt remove`, no `purge` — se
#               alinea con el resto de los instaladores del proyecto).
#   reinstall — sin función propia: usa el fallback mecánico del
#               dispatcher (uninstall_tool + install_tool), igual que
#               antes de esta migración.
#   update    — `git pull --ff-only` sobre el framework ya clonado.
#   repair    — sobre BROKEN, elimina el directorio corrupto y lo vuelve a
#               clonar. Rechaza sobre NOT_INSTALLED.

set -Eeuo pipefail

UCI_OH_MY_ZSH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_OH_MY_ZSH_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/git_clone.sh
source "${UCI_OH_MY_ZSH_SCRIPT_DIR}/../lib/git_clone.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OH_MY_ZSH_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Oh My Zsh"
OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
OH_MY_ZSH_REPO="https://github.com/ohmyzsh/ohmyzsh.git"

# Function to check status
check_status() {
    if ! command -v zsh &> /dev/null || [[ ! -d "${OH_MY_ZSH_DIR}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! git_clone_present "${OH_MY_ZSH_DIR}"; then
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
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    apt_install_packages zsh git
    git_clone_ensure "${OH_MY_ZSH_REPO}" "${OH_MY_ZSH_DIR}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    rm -rf "${OH_MY_ZSH_DIR}"
    apt_purge_packages zsh

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    if ! git_clone_present "${OH_MY_ZSH_DIR}"; then
        echo "${TOOL_NAME} no está instalado o está en estado BROKEN; usa 'install'/'repair' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    git_clone_update "${OH_MY_ZSH_DIR}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if [[ ! -d "${OH_MY_ZSH_DIR}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    rm -rf "${OH_MY_ZSH_DIR}"
    git_clone_ensure "${OH_MY_ZSH_REPO}" "${OH_MY_ZSH_DIR}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
