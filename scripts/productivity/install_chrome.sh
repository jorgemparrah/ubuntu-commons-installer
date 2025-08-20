#!/bin/bash
# install_chrome.sh

TOOL_NAME="Google Chrome"

# Function to check status
check_status() {
    if command -v google-chrome &> /dev/null || dpkg -l | grep -q "google-chrome-stable"; then
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
    
    # Download Chrome
    echo "Descargando Google Chrome..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    
    # Install Chrome
    echo "Instalando Google Chrome..."
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    
    # Clean up
    rm -f google-chrome-stable_current_amd64.deb
    
    echo "Google Chrome instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove Chrome
    sudo apt remove -y google-chrome-stable
    sudo apt autoremove -y
    
    echo "Google Chrome desinstalado correctamente."
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
