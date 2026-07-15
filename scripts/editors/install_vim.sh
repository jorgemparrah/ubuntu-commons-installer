#!/usr/bin/env bash
# install_vim.sh
#
# Instalador de referencia para el contrato de estado enriquecido del Hito 3
# (ver docs/adr/0012-modelo-de-estado-enriquecido.md y docs/ROADMAP.md).
# `status` puede devolver: INSTALLED | NOT_INSTALLED | OUTDATED | BROKEN | UNSUPPORTED
set -Eeuo pipefail

TOOL_NAME="Vim"
PACKAGE_NAME="vim"

# Function to check status
check_status() {
    if ! command -v apt-get &> /dev/null && ! command -v apt &> /dev/null; then
        echo "UNSUPPORTED"
        return 1
    fi

    local dpkg_status
    dpkg_status="$(dpkg-query -W -f='${Status}' "${PACKAGE_NAME}" 2>/dev/null || true)"

    if [[ -z "${dpkg_status}" ]]; then
        if command -v vim &> /dev/null; then
            # vim existe pero no está registrado vía dpkg (por ejemplo, snap o
            # binario instalado manualmente): se reporta instalado, sin más
            # detalle de versión/actualización desde este instalador.
            echo "INSTALLED"
            return 0
        fi
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ "${dpkg_status}" != "install ok installed" ]]; then
        echo "BROKEN"
        return 1
    fi

    if ! command -v vim &> /dev/null; then
        echo "BROKEN"
        return 1
    fi

    if apt list --upgradable 2>/dev/null | grep -q "^${PACKAGE_NAME}/"; then
        echo "OUTDATED"
        return 0
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    sudo apt update
    sudo apt install -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    sudo apt remove -y "${PACKAGE_NAME}"
    sudo apt autoremove -y
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando ${TOOL_NAME}..."
    uninstall_tool
    install_tool
}

# Function to update (para el estado OUTDATED)
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo apt update
    sudo apt install --only-upgrade -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN)
repair_tool() {
    echo "Reparando ${TOOL_NAME}..."
    sudo dpkg --configure -a
    sudo apt install -f -y
    sudo apt install --reinstall -y "${PACKAGE_NAME}"
    echo "${TOOL_NAME} reparado."
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
        "update")
            update_tool
            ;;
        "repair")
            repair_tool
            ;;
        *)
            echo "Uso: $0 {status|install|uninstall|reinstall|update|repair}"
            exit 1
            ;;
    esac
}

main "$@"
