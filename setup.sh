#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored text
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_status() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Function to check if zenity is installed
check_zenity() {
    if ! command -v zenity &> /dev/null; then
        print_error "Zenity no está instalado."
        print_info "Instalando zenity..."
        if sudo apt update && sudo apt install -y zenity; then
            print_status "Zenity instalado correctamente."
        else
            print_error "Error al instalar zenity. Por favor, instálalo manualmente:"
            echo "sudo apt install zenity"
            exit 1
        fi
    fi
}

# Function to display project introduction with zenity
show_introduction() {
    zenity --info \
        --title="🚀 Post-Install Setup" \
        --text="Este proyecto automatiza la instalación de herramientas esenciales para desarrolladores en sistemas Ubuntu/Debian.

🎯 Características principales:
• Instalación selectiva de herramientas
• Interfaz moderna con categorías organizadas
• Detección automática de herramientas ya instaladas
• Instalación desatendida y segura
• Scripts modulares y reutilizables

📁 Organización por categorías:
• SYSTEM: Actualizaciones, kernel, utilidades del sistema
• EDITORS: VS Code, Cursor AI, Vim
• DEVELOPMENT: Docker, Node.js, herramientas de desarrollo
• PRODUCTIVITY: Chrome, Spotify, Zoom, etc.
• MAINTENANCE: Actualizaciones finales del sistema" \
        --width=600 \
        --height=400
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for essential commands
    if ! command -v sudo &> /dev/null; then
        missing_deps+=("sudo")
    fi
    
    if ! command -v apt &> /dev/null; then
        missing_deps+=("apt")
    fi
    
    if ! command -v snap &> /dev/null; then
        missing_deps+=("snapd")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        local deps_text=""
        for dep in "${missing_deps[@]}"; do
            deps_text="$deps_text\n• $dep"
        done
        
        zenity --question \
            --title="⚠️ Dependencias Faltantes" \
            --text="Para utilizar este proyecto, necesitas instalar las siguientes dependencias del sistema:$deps_text

¿Deseas que el script intente instalar estas dependencias automáticamente?" \
            --width=500 \
            --height=300
        
        if [[ $? -eq 0 ]]; then
            print_info "Instalando dependencias..."
            if sudo apt update && sudo apt install -y "${missing_deps[@]}"; then
                print_status "Dependencias instaladas correctamente."
                zenity --info \
                    --title="✅ Dependencias Instaladas" \
                    --text="Todas las dependencias han sido instaladas correctamente." \
                    --width=400
            else
                print_error "Error al instalar dependencias."
                zenity --error \
                    --title="❌ Error de Instalación" \
                    --text="Error al instalar dependencias. Por favor, instálalas manualmente:

sudo apt update && sudo apt install ${missing_deps[*]}" \
                    --width=500
                exit 1
            fi
        else
            print_warning "Dependencias no instaladas."
            zenity --error \
                --title="❌ Dependencias Requeridas" \
                --text="El script no puede continuar sin las dependencias necesarias.

Instala las dependencias manualmente y vuelve a ejecutar el script." \
                --width=400
            exit 1
        fi
    fi
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

# Function to create zenity checklist
create_zenity_checklist() {
    local -n selected_ref="$1"
    local -n tool_keys_ref="$2"
    local -n tool_names_ref="$3"
    local -n tool_scripts_ref="$4"
    local -n tool_checks_ref="$5"
    
    # Create checklist items array
    local checklist_items=()
    local index=0
    
    for i in "${!tool_names_ref[@]}"; do
        local name="${tool_names_ref[$i]}"
        local key="${tool_keys_ref[$i]}"
        local check="${tool_checks_ref[$i]}"
        
        # Check installation status
        local status=""
        if check_installed "$name" "$check"; then
            status="✓ Instalado"
        else
            status="✗ No instalado"
        fi
        
        # Determine category
        local category=""
        case "$name" in
            "System Updates"|"Kernel & Headers"|"Development Tools"|"System Utilities"|"Multimedia Tools"|"Terminator"|"Oh My Zsh"|"Powerlevel10k"|"Ranger"|"cmatrix"|"GIMP"|"OBS Studio")
                category="SYSTEM"
                ;;
            "Visual Studio Code"|"Cursor AI IDE"|"Vim")
                category="EDITORS"
                ;;
            "Docker"|"Node.js"|"Yarn"|"Postman"|"DBeaver"|"GitKraken"|"Insomnia"|"MongoDB Compass"|"kubectl")
                category="DEVELOPMENT"
                ;;
            "ULauncher"|"Google Chrome"|"Spotify"|"Zoom"|"Flameshot")
                category="PRODUCTIVITY"
                ;;
            "Final System Update")
                category="MAINTENANCE"
                ;;
            *)
                category="SYSTEM"
                ;;
        esac
        
        # Add items to array with proper quoting (Category | Tool | Status)
        checklist_items+=("$index")
        checklist_items+=("$category")
        checklist_items+=("$name")
        checklist_items+=("$status")
        ((index++))
    done
    
    # Show zenity checklist
    local selected=$(zenity --list \
        --title="🛠️ Seleccionar Herramientas para Instalar" \
        --text="Selecciona las herramientas que deseas instalar:" \
        --checklist \
        --column="Seleccionar" \
        --column="Categoría" \
        --column="Herramienta" \
        --column="Estado" \
        --width=800 \
        --height=600 \
        --multiple \
        --separator=" " \
        "${checklist_items[@]}")
    
    if [[ -z "$selected" ]]; then
        zenity --info \
            --title="ℹ️ Sin Selección" \
            --text="No se seleccionaron herramientas. El script se cerrará." \
            --width=300
        exit 0
    fi
    
    # Process selected items
    selected_ref=()
    for item in $selected; do
        local key="${tool_keys_ref[$item]}"
        selected_ref+=("$key")
    done
}

# Function to show installation progress
show_installation_progress() {
    local -n selected_tools_ref="$1"
    local -n tool_keys_ref="$2"
    local -n tool_names_ref="$3"
    local -n tool_scripts_ref="$4"
    local -n tool_checks_ref="$5"
    
    local total_tools=${#selected_tools_ref[@]}
    local current_tool=0
    local failed_installations=()
    
    # Create progress pipe
    local progress_pipe=$(mktemp -u)
    mkfifo "$progress_pipe"
    
    # Start progress dialog
    zenity --progress \
        --title="🚀 Instalando Herramientas" \
        --text="Preparando instalación..." \
        --percentage=0 \
        --width=500 \
        --height=200 \
        --auto-close \
        --auto-kill \
        < "$progress_pipe" &
    
    local progress_pid=$!
    
    # Install tools
    for key in "${selected_tools_ref[@]}"; do
        # Find the index of the selected tool
        for i in "${!tool_keys_ref[@]}"; do
            if [[ "${tool_keys_ref[$i]}" == "$key" ]]; then
                local name="${tool_names_ref[$i]}"
                local script="${tool_scripts_ref[$i]}"
                local check="${tool_checks_ref[$i]}"
                
                ((current_tool++))
                local percentage=$((current_tool * 100 / total_tools))
                
                # Update progress
                echo "# Instalando $name... ($current_tool/$total_tools)" > "$progress_pipe"
                echo "$percentage" > "$progress_pipe"
                
                if install_tool "$name" "$script" "$check"; then
                    echo "# ✅ $name instalado correctamente" > "$progress_pipe"
                else
                    echo "# ❌ Error al instalar $name" > "$progress_pipe"
                    failed_installations+=("$name")
                fi
                
                sleep 1
                break
            fi
        done
    done
    
    # Close progress dialog
    echo "100" > "$progress_pipe"
    wait $progress_pid
    
    # Clean up
    rm -f "$progress_pipe"
    
    # Show results
    if [[ ${#failed_installations[@]} -eq 0 ]]; then
        zenity --info \
            --title="✅ Instalación Completada" \
            --text="¡Todas las herramientas seleccionadas han sido instaladas exitosamente!

Notas importantes:
• Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de Docker surtan efecto
• Reinicia tu terminal o ejecuta 'source ~/.bashrc' para que Node.js/NVM funcione
• Cursor AI IDE se puede encontrar en el menú de aplicaciones
• Flameshot está configurado con la tecla Impr Pant para capturas de pantalla" \
            --width=500 \
            --height=400
    else
        local failed_text=""
        for failed in "${failed_installations[@]}"; do
            failed_text="$failed_text\n• $failed"
        done
        
        zenity --warning \
            --title="⚠️ Instalación Parcial" \
            --text="La instalación se completó con algunos errores.

Herramientas que fallaron:$failed_text

El resto de las herramientas se instalaron correctamente." \
            --width=500 \
            --height=300
    fi
}

# Main setup function
main_setup() {
    # Check zenity
    check_zenity
    
    # Show introduction
    show_introduction
    
    # Check dependencies
    check_dependencies
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Make all install scripts executable
    chmod +x scripts/*/*.sh
    
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
    
    # Create zenity checklist
    create_zenity_checklist selected_tools tool_keys tool_names tool_scripts tool_checks
    
    # Show installation progress
    show_installation_progress selected_tools tool_keys tool_names tool_scripts tool_checks
}

# Run main setup
main_setup
