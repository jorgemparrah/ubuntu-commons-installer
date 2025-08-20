#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if any HWE kernel is installed
check_hwe_kernel_installed() {
    if dpkg -l | grep -q "linux-generic-hwe"; then
        return 0  # HWE kernel installed
    else
        return 1  # No HWE kernel
    fi
}

# Function to get the latest available HWE kernel
get_latest_hwe_kernel() {
    # Update package list to get latest available kernels
    sudo apt update
    
    # Find the latest HWE kernel available
    local latest_kernel=$(apt list --upgradable 2>/dev/null | grep "linux-generic-hwe" | tail -1 | cut -d'/' -f1)
    
    if [[ -n "$latest_kernel" ]]; then
        echo "$latest_kernel"
    else
        # Fallback to current Ubuntu version HWE kernel
        local ubuntu_version=$(lsb_release -cs)
        echo "linux-generic-hwe-${ubuntu_version}"
    fi
}

# Function to check if kernel update is available
check_kernel_update_available() {
    sudo apt update
    if apt list --upgradable 2>/dev/null | grep -q "linux-generic-hwe"; then
        return 0  # Update available
    else
        return 1  # No update available
    fi
}

installKernel() {
    echo "Checking Kernel & Headers installation status..."
    
    # Check if any HWE kernel is installed
    if check_hwe_kernel_installed; then
        echo -e "${GREEN}✓${NC} HWE Kernel is installed."
        
        # Check if kernel update is available
        if check_kernel_update_available; then
            echo -e "${YELLOW}!${NC} Kernel update available. Updating..."
            
            # Update kernel packages
            sudo apt upgrade -y linux-generic-hwe* linux-headers-generic linux-firmware
            
            echo -e "${GREEN}✓${NC} Kernel updated successfully."
        else
            echo -e "${BLUE}ℹ${NC} Kernel is up to date."
        fi
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} HWE Kernel not found. Installing latest version..."
    
    # Get the latest available HWE kernel
    local latest_kernel=$(get_latest_hwe_kernel)
    echo -e "${BLUE}ℹ${NC} Installing: $latest_kernel"
    
    # Install kernel packages
    sudo apt install -y --install-recommends "$latest_kernel"
    sudo apt install -y linux-firmware linux-headers-generic
    
    echo -e "${GREEN}✓${NC} Kernel & Headers installation complete."
    echo -e "${BLUE}ℹ${NC} You may need to reboot for the new kernel to take effect."
}

installKernel
