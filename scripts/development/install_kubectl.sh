#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if kubectl is installed
check_kubectl_installed() {
    if command -v kubectl &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installKubectl() {
    echo "Checking kubectl installation status..."
    
    if check_kubectl_installed; then
        echo -e "${GREEN}✓${NC} kubectl is already installed."
        echo "kubectl version: $(kubectl version --client --short)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} kubectl is not installed. Installing..."
    
    # Install kubectl via snap
    echo "Installing kubectl via snap..."
    sudo snap install kubectl --classic
    
    echo -e "${GREEN}✓${NC} kubectl installation complete."
    echo "kubectl version: $(kubectl version --client --short)"
}

installKubectl
