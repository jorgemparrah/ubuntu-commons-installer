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

# Function to check if multiple packages are installed
check_multiple_packages() {
    local packages=("$@")
    local all_installed=true
    
    for package in "${packages[@]}"; do
        if ! check_package_installed "$package"; then
            all_installed=false
            break
        fi
    done
    
    return $([ "$all_installed" = true ] && echo 0 || echo 1)
}

installSystemUtils() {
    echo "Checking System Utilities installation status..."
    
    # Check if system utility packages are already installed
    local utils_packages=("meld" "baobab" "gparted")
    
    if check_multiple_packages "${utils_packages[@]}"; then
        echo -e "${GREEN}✓${NC} System Utilities are already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} System Utilities are not installed. Installing..."
    
    # Install system utility packages
    sudo apt install -y meld baobab gparted
    
    echo -e "${GREEN}✓${NC} System Utilities installation complete."
}

installSystemUtils
