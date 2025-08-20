#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Chrome is installed
check_chrome_installed() {
    if command -v google-chrome &> /dev/null || dpkg -l | grep -q "google-chrome-stable"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installChrome() {
    echo "Checking Google Chrome installation status..."
    
    if check_chrome_installed; then
        echo -e "${GREEN}✓${NC} Google Chrome is already installed."
        if command -v google-chrome &> /dev/null; then
            echo "Chrome version: $(google-chrome --version)"
        fi
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Google Chrome is not installed. Installing..."
    
    # Download Chrome
    echo "Downloading Google Chrome..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    
    # Install Chrome
    echo "Installing Google Chrome..."
    sudo apt install -y ./google-chrome-stable_current_amd64.deb
    
    # Clean up
    rm -f google-chrome-stable_current_amd64.deb
    
    echo -e "${GREEN}✓${NC} Google Chrome installation complete."
}

installChrome
