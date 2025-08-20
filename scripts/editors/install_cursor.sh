#!/bin/bash

VERSION_CURSOR=1.4.5
CURSOR_PATH=/opt/cursor
APPIMAGE_PATH="$CURSOR_PATH/Cursor-$VERSION_CURSOR.AppImage"

installCursor() {
    if ! [ -f $APPIMAGE_PATH ]
    then
        echo "Installing Cursor AI IDE..."

        # Prepare path
        echo "Installing dependencies..."
        sudo add-apt-repository universe -y
        sudo apt install -y libfuse2t64 wget

        # Prepare path
        echo "Preparing paths..."
        sudo mkdir -p $CURSOR_PATH

        # Download icon
        ICON_NAME=cursor.png
        ICON_PATH=$CURSOR_PATH/$ICON_NAME
        ICON_URL="https://raw.githubusercontent.com/rahuljangirwork/copmany-logos/refs/heads/main/$ICON_NAME"
        echo "Downloading icon..."
        sudo wget $ICON_URL
        sudo mv $ICON_NAME $ICON_PATH

        # Download installer
        INSTALLER_NAME=Cursor-$VERSION_CURSOR-x86_64.AppImage
        INSTALLER_URL="https://downloads.cursor.com/production/af58d92614edb1f72bdd756615d131bf8dfa5299/linux/x64/$INSTALLER_NAME"
        echo "Downloading installer..."
        sudo wget $INSTALLER_URL
        sudo mv $INSTALLER_NAME $APPIMAGE_PATH
        sudo chmod +x $APPIMAGE_PATH

        # Create a .desktop entry for Cursor
        DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"
        echo "Creating .desktop entry for Cursor..."
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
        echo "Creating 'cursor' command..."
        sudo bash -c "cat > $BINARY_LINK_PATH" <<EOL
#!/usr/bin/env bash
exec $APPIMAGE_PATH --no-sandbox "$@"
EOL

        echo "Cursor AI IDE installation complete. You can find it in your application menu."
    else
        echo "Cursor AI IDE is already installed."
    fi
}

installCursor
