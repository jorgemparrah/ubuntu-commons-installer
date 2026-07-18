#!/bin/bash
# install_vscode.sh
#
# Repo APT oficial de Microsoft, con signed-by + keyring (nunca apt-key).
# Corregido en el Hito 9 con los mismos hallazgos reales encontrados al
# validar install_cursor.sh (mismo patrón gpg --dearmor) en CI, ver
# docs/UBUNTU_COMPATIBILITY.md:
#   1) gpg --dearmor requiere el paquete gnupg, no se puede asumir presente;
#   2) sin comprobar el resultado, un wget/gpg fallido deja un keyring
#      vacío en silencio (NO_PUBKEY recién en 'apt update');
#   3) 'dpkg -s'/'command -v' no distinguen el estado "config-files"
#      remanente que deja 'apt remove' (sin purgar) de instalado de verdad.

TOOL_NAME="Visual Studio Code"
VSCODE_KEYRING=/etc/apt/keyrings/packages.microsoft.gpg
VSCODE_REPO_LIST=/etc/apt/sources.list.d/vscode.list

# Function to check status
check_status() {
    if command -v code &> /dev/null || dpkg -l code 2>/dev/null | grep -q '^ii'; then
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

    # Configure debconf
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections

    # gpg --dearmor requiere el paquete gnupg; no se puede asumir presente.
    if ! command -v gpg &> /dev/null; then
        sudo apt update
        sudo apt install -y gnupg
    fi

    sudo mkdir -p "$(dirname "${VSCODE_KEYRING}")"

    # Descarga y convierte la clave GPG de Microsoft. Se verifica
    # explícitamente que el keyring no quede vacío (wget o gpg fallidos en
    # silencio dejarían un archivo vacío, y el error real -NO_PUBKEY- solo
    # aparecería más tarde, en 'apt update').
    local tmp_keyring
    tmp_keyring="$(mktemp)"
    if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "${tmp_keyring}"; then
        echo "No se pudo descargar/convertir la clave GPG de Microsoft" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi
    if [[ ! -s "${tmp_keyring}" ]]; then
        echo "El keyring de Microsoft quedó vacío tras la descarga; abortando" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi
    sudo install -D -o root -g root -m 644 "${tmp_keyring}" "${VSCODE_KEYRING}"
    rm -f "${tmp_keyring}"

    # Add VS Code repository
    echo "deb [arch=amd64,arm64,armhf signed-by=${VSCODE_KEYRING}] https://packages.microsoft.com/repos/code stable main" | sudo tee "${VSCODE_REPO_LIST}" > /dev/null

    # Install VS Code
    sudo apt update
    sudo apt install -y code

    echo "Visual Studio Code instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    # 'apt purge' (no solo 'remove') para que dpkg no deje el paquete en
    # estado "config-files" remanente, que 'dpkg -l | grep ii' interpreta
    # correctamente como no instalado pero 'dpkg -s' seguiría reportando
    # éxito (hallazgo real encontrado en install_cursor.sh).
    sudo apt purge -y code
    sudo apt autoremove -y

    sudo rm -f "${VSCODE_REPO_LIST}"
    sudo rm -f "${VSCODE_KEYRING}"

    echo "Visual Studio Code desinstalado correctamente."
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
