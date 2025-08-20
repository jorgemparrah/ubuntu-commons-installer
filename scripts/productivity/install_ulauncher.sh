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

installULauncher() {
    echo "Checking ULauncher installation status..."
    
    if check_package_installed "ulauncher"; then
        echo -e "${GREEN}✓${NC} ULauncher is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} ULauncher is not installed. Installing..."
    
    # Add repositories
    sudo add-apt-repository universe -y
    sudo add-apt-repository ppa:agornostal/ulauncher -y
    sudo apt update
    
    # Install ULauncher
    sudo apt install -y ulauncher
    
    echo -e "${GREEN}✓${NC} ULauncher installation complete."
}

installULauncher
