#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if cmatrix is installed
check_cmatrix_installed() {
    if command -v cmatrix &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installCmatrix() {
    echo "Checking cmatrix installation status..."
    
    if check_cmatrix_installed; then
        echo -e "${GREEN}✓${NC} cmatrix is already installed."
        echo "cmatrix version: $(cmatrix -V 2>/dev/null || echo 'Version info not available')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} cmatrix is not installed. Installing..."
    
    # Update package list
    sudo apt update
    
    # Install cmatrix via apt
    echo "Installing cmatrix via apt..."
    sudo apt install -y cmatrix
    
    echo -e "${GREEN}✓${NC} cmatrix installation complete."
    echo "cmatrix version: $(cmatrix -V 2>/dev/null || echo 'Version info not available')"
}

installCmatrix
