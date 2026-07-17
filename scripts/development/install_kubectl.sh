#!/bin/bash
# install_kubectl.sh
#
# kubectl se gestiona vía Mise, no vía Snap (ver
# docs/adr/0018-kubectl-via-mise.md). Usa scripts/lib/runtime.sh, el mismo
# mecanismo del Hito 8 (Gestor de runtimes) que ya gestiona Node y Python.

TOOL_NAME="kubectl"
UCI_KUBECTL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_KUBECTL_SCRIPT_DIR}/../lib/runtime.sh"

# Function to check status
check_status() {
    if runtime_mise_available "${HOME}" && "$(runtime_mise_bin "${HOME}")" which kubectl &> /dev/null; then
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

    if ! runtime_install "${HOME}" kubectl latest; then
        echo "No se pudo instalar kubectl vía Mise" >&2
        return 1
    fi

    if ! runtime_use_global "${HOME}" kubectl latest; then
        echo "No se pudo fijar kubectl como versión global de Mise" >&2
        return 1
    fi

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    if runtime_mise_available "${HOME}"; then
        runtime_cmd "${HOME}" uninstall kubectl@latest || true
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
