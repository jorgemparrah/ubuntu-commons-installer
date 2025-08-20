#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

installFinalUpdate() {
    echo "Performing final system update..."
    echo -e "${YELLOW}!${NC} This will update and clean the system."
    
    # Update and upgrade
    sudo apt update
    sudo apt upgrade -y
    
    # Remove unnecessary packages
    sudo apt autoremove -y
    
    echo -e "${GREEN}✓${NC} Final system update complete."
}

installFinalUpdate
