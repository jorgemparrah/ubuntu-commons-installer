#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if Powerlevel10k is installed
check_powerlevel10k_installed() {
    if [ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

installPowerlevel10k() {
    echo "Checking Powerlevel10k installation status..."
    
    if check_powerlevel10k_installed; then
        echo -e "${GREEN}✓${NC} Powerlevel10k is already installed."
        return 0
    fi
    
    echo -e "${YELLOW}!${NC} Powerlevel10k is not installed. Installing..."
    
    # Check if Oh My Zsh is installed
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo -e "${YELLOW}Note:${NC} Oh My Zsh is not installed. Installing it first..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Install Powerlevel10k
    echo "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    
    # Set Powerlevel10k as default theme
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    
    echo -e "${GREEN}✓${NC} Powerlevel10k installation complete."
    echo -e "${YELLOW}Note:${NC} You may need to restart your terminal or run 'source ~/.zshrc' to see the changes."
    echo -e "${YELLOW}Note:${NC} Run 'p10k configure' to customize your prompt."
}

installPowerlevel10k
