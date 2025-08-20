#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Postman is installed
check_postman_installed() {
    if snap list | grep -q "postman"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installPostman() {
    echo "Checking Postman installation status..."
    
    if check_postman_installed; then
        echo -e "${GREEN}✓${NC} Postman is already installed."
        echo "Postman version: $(snap list postman | grep postman | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Postman is not installed. Installing..."
    
    # Install Postman via snap
    echo "Installing Postman via snap..."
    sudo snap install postman --classic
    
    echo -e "${GREEN}✓${NC} Postman installation complete."
}

installPostman
