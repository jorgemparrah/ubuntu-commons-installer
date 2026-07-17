#!/bin/bash
# install_powerlevel10k.sh
#
# Instala zsh y el tema Powerlevel10k (clonado directamente desde su repo
# oficial, sin correr ningún script remoto) como tema custom de Oh My Zsh
# — antes este script solo instalaba el paquete `zsh` y nunca el tema,
# pese a su nombre (hallazgo de docs/UBUNTU_COMPATIBILITY.md). No toca
# `.zshrc` ni `.p10k.zsh`: si `/home` se reutiliza, la personalización
# existente (ver docs/adr/0021-reutilizar-personalizacion-shell-en-home.md)
# no se sobreescribe — solo se clona el tema si todavía no existe.

TOOL_NAME="Powerlevel10k"
P10K_DIR="${HOME}/.oh-my-zsh/custom/themes/powerlevel10k"
P10K_REPO="https://github.com/romkatv/powerlevel10k.git"

# Function to check status
check_status() {
    if command -v zsh &> /dev/null && [[ -d "${P10K_DIR}" ]]; then
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

    if [[ -d "${P10K_DIR}" ]]; then
        echo "Powerlevel10k ya está presente en ${P10K_DIR}, no se reinstala."
    else
        mkdir -p "$(dirname "${P10K_DIR}")"
        git clone --depth=1 "${P10K_REPO}" "${P10K_DIR}"
    fi

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    rm -rf "${P10K_DIR}"
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
