#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Insomnia is installed
check_insomnia_installed() {
    if snap list | grep -q "insomnia"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installInsomnia() {
    echo "Checking Insomnia installation status..."
    
    if check_insomnia_installed; then
        echo -e "${GREEN}✓${NC} Insomnia is already installed."
        echo "Insomnia version: $(snap list insomnia | grep insomnia | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Insomnia is not installed. Installing..."
    
    # Install Insomnia via snap
    echo "Installing Insomnia via snap..."
    sudo snap install insomnia --classic
    
    echo -e "${GREEN}✓${NC} Insomnia installation complete."
}

installInsomnia
