#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if OBS Studio is installed
check_obs_studio_installed() {
    if command -v obs &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installObsStudio() {
    echo "Checking OBS Studio installation status..."
    
    if check_obs_studio_installed; then
        echo -e "${GREEN}✓${NC} OBS Studio is already installed."
        echo "OBS Studio version: $(obs --version)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} OBS Studio is not installed. Installing..."
    
    # Install OBS Studio via snap
    echo "Installing OBS Studio via snap..."
    sudo snap install obs-studio --classic
    
    echo -e "${GREEN}✓${NC} OBS Studio installation complete."
    echo "OBS Studio version: $(obs --version)"
}

installObsStudio
