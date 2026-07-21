#!/usr/bin/env bash
# install_powerlevel10k.sh
#
# Instalador migrado en el Hito 11 (grupo git-clone) al contrato completo
# de 6 verbos (ver docs/ROADMAP.md y
# docs/adr/0029-contrato-completo-de-instalador-referencia.md). Usa el
# dispatcher compartido (scripts/lib/installer_cli.sh), los helpers APT
# (scripts/lib/apt.sh) y los helpers de clonado Git (scripts/lib/git_clone.sh,
# nuevos en esta migración, compartidos con install_oh_my_zsh.sh).
#
# Instala zsh y el tema Powerlevel10k, clonado directamente desde su repo
# oficial como tema custom de Oh My Zsh, sin correr ningún script remoto.
# No toca `.zshrc` ni `.p10k.zsh`: si `/home` se reutiliza, la
# personalización existente (ver
# docs/adr/0021-reutilizar-personalizacion-shell-en-home.md) no se
# sobreescribe — solo se clona el tema si todavía no es un repositorio Git
# válido.
#
# Semántica de los 6 verbos: idéntica a install_oh_my_zsh.sh, ver los
# comentarios de ese archivo.
#
# Depende de Oh My Zsh (Hito 17, ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md,
# campo depends_on=oh_my_zsh en tools_catalog.sh): install_tool rechaza
# explícitamente si Oh My Zsh no está instalado, en vez de instalarlo por
# su cuenta.

set -Eeuo pipefail

UCI_POWERLEVEL10K_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UCI_POWERLEVEL10K_REPO_ROOT="$(cd "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/git_clone.sh
source "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../lib/git_clone.sh"
# shellcheck source=../lib/dependencies.sh
source "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../lib/dependencies.sh"
# shellcheck source=../lib/tools_catalog.sh
source "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../lib/tools_catalog.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_POWERLEVEL10K_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="Powerlevel10k"
P10K_DIR="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
P10K_REPO="https://github.com/romkatv/powerlevel10k.git"
UCI_POWERLEVEL10K_DEPENDS_ON="oh_my_zsh"

# Function to check status
check_status() {
    if ! command -v zsh &> /dev/null || [[ ! -d "${P10K_DIR}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! git_clone_present "${P10K_DIR}"; then
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

    local dep_script
    dep_script="${UCI_POWERLEVEL10K_REPO_ROOT}/$(tools_registry_field "${UCI_POWERLEVEL10K_DEPENDS_ON}" "script")"
    if ! dependency_require_installed "${dep_script}" "Oh My Zsh"; then
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    apt_install_packages zsh git
    git_clone_ensure "${P10K_REPO}" "${P10K_DIR}"

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    rm -rf "${P10K_DIR}"
    apt_purge_packages zsh

    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    if ! git_clone_present "${P10K_DIR}"; then
        echo "${TOOL_NAME} no está instalado o está en estado BROKEN; usa 'install'/'repair' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    git_clone_update "${P10K_DIR}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    if [[ ! -d "${P10K_DIR}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    rm -rf "${P10K_DIR}"
    git_clone_ensure "${P10K_REPO}" "${P10K_DIR}"
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
