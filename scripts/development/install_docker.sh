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

# Function to check if Docker is installed
check_docker_installed() {
    if command -v docker &> /dev/null && check_package_installed "docker-ce"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installDocker() {
    echo "Checking Docker installation status..."
    
    if check_docker_installed; then
        echo -e "${GREEN}✓${NC} Docker is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Docker is not installed. Installing..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    sudo apt-get update
    
    # Install Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo groupadd docker
    sudo usermod -aG docker $USER
    
    echo -e "${GREEN}✓${NC} Docker installation complete. You may need to log out and back in for group changes to take effect."
}

installDocker
