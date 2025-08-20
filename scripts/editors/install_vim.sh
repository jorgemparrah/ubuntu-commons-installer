#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Vim is installed
check_vim_installed() {
    if command -v vim &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installVim() {
    echo "Checking Vim installation status..."
    
    if check_vim_installed; then
        echo -e "${GREEN}✓${NC} Vim is already installed."
        echo "Vim version: $(vim --version | head -n 1)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Vim is not installed. Installing..."
    
    # Update package list
    sudo apt update
    
    # Install Vim via apt
    echo "Installing Vim via apt..."
    sudo apt install -y vim
    
    echo -e "${GREEN}✓${NC} Vim installation complete."
    echo "Vim version: $(vim --version | head -n 1)"
}

installVim
