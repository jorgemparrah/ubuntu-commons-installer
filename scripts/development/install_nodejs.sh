#!/bin/bash
# install_nodejs.sh

TOOL_NAME="Node.js"

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
