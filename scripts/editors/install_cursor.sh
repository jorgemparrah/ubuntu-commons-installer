#!/bin/bash
# install_cursor.sh

VERSION_CURSOR=1.4.5
CURSOR_PATH=/opt/cursor
APPIMAGE_PATH="$CURSOR_PATH/Cursor-$VERSION_CURSOR.AppImage"
TOOL_NAME="Cursor AI IDE"

# Function to check status
check_status() {
    if [ -f "$APPIMAGE_PATH" ] || [ -f "$HOME/.local/share/applications/cursor.desktop" ] || [ -f "/usr/share/applications/cursor.desktop" ]; then
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
    
    if [ -f "$APPIMAGE_PATH" ]; then
        echo "Cursor AI IDE ya está instalado."
        return 0
    fi

    # Prepare path
    echo "Instalando dependencias..."
    sudo add-apt-repository universe -y
    sudo apt install -y libfuse2t64 wget

    # Prepare path
    echo "Preparando rutas..."
    sudo mkdir -p $CURSOR_PATH

    # Download icon
    ICON_NAME=cursor.png
    ICON_PATH=$CURSOR_PATH/$ICON_NAME
    ICON_URL="https://raw.githubusercontent.com/rahuljangirwork/copmany-logos/refs/heads/main/$ICON_NAME"
    echo "Descargando icono..."
    sudo wget $ICON_URL
    sudo mv $ICON_NAME $ICON_PATH

    # Download installer
    INSTALLER_NAME=Cursor-$VERSION_CURSOR-x86_64.AppImage
    INSTALLER_URL="https://downloads.cursor.com/production/af58d92614edb1f72bdd756615d131bf8dfa5299/linux/x64/$INSTALLER_NAME"
    echo "Descargando instalador..."
    sudo wget $INSTALLER_URL
    sudo mv $INSTALLER_NAME $APPIMAGE_PATH
    sudo chmod +x $APPIMAGE_PATH

    # Create a .desktop entry for Cursor
    DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"
    echo "Creando entrada .desktop para Cursor..."
    sudo bash -c "cat > $DESKTOP_ENTRY_PATH" <<EOL
[Desktop Entry]
Name=Cursor AI IDE
Exec=$APPIMAGE_PATH --no-sandbox
Icon=$ICON_PATH
Type=Application
Categories=Development;
EOL

    # Create binary link
    BINARY_LINK_PATH="/usr/local/bin/cursor"
    echo "Creando comando 'cursor'..."
    sudo bash -c "cat > $BINARY_LINK_PATH" <<EOL
#!/usr/bin/env bash
exec $APPIMAGE_PATH --no-sandbox "\$@"
EOL
    sudo chmod +x $BINARY_LINK_PATH

    echo "Cursor AI IDE instalado correctamente. Puedes encontrarlo en el menú de aplicaciones."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove AppImage
    if [ -f "$APPIMAGE_PATH" ]; then
        sudo rm -f "$APPIMAGE_PATH"
    fi
    
    # Remove icon
    if [ -f "$CURSOR_PATH/cursor.png" ]; then
        sudo rm -f "$CURSOR_PATH/cursor.png"
    fi
    
    # Remove desktop entry
    if [ -f "/usr/share/applications/cursor.desktop" ]; then
        sudo rm -f "/usr/share/applications/cursor.desktop"
    fi
    
    # Remove binary link
    if [ -f "/usr/local/bin/cursor" ]; then
        sudo rm -f "/usr/local/bin/cursor"
    fi
    
    # Remove directory if empty
    if [ -d "$CURSOR_PATH" ] && [ -z "$(ls -A $CURSOR_PATH)" ]; then
        sudo rmdir "$CURSOR_PATH"
    fi
    
    echo "Cursor AI IDE desinstalado correctamente."
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
