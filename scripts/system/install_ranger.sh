#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Ranger is installed
check_ranger_installed() {
    if command -v ranger &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installRanger() {
    echo "Checking Ranger installation status..."
    
    if check_ranger_installed; then
        echo -e "${GREEN}✓${NC} Ranger is already installed."
        echo "Ranger version: $(ranger --version | head -n 1)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Ranger is not installed. Installing..."
    
    # Update package list
    sudo apt update
    
    # Install Ranger via apt
    echo "Installing Ranger via apt..."
    sudo apt install -y ranger
    
    echo -e "${GREEN}✓${NC} Ranger installation complete."
    echo "Ranger version: $(ranger --version | head -n 1)"
}

installRanger
