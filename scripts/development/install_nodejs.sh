#!/bin/bash
# install_nodejs.sh
#
# ⚠️  LEGADO / DEPRECADO — NO USAR EN FLUJOS NUEVOS ⚠️
#
# Este script instala Node.js vía NVM. El proyecto migró a Mise como único
# gestor de runtimes (ver docs/adr/0002-mise-como-unico-gestor-runtime.md).
# El bootstrap interactivo (setup.sh) ya NO lo invoca: usa Mise
# directamente (ver ensure_node_via_mise() en setup.sh). Tampoco aparece en
# el menú de setup.js.
#
# Además, su `uninstall` es destructivo de la forma que HI-04/ADR 0007
# describen como insegura (borra con `sed` cualquier línea que contenga
# "nvm" en los archivos de shell, en vez de tocar solo bloques gestionados
# exactos). Si ya tienes NVM instalado, la forma segura de migrar es
# `./setup.sh migrate` (ver scripts/migrations/001_nvm_to_mise.sh), que
# respalda todo y mueve ~/.nvm en vez de borrarlo.
#
# Las acciones que modifican el sistema (install/uninstall/reinstall)
# requieren UCI_ALLOW_LEGACY_NVM=1 explícito para no invocarse por
# accidente. `status` sigue funcionando sin esa variable (es de solo
# lectura).

TOOL_NAME="Node.js"

require_legacy_confirmation() {
    if [[ "${UCI_ALLOW_LEGACY_NVM:-0}" != "1" ]]; then
        echo "Este script (install_nodejs.sh) está deprecado: instala Node.js vía NVM," >&2
        echo "y el proyecto ahora usa Mise (ver docs/adr/0002-mise-como-unico-gestor-runtime.md)." >&2
        echo "" >&2
        echo "Si ya tienes NVM instalado, usa './setup.sh migrate' para migrar de forma" >&2
        echo "segura (respalda todo, mueve ~/.nvm en vez de borrarlo)." >&2
        echo "" >&2
        echo "Si de verdad necesitas ejecutar esta acción legada a propósito, volvé a" >&2
        echo "correr el comando con UCI_ALLOW_LEGACY_NVM=1." >&2
        exit 1
    fi
}

# Function to check status
check_status() {
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    require_legacy_confirmation

    echo "Instalando $TOOL_NAME..."

    # Install NVM
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

    # Load NVM in current session
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install Node.js LTS
    nvm install --lts
    nvm use --lts

    # Verify installation
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        echo "Node.js instalado correctamente."
        echo "Node version: $(node --version)"
        echo "NPM version: $(npm --version)"
        echo "Por favor, reinicia tu terminal o ejecuta: source ~/.bashrc"
    else
        echo "Error: Node.js no se instaló correctamente."
        return 1
    fi
}

# Function to uninstall
uninstall_tool() {
    require_legacy_confirmation

    echo "Desinstalando $TOOL_NAME..."

    # Remove NVM directory
    if [[ -d "$HOME/.nvm" ]]; then
        rm -rf "$HOME/.nvm"
    fi

    # Remove NVM from shell configuration files
    for file in ~/.bashrc ~/.zshrc ~/.profile; do
        if [[ -f "$file" ]]; then
            sed -i '/NVM_DIR/d' "$file"
            sed -i '/nvm/d' "$file"
        fi
    done

    echo "Node.js desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    require_legacy_confirmation
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Main function
main() {
    case "$1" in
        "status")
            check_status
            ;;
        "install")
            install_tool
            ;;
        "uninstall")
            uninstall_tool
            ;;
        "reinstall")
            reinstall_tool
            ;;
        *)
            echo "Uso: $0 {status|install|uninstall|reinstall}"
            exit 1
            ;;
    esac
}

main "$@"
