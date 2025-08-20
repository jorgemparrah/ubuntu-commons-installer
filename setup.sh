#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if a tool is already installed
check_installed() {
    local tool_name="$1"
    local check_command="$2"
    
    # First check if it's a command (APT packages)
    if command -v $check_command &> /dev/null; then
        return 0  # Installed
    fi
    
    # Then check if it's a snap package
    if snap list | grep -q "^$check_command "; then
        return 0  # Installed
    fi
    
    # Check for special cases
    case "$check_command" in
        "ulauncher")
            if [ -d "$HOME/.config/ulauncher" ]; then
                return 0  # Installed
            fi
            ;;
        "cursor")
            if [ -f "$HOME/.local/share/applications/cursor.desktop" ] || [ -f "/usr/share/applications/cursor.desktop" ]; then
                return 0  # Installed
            fi
            ;;
        "code")
            if command -v code &> /dev/null || snap list | grep -q "^code "; then
                return 0  # Installed
            fi
            ;;
        "docker")
            if command -v docker &> /dev/null || snap list | grep -q "^docker "; then
                return 0  # Installed
            fi
            ;;
        "node")
            if command -v node &> /dev/null; then
                return 0  # Installed
            fi
            ;;
        "yarn")
            if command -v yarn &> /dev/null; then
                return 0  # Installed
            fi
            ;;
        "google-chrome")
            if command -v google-chrome &> /dev/null || snap list | grep -q "^google-chrome "; then
                return 0  # Installed
            fi
            ;;
        "zoom-client")
            if command -v zoom &> /dev/null || snap list | grep -q "^zoom-client "; then
                return 0  # Installed
            fi
            ;;
        "flameshot")
            if command -v flameshot &> /dev/null; then
                return 0  # Installed
            fi
            ;;
    esac
    
    return 1  # Not installed
}

# Function to install a tool
install_tool() {
    local tool_name="$1"
    local script_name="$2"
    local check_command="$3"
    
    print_status "Installing $tool_name..."
    if "$SCRIPT_DIR/$script_name"; then
        print_status "$tool_name installation completed successfully."
    else
        print_error "Failed to install $tool_name."
        return 1
    fi
}

# Function to clear screen
clear_screen() {
    clear
}

# Function to display checkbox menu
display_checkbox_menu() {
    local -n selected_ref="$1"
    local -n tool_keys_ref="$2"
    local -n tool_names_ref="$3"
    local -n tool_scripts_ref="$4"
    local -n tool_checks_ref="$5"
    
    clear_screen
    print_header "Post-Install Setup"
    echo "Select tools to install (use 'x' or SPACE to toggle, ENTER to confirm, 'q' to quit):"
    echo ""
    
    print_header "Tool Selection"
    echo "Use 'x' or SPACE to toggle selection, ENTER to confirm, 'a' to select all, 'n' to select none, 'q' to quit"
    echo ""
    
    # Create arrays for menu
    declare -a menu_keys=()
    declare -a menu_names=()
    declare -a menu_status=()
    
    local index=0
    for i in "${!tool_names_ref[@]}"; do
        menu_keys+=("${tool_keys_ref[$i]}")
        menu_names+=("${tool_names_ref[$i]}")
        
        # Always start unchecked (but keep installation status display)
        menu_status+=("false")
        ((index++))
    done
    
    # Display menu
    local current_selection=0
    local total_items=${#menu_names[@]}
    
    while true; do
        # Clear menu area and redraw
        clear_screen
        print_header "Post-Install Setup"
        echo "Select tools to install (use 'x' or SPACE to toggle, ENTER to confirm, 'q' to quit):"
        echo ""
        
        print_header "Tool Selection"
        echo "Use 'x' or SPACE to toggle selection, ENTER to confirm, 'a' to select all, 'n' to select none, 'q' to quit"
        echo ""
        
        # Display menu items with installation status
        for i in "${!menu_names[@]}"; do
            local checkbox="☐"
            local color="$NC"
            local status_icon=""
            local status_text=""
            
            # Check installation status
            local name="${tool_names_ref[$i]}"
            local check="${tool_checks_ref[$i]}"
            if check_installed "$name" "$check"; then
                status_icon="${GREEN}✓${NC}"
                status_text="(installed)"
            else
                status_icon="${RED}✗${NC}"
                status_text="(not installed)"
            fi
            
            # Check selection status
            if [[ "${menu_status[$i]}" == "true" ]]; then
                checkbox="☑"
                color="$GREEN"
            fi
            
            # Display the line
            if [[ $i -eq $current_selection ]]; then
                echo -e "${CYAN}>${NC} $checkbox ${color}${menu_names[$i]}${NC} $status_icon $status_text"
            else
                echo -e "  $checkbox ${color}${menu_names[$i]}${NC} $status_icon $status_text"
            fi
        done
        
        # Read single character
        read -rsn1 key
        
        case "$key" in
            $'\x1b')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    "[A") # Up arrow
                        if [[ $current_selection -gt 0 ]]; then
                            ((current_selection--))
                        fi
                        ;;
                    "[B") # Down arrow
                        if [[ $current_selection -lt $((total_items-1)) ]]; then
                            ((current_selection++))
                        fi
                        ;;
                esac
                ;;
            " "|"x"|"X")  # Space or 'x' - toggle selection
                # Simple toggle for individual tools
                if [[ "${menu_status[$current_selection]}" == "true" ]]; then
                    menu_status[$current_selection]="false"
                else
                    menu_status[$current_selection]="true"
                fi
                ;;
            "a"|"A")  # Select all
                for i in "${!menu_status[@]}"; do
                    menu_status[$i]="true"
                done
                ;;
            "n"|"N")  # Select none
                for i in "${!menu_status[@]}"; do
                    menu_status[$i]="false"
                done
                ;;
            "q"|"Q")  # Quit
                print_status "Exiting setup."
                exit 0
                ;;
            "")  # Enter - confirm selection
                break
                ;;
        esac
    done
    
    # Process final selection
    selected_ref=()
    for i in "${!menu_status[@]}"; do
        if [[ "${menu_status[$i]}" == "true" ]]; then
            local key="${menu_keys[$i]}"
            selected_ref+=("$key")
        fi
    done
}

# Main setup function
main_setup() {
    print_header "Post-Install Setup"
    echo "Select tools to install (use 'x' or SPACE to toggle, ENTER to confirm):"
    echo ""
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Make all install scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    
    # Define tools with their installation info (ordered)
    declare -a tool_keys=(
        "system_update"
        "kernel"
        "development_tools"
        "system_utils"
        "multimedia"
        "ulauncher"
        "vscode"
        "cursor"
        "vim"
        "docker"
        "nodejs"
        "yarn"
        "postman"
        "dbeaver"
        "gitkraken"
        "insomnia"
        "mongodb_compass"
        "kubectl"
        "terminator"
        "oh_my_zsh"
        "powerlevel10k"
        "ranger"
        "cmatrix"
        "gimp"
        "obs_studio"
        "chrome"
        "spotify"
        "zoom"
        "flameshot"
        "final_update"
    )
    
    declare -a tool_names=(
        "System Updates"
        "Kernel & Headers"
        "Development Tools"
        "System Utilities"
        "Multimedia Tools"
        "ULauncher"
        "Visual Studio Code"
        "Cursor AI IDE"
        "Vim"
        "Docker"
        "Node.js"
        "Yarn"
        "Postman"
        "DBeaver"
        "GitKraken"
        "Insomnia"
        "MongoDB Compass"
        "kubectl"
        "Terminator"
        "Oh My Zsh"
        "Powerlevel10k"
        "Ranger"
        "cmatrix"
        "GIMP"
        "OBS Studio"
        "Google Chrome"
        "Spotify"
        "Zoom"
        "Flameshot"
        "Final System Update"
    )
    
    declare -a tool_scripts=(
        "scripts/system/install_system_update.sh"
        "scripts/system/install_kernel.sh"
        "scripts/system/install_development_tools.sh"
        "scripts/system/install_system_utils.sh"
        "scripts/system/install_multimedia.sh"
        "scripts/productivity/install_ulauncher.sh"
        "scripts/editors/install_vscode.sh"
        "scripts/editors/install_cursor.sh"
        "scripts/editors/install_vim.sh"
        "scripts/development/install_docker.sh"
        "scripts/development/install_nodejs.sh"
        "scripts/development/install_yarn.sh"
        "scripts/development/install_postman.sh"
        "scripts/development/install_dbeaver.sh"
        "scripts/development/install_gitkraken.sh"
        "scripts/development/install_insomnia.sh"
        "scripts/development/install_mongodb_compass.sh"
        "scripts/development/install_kubectl.sh"
        "scripts/system/install_terminator.sh"
        "scripts/system/install_oh_my_zsh.sh"
        "scripts/system/install_powerlevel10k.sh"
        "scripts/system/install_ranger.sh"
        "scripts/system/install_cmatrix.sh"
        "scripts/system/install_gimp.sh"
        "scripts/system/install_obs_studio.sh"
        "scripts/productivity/install_chrome.sh"
        "scripts/productivity/install_spotify.sh"
        "scripts/productivity/install_zoom.sh"
        "scripts/productivity/install_flameshot.sh"
        "scripts/maintenance/install_final_update.sh"
    )
    
    declare -a tool_checks=(
        ""
        ""
        "wget"
        "meld"
        "vlc"
        "ulauncher"
        "code"
        "cursor"
        "vim"
        "docker"
        "node"
        "yarn"
        "postman"
        "dbeaver-ce"
        "gitkraken"
        "insomnia"
        "mongodb-compass"
        "kubectl"
        "terminator"
        ""
        ""
        "ranger"
        "cmatrix"
        "gimp"
        "obs-studio"
        "google-chrome"
        "spotify"
        "zoom-client"
        "flameshot"
        ""
    )
    
    # Array to store selected tools
    declare -a selected_tools=()
    
    # Display checkbox menu
    display_checkbox_menu selected_tools tool_keys tool_names tool_scripts tool_checks
    
    # Check if any tools were selected
    if [[ ${#selected_tools[@]} -eq 0 ]]; then
        print_status "No tools selected. Exiting..."
        exit 0
    fi
    
    # Show final selection
    clear_screen
    print_header "Selected Tools"
    for key in "${selected_tools[@]}"; do
        # Find the index of the selected tool
        for i in "${!tool_keys[@]}"; do
            if [[ "${tool_keys[$i]}" == "$key" ]]; then
                echo "☑ ${tool_names[$i]}"
                break
            fi
        done
    done
    echo ""
    
    # Confirmation
    read -p "Proceed with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "Installation cancelled."
        exit 0
    fi
    
    # Start installation
    print_header "Starting Installation"
    echo "This may take a while. Please be patient..."
    echo ""
    
    local failed_installations=()
    
    # Install selected tools
    for key in "${selected_tools[@]}"; do
        # Find the index of the selected tool
        for i in "${!tool_keys[@]}"; do
            if [[ "${tool_keys[$i]}" == "$key" ]]; then
                local name="${tool_names[$i]}"
                local script="${tool_scripts[$i]}"
                local check="${tool_checks[$i]}"
                
                print_header "Installing $name"
                if install_tool "$name" "$script" "$check"; then
                    print_status "$name installed successfully!"
                else
                    print_error "$name installation failed!"
                    failed_installations+=("$name")
                fi
                echo ""
                break
            fi
        done
    done
    
    # Final summary
    print_header "Installation Summary"
    if [[ ${#failed_installations[@]} -eq 0 ]]; then
        print_status "All selected tools were installed successfully!"
    else
        print_warning "Some installations failed:"
        for failed in "${failed_installations[@]}"; do
            echo "- $failed"
        done
    fi
    
    echo ""
    print_header "Important Notes"
    echo "- You may need to log out and back in for Docker group changes to take effect"
    echo "- Restart your terminal or run 'source ~/.bashrc' for Node.js/NVM to work"
    echo "- Cursor AI IDE can be found in your application menu"
    echo "- Flameshot is configured with the Print key for screenshots"
    echo ""
    print_status "Setup complete!"
}

# Run main setup
main_setup
