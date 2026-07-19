#!/usr/bin/env bash
# install_yarn.sh
#
# Yarn se instala vía Mise, no vía apt (ver
# docs/adr/0017-mise-instala-yarn-pnpm-directo.md). El paquete `yarn` de
# los repositorios de Ubuntu es en realidad `cmdtest` (Debian), no el Yarn
# de JavaScript — un bug preexistente detectado en
# docs/UBUNTU_COMPATIBILITY.md, no específico de Ubuntu 26. Usa
# scripts/lib/runtime.sh (Hito 8), el mismo mecanismo que kubectl/Node/Python.

set -Eeuo pipefail
TOOL_NAME="Yarn"
UCI_YARN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_YARN_SCRIPT_DIR}/../lib/runtime.sh"

# Function to check status
check_status() {
    if runtime_mise_available "${HOME}" && "$(runtime_resolve_mise_bin "${HOME}")" which yarn &> /dev/null; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    echo "Instalando $TOOL_NAME..."

    if ! runtime_ensure_mise "${HOME}"; then
        echo "No se pudo instalar Mise" >&2
        return 1
    fi

    if ! runtime_install "${HOME}" yarn latest; then
        echo "No se pudo instalar Yarn vía Mise" >&2
        return 1
    fi

    if ! runtime_use_global "${HOME}" yarn latest; then
        echo "No se pudo fijar Yarn como versión global de Mise" >&2
        return 1
    fi

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    if runtime_mise_available "${HOME}"; then
        runtime_cmd "${HOME}" uninstall yarn@latest || true
    fi

    echo "$TOOL_NAME desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Main function
main() {
    case "${1:-}" in
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
