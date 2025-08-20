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

# Function to check if Yarn is installed
check_yarn_installed() {
    if command -v yarn &> /dev/null || check_package_installed "yarn"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installYarn() {
    echo "Checking Yarn installation status..."
    
    if check_yarn_installed; then
        echo -e "${GREEN}✓${NC} Yarn is already installed."
        if command -v yarn &> /dev/null; then
            echo "Yarn version: $(yarn --version)"
        fi
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Yarn is not installed. Installing..."
    
    # Add Yarn GPG key
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg
    
    # Add Yarn repository
    echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    
    # Update and install Yarn
    sudo apt update
    sudo apt install -y yarn
    
    echo -e "${GREEN}✓${NC} Yarn installation complete."
}

installYarn
