#!/bin/bash
# setup.sh - Script principal híbrido (Bash + Node.js)

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

# Function to show project introduction
show_introduction() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           🚀 POST-INSTALL SETUP 🚀                           ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                              ║"
    echo "║  Este proyecto automatiza la instalación de herramientas esenciales para     ║"
    echo "║  desarrolladores en sistemas Ubuntu/Debian. Incluye editores de código,      ║"
    echo "║  herramientas de desarrollo, aplicaciones de productividad y utilidades      ║"
    echo "║  del sistema.                                                                ║"
    echo "║                                                                              ║"
    echo "║  🎯 Características principales:                                             ║"
    echo "║     • Instalación selectiva de herramientas                                  ║"
    echo "║     • Interfaz moderna con categorías organizadas                            ║"
    echo "║     • Detección automática de herramientas ya instaladas                     ║"
    echo "║     • Instalación desatendida y segura                                       ║"
    echo "║     • Scripts modulares y reutilizables                                      ║"
    echo "║                                                                              ║"
    echo "║  📁 Organización por categorías:                                             ║"
    echo "║     • SYSTEM: Actualizaciones, kernel, utilidades del sistema                ║"
    echo "║     • EDITORS: VS Code, Cursor AI, Vim                                       ║"
    echo "║     • DEVELOPMENT: Docker, Node.js, herramientas de desarrollo               ║"
    echo "║     • PRODUCTIVITY: Chrome, Spotify, Zoom, etc.                              ║"
    echo "║     • MAINTENANCE: Actualizaciones finales del sistema                       ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    print_info "Presiona ENTER para continuar..."
    read -r
}

# Function to check basic dependencies
check_basic_dependencies() {
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
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v wget &> /dev/null; then
        missing_deps+=("wget")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                           ⚠️  DEPENDENCIAS FALTANTES ⚠️                           ║"
        echo "╠══════════════════════════════════════════════════════════════════════════════╣"
        echo "║                                                                              ║"
        echo "║  Para utilizar este proyecto, necesitas instalar las siguientes             ║"
        echo "║  dependencias del sistema:                                                  ║"
        echo "║                                                                              ║"
        for dep in "${missing_deps[@]}"; do
            echo -e "║     • ${YELLOW}$dep${RED}                                                                    ║"
        done
        echo "║                                                                              ║"
        echo "║  Puedes instalarlas ejecutando:                                             ║"
        echo "║                                                                              ║"
        echo -e "║     ${CYAN}sudo apt update && sudo apt install ${missing_deps[*]}${RED}                    ║"
        echo "║                                                                              ║"
        echo "║  ¿Deseas que el script intente instalar estas dependencias automáticamente? ║"
        echo "║                                                                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        
        read -p "¿Instalar dependencias automáticamente? (y/N): " install_deps
        
        if [[ "$install_deps" =~ ^[Yy]$ ]]; then
            print_info "Instalando dependencias básicas..."
            if sudo apt update && sudo apt install -y "${missing_deps[@]}"; then
                print_status "Dependencias básicas instaladas correctamente."
                echo ""
                print_info "Presiona ENTER para continuar..."
                read -r
                return 0
            else
                print_error "Error al instalar dependencias básicas. Por favor, instálalas manualmente."
                echo ""
                print_info "Comando para instalar manualmente:"
                echo -e "${CYAN}sudo apt update && sudo apt install ${missing_deps[*]}${NC}"
                echo ""
                print_info "Presiona ENTER para salir..."
                read -r
                exit 1
            fi
        else
            print_warning "Dependencias básicas no instaladas. El script no puede continuar."
            echo ""
            print_info "Instala las dependencias manualmente y vuelve a ejecutar el script."
            echo ""
            print_info "Presiona ENTER para salir..."
            read -r
            exit 1
        fi
    fi
}

# Function to check and install Node.js using existing script
check_and_install_nodejs() {
    if ! command -v node &> /dev/null; then
        echo -e "${YELLOW}"
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                           📦 INSTALACIÓN DE NODE.JS 📦                       ║"
        echo "╠══════════════════════════════════════════════════════════════════════════════╣"
        echo "║                                                                              ║"
        echo "║  Para usar la interfaz interactiva, necesitas Node.js instalado.             ║"
        echo "║                                                                              ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        
        read -p "¿Instalar Node.js automáticamente? (y/N): " install_node
        
        if [[ "$install_node" =~ ^[Yy]$ ]]; then
            print_info "Instalando Node.js usando el script existente..."
            
            # Check if Node.js installation script exists
            if [[ -f "scripts/development/install_nodejs.sh" ]]; then
                chmod +x scripts/development/install_nodejs.sh
                if ./scripts/development/install_nodejs.sh install; then
                    print_status "Node.js instalado correctamente."
                    
                    # Verify installation
                    if command -v node &> /dev/null && command -v npm &> /dev/null; then
                        print_status "Node.js y npm están disponibles."
                        echo ""
                        print_info "Presiona ENTER para continuar..."
                        read -r
                        return 0
                    else
                        print_error "Error: Node.js no se instaló correctamente."
                        exit 1
                    fi
                else
                    print_error "Error al instalar Node.js usando el script existente."
                    exit 1
                fi
            else
                print_error "Script de instalación de Node.js no encontrado."
                print_info "Puedes instalarlo manualmente visitando: https://nodejs.org/"
                echo ""
                print_info "Presiona ENTER para salir..."
                read -r
                exit 1
            fi
        else
            print_warning "Node.js no instalado. El script no puede continuar."
            echo ""
            print_info "Instala Node.js manualmente y vuelve a ejecutar el script."
            echo ""
            print_info "Presiona ENTER para salir..."
            read -r
            exit 1
        fi
    fi
}

# Function to setup Node.js dependencies
setup_nodejs_dependencies() {
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        print_error "package.json no encontrado. Asegúrate de que esté en el directorio del proyecto."
        exit 1
    fi
    
    # Check if setup.js exists
    if [[ ! -f "setup.js" ]]; then
        print_error "setup.js no encontrado. Asegúrate de que esté en el directorio del proyecto."
        exit 1
    fi
    
    # Install Node.js dependencies
    if [[ ! -d "node_modules" ]]; then
        print_info "Instalando dependencias de Node.js..."
        if npm install; then
            print_status "Dependencias de Node.js instaladas correctamente."
        else
            print_error "Error al instalar dependencias de Node.js."
            exit 1
        fi
    fi
}

# Main function
main_setup() {
    # Show introduction
    show_introduction
    
    # Check basic dependencies
    check_basic_dependencies
    
    # Check and install Node.js using existing script
    check_and_install_nodejs
    
    # Setup Node.js dependencies
    setup_nodejs_dependencies
    
    # Make all install scripts executable
    chmod +x scripts/*/*.sh 2>/dev/null || true
    
    # Launch Node.js interface
    print_info "Iniciando interfaz interactiva..."
    echo ""
    sleep 2
    clear
    node setup.js
}

# Run main setup
main_setup
