#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if MongoDB Compass is installed
check_mongodb_compass_installed() {
    if snap list | grep -q "mongodb-compass"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installMongoDBCompass() {
    echo "Checking MongoDB Compass installation status..."
    
    if check_mongodb_compass_installed; then
        echo -e "${GREEN}✓${NC} MongoDB Compass is already installed."
        echo "MongoDB Compass version: $(snap list mongodb-compass | grep mongodb-compass | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} MongoDB Compass is not installed. Installing..."
    
    # Install MongoDB Compass via snap
    echo "Installing MongoDB Compass via snap..."
    sudo snap install mongodb-compass --classic
    
    echo -e "${GREEN}✓${NC} MongoDB Compass installation complete."
}

installMongoDBCompass
