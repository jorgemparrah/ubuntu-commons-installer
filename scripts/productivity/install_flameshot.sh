#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a package is installed
check_package_installed() {
    local package="$1"
    if dpkg -l | grep -q "^ii.*$package"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installFlameshot() {
    echo "Checking Flameshot installation status..."
    
    if check_package_installed "flameshot"; then
        echo -e "${GREEN}✓${NC} Flameshot is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Flameshot is not installed. Installing..."
    
    # Install Flameshot
    sudo apt install -y flameshot
    
    # Configure keyboard shortcut for Print key
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/']"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/name "'Flameshot'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/command "'flameshot gui'"
    dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/binding "'Print'"
    
    echo -e "${GREEN}✓${NC} Flameshot installation complete. Print key is now configured for screenshot."
}

installFlameshot
