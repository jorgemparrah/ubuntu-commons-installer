#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if GitKraken is installed
check_gitkraken_installed() {
    if snap list | grep -q "gitkraken"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installGitKraken() {
    echo "Checking GitKraken installation status..."
    
    if check_gitkraken_installed; then
        echo -e "${GREEN}✓${NC} GitKraken is already installed."
        echo "GitKraken version: $(snap list gitkraken | grep gitkraken | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} GitKraken is not installed. Installing..."
    
    # Install GitKraken via snap
    echo "Installing GitKraken via snap..."
    sudo snap install gitkraken --classic
    
    echo -e "${GREEN}✓${NC} GitKraken installation complete."
}

installGitKraken
