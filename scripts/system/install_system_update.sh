#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

installSystemUpdate() {
    echo "Checking System Update status..."
    
    echo -e "${YELLOW}!${NC} Performing system updates..."
    
    # Update system
    sudo apt update
    sudo apt upgrade -y
    
    echo -e "${GREEN}✓${NC} System updates complete."
}

installSystemUpdate
