#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Node.js is installed
check_nodejs_installed() {
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installNodeJS() {
    echo "Checking Node.js installation status..."
    
    if check_nodejs_installed; then
        echo -e "${GREEN}✓${NC} Node.js is already installed."
        echo "Node version: $(node --version)"
        echo "NPM version: $(npm --version)"
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Node.js is not installed. Installing..."
    
    # Install NVM
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    
    # Load NVM in current session
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install Node.js LTS and latest
    nvm install --lts
    nvm install node
    
    # Use LTS as default
    nvm use --lts
    
    echo -e "${GREEN}✓${NC} Node.js installation complete."
    echo "Please restart your terminal or run: source ~/.bashrc"
}

installNodeJS
