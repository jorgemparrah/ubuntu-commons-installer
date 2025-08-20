#!/bin/bash
# install_mongodb_compass.sh

TOOL_NAME="MongoDB Compass"

# Function to check status
check_status() {
    if command -v mongodb-compass &> /dev/null || dpkg -l | grep -q "mongodb-compass"; then
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
    
    # Download MongoDB Compass
    echo "Descargando MongoDB Compass..."
    wget https://downloads.mongodb.com/compass/mongodb-compass_1.46.8_amd64.deb
    
    # Install MongoDB Compass
    echo "Instalando MongoDB Compass..."
    sudo apt install -y ./mongodb-compass_1.46.8_amd64.deb
    
    # Clean up
    rm -f mongodb-compass_1.46.8_amd64.deb
    
    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove package
    sudo apt remove -y mongodb-compass
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
