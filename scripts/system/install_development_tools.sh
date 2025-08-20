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

installDevelopmentTools() {
    echo "Checking Development Tools installation status..."
    
    # Check if development packages are already installed
    local dev_packages=("wget" "curl" "git" "build-essential" "software-properties-common")
    
    if check_multiple_packages "${dev_packages[@]}"; then
        echo -e "${GREEN}✓${NC} Development Tools are already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Development Tools are not installed. Installing..."
    
    # Install development packages
    sudo apt install -y wget curl git build-essential software-properties-common
    sudo apt install -y apt-transport-https gnupg2
    
    echo -e "${GREEN}✓${NC} Development Tools installation complete."
}

installDevelopmentTools
