#!/bin/bash
# install_cursor.sh
#
# Cursor tiene un repositorio APT oficial (downloads.cursor.com/aptrepo),
# con el mecanismo moderno de clave GPG (signed-by + keyring en
# /etc/apt/keyrings, nunca apt-key) y soporte para amd64 y arm64. Antes
# este script descargaba un AppImage fijado a x86_64 sin checksum
# (hallazgo de docs/UBUNTU_COMPATIBILITY.md); el repo oficial resuelve
# ambos problemas de una vez (arquitectura declarada explícitamente,
# clave y paquete verificados por apt) — ver ADR 0027 (categoría
# "servicio/software técnico con repositorio propio -> APT oficial del
# fabricante").

TOOL_NAME="Cursor AI IDE"
CURSOR_KEYRING=/etc/apt/keyrings/cursor.gpg
CURSOR_REPO_LIST=/etc/apt/sources.list.d/cursor.list

# Function to check status
check_status() {
    if command -v cursor &> /dev/null || dpkg -s cursor &> /dev/null; then
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

    # gpg --dearmor requiere el paquete gnupg; no se puede asumir presente
    # (encontrado al validar en CI: sin gnupg, el pipe no falla de forma
    # visible y deja un keyring vacío en silencio, causando un error de
    # firma NO_PUBKEY recién al hacer 'apt update' — ver docs/UBUNTU_COMPATIBILITY.md).
    if ! command -v gpg &> /dev/null; then
        sudo apt update
        sudo apt install -y gnupg
    fi

    sudo mkdir -p "$(dirname "${CURSOR_KEYRING}")"

    # Añade la clave GPG de Cursor
    curl -fsSL https://downloads.cursor.com/keys/anysphere.asc | gpg --dearmor | sudo tee "${CURSOR_KEYRING}" > /dev/null

    # Añade el repositorio de Cursor
    echo "deb [arch=amd64,arm64 signed-by=${CURSOR_KEYRING}] https://downloads.cursor.com/aptrepo stable main" | sudo tee "${CURSOR_REPO_LIST}" > /dev/null

    # Actualiza e instala
    sudo apt update
    sudo apt install -y cursor

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    sudo apt remove -y cursor
    sudo apt autoremove -y
    sudo rm -f "${CURSOR_REPO_LIST}"
    sudo rm -f "${CURSOR_KEYRING}"

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
