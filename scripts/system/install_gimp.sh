#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if GIMP is installed
check_gimp_installed() {
    if command -v gimp &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installGimp() {
    echo "Checking GIMP installation status..."
    
    if check_gimp_installed; then
        echo -e "${GREEN}✓${NC} GIMP is already installed."
        echo "GIMP version: $(gimp --version)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} GIMP is not installed. Installing..."
    
    # Update package list
    sudo apt update
    
    # Install GIMP via apt
    echo "Installing GIMP via apt..."
    sudo snap install gimp --classic
    
    echo -e "${GREEN}✓${NC} GIMP installation complete."
    echo "GIMP version: $(gimp --version)"
}

installGimp
