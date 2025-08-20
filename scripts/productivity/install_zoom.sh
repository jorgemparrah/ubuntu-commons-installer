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

installZoom() {
    echo "Checking Zoom installation status..."
    
    if check_package_installed "zoom-client"; then
        echo -e "${GREEN}✓${NC} Zoom is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Zoom is not installed. Installing..."
    
    # Install Zoom
    sudo snap install zoom-client
    
    echo -e "${GREEN}✓${NC} Zoom installation complete."
}

installZoom
