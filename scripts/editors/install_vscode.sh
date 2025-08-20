#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a package is installed
check_package_installed() {
    if command -v code &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installVSCode() {
    echo "Checking Visual Studio Code installation status..."
    
    if check_vim_installed; then
        echo -e "${GREEN}✓${NC} Visual Studio Code is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Visual Studio Code is not installed. Installing..."
    
    # Configure debconf
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
    
    # Download and install Microsoft GPG key
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    
    # Add VS Code repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    
    # Clean up GPG file
    rm -f packages.microsoft.gpg
    
    # Install VS Code
    sudo apt update
    sudo apt install -y code
    
    echo -e "${GREEN}✓${NC} Visual Studio Code installation complete."
}

installVSCode
