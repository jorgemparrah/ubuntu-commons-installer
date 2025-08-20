#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Oh My Zsh is installed
check_oh_my_zsh_installed() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installOhMyZsh() {
    echo "Checking Oh My Zsh installation status..."
    
    if check_oh_my_zsh_installed; then
        echo -e "${GREEN}✓${NC} Oh My Zsh is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Oh My Zsh is not installed. Installing..."
    
    # Install Oh My Zsh
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    echo -e "${GREEN}✓${NC} Oh My Zsh installation complete."
    echo -e "${YELLOW}Note:${NC} You may need to restart your terminal or run 'source ~/.zshrc' to see the changes."
}

installOhMyZsh
