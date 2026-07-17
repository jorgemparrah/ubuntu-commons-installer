#!/bin/bash
# install_nodejs.sh
#
# ⚠️  LEGADO / DEPRECADO — NO USAR EN FLUJOS NUEVOS ⚠️
#
# Este script instalaba Node.js vía NVM. El proyecto migró a Mise como
# único gestor de runtimes (ver docs/adr/0002-mise-como-unico-gestor-runtime.md).
# El bootstrap interactivo (setup.sh) ya NO lo invoca: usa Mise
# directamente (ver ensure_node_via_mise() en setup.sh). Tampoco aparece en
# el menú de setup.js.
#
# `install`, `uninstall` y `reinstall` se niegan a operar SIEMPRE, sin
# excepción: no existe ninguna variable de entorno que los reactive. Las
# operaciones destructivas que tenían (`rm -rf ~/.nvm`, `sed -i` de patrón
# amplio sobre .bashrc/.zshrc/.profile) ya no existen en este archivo, no
# solo están deshabilitadas (ver docs/adr/0003-migracion-nvm-sin-borrado-directo.md).
#
# Si ya tienes NVM instalado, la forma segura de migrar es
# `./setup.sh migrate` (ver scripts/migrations/001_nvm_to_mise.sh), que
# respalda todo y mueve ~/.nvm en vez de borrarlo. Para instalar Node.js en
# una workstation nueva, usa el flujo interactivo (`./setup.sh`), que
# instala Node vía Mise.
#
# `status` se mantiene: sigue siendo de solo lectura, útil para detectar
# estado histórico (Node/npm ya presentes en PATH, sin importar su origen).

refuse_legacy_action() {
    local action="$1"
    echo "install_nodejs.sh: la acción '${action}' está deshabilitada permanentemente." >&2
    echo "Este script instalaba Node.js vía NVM; el proyecto usa Mise como único" >&2
    echo "gestor de runtimes (ver docs/adr/0002-mise-como-unico-gestor-runtime.md)." >&2
    echo "" >&2
    echo "Si ya tienes NVM instalado, usa './setup.sh migrate' para migrar de forma" >&2
    echo "segura (respalda todo, mueve ~/.nvm en vez de borrarlo)." >&2
    echo "" >&2
    echo "Si necesitas instalar Node.js en una workstation nueva, usa el flujo" >&2
    echo "interactivo ('./setup.sh'), que instala Node vía Mise." >&2
    exit 1
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
    refuse_legacy_action "install"
}

# Function to uninstall
uninstall_tool() {
    refuse_legacy_action "uninstall"
}

# Function to reinstall
reinstall_tool() {
    refuse_legacy_action "reinstall"
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
