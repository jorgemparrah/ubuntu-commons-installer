#!/bin/bash
# install_oh_my_zsh.sh
#
# Instala zsh y el framework Oh My Zsh (clonado directamente desde su repo
# oficial, sin correr su script remoto de instalación) — antes este script
# solo instalaba el paquete `zsh` y nunca el framework, pese a su nombre
# (hallazgo de docs/UBUNTU_COMPATIBILITY.md). No toca `.zshrc` ni cambia
# el shell por defecto: si `/home` se reutiliza, la personalización
# existente (ver docs/adr/0021-reutilizar-personalizacion-shell-en-home.md)
# no se sobreescribe — solo se clona el framework si `~/.oh-my-zsh` todavía
# no existe.

TOOL_NAME="Oh My Zsh"
OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
OH_MY_ZSH_REPO="https://github.com/ohmyzsh/ohmyzsh.git"

# Function to check status
check_status() {
    if command -v zsh &> /dev/null && [[ -d "${OH_MY_ZSH_DIR}" ]]; then
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

    sudo apt update
    sudo apt install -y zsh git

    if [[ -d "${OH_MY_ZSH_DIR}" ]]; then
        echo "Oh My Zsh ya está presente en ${OH_MY_ZSH_DIR}, no se reinstala."
    else
        git clone --depth=1 "${OH_MY_ZSH_REPO}" "${OH_MY_ZSH_DIR}"
    fi

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    rm -rf "${OH_MY_ZSH_DIR}"
    sudo apt remove -y zsh
    sudo apt autoremove -y

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
