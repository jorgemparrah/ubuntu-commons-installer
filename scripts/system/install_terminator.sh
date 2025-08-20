#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Terminator is installed
check_terminator_installed() {
    if command -v terminator &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installTerminator() {
    echo "Checking Terminator installation status..."
    
    if check_terminator_installed; then
        echo -e "${GREEN}✓${NC} Terminator is already installed."
        echo "Terminator version: $(terminator --version)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Terminator is not installed. Installing..."
    
    # Update package list
    sudo apt update
    
    # Install Terminator via apt
    echo "Installing Terminator via apt..."
    sudo apt install -y terminator
    
    echo -e "${GREEN}✓${NC} Terminator installation complete."
    echo "Terminator version: $(terminator --version)"
}

installTerminator
