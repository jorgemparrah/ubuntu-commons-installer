#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if DBeaver is installed
check_dbeaver_installed() {
    if snap list | grep -q "dbeaver-ce"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installDBeaver() {
    echo "Checking DBeaver installation status..."
    
    if check_dbeaver_installed; then
        echo -e "${GREEN}✓${NC} DBeaver is already installed."
        echo "DBeaver version: $(snap list dbeaver-ce | grep dbeaver-ce | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} DBeaver is not installed. Installing..."
    
    # Install DBeaver via snap
    echo "Installing DBeaver via snap..."
    sudo snap install dbeaver-ce --classic
    
    echo -e "${GREEN}✓${NC} DBeaver installation complete."
}

installDBeaver
