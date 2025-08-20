#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Spotify is installed
check_spotify_installed() {
    if snap list | grep -q "spotify"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installSpotify() {
    echo "Checking Spotify installation status..."
    
    if check_spotify_installed; then
        echo -e "${GREEN}✓${NC} Spotify is already installed."
        echo "Spotify version: $(snap list spotify | grep spotify | awk '{print $3}')"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Spotify is not installed. Installing..."
    
    # Install Spotify via snap
    echo "Installing Spotify via snap..."
    sudo snap install spotify --classic
    
    echo -e "${GREEN}✓${NC} Spotify installation complete."
}

installSpotify
