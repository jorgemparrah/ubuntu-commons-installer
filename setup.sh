#!/usr/bin/env bash
# setup.sh - Router de comandos de Ubuntu Workstation.
#
# Router de comandos Bash (Hito 2), con `doctor` de solo lectura (Hito 4).
# Ver docs/ROADMAP.md. El flujo interactivo histórico (antes toda la lógica
# de este archivo) se preserva sin cambios de comportamiento dentro de
# main_setup().
#
# Ver docs/adr/0001-bootstrap-bash-sin-node.md.
set -Eeuo pipefail

# Ruta absoluta del repositorio, calculada desde la ubicación real de este
# script, para poder ejecutarse desde cualquier directorio.
UCI_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_ROOT_DIR

# Home "lógico" que usan Doctor y (a futuro) Backups/Migraciones para todo lo
# que hoy se buscaría bajo $HOME (~/.nvm, ~/.ssh, ~/.bashrc, etc.). Por
# defecto es el $HOME real; se puede apuntar a una carpeta de prueba para
# simular un home sin tocar el de esta máquina, por ejemplo:
#   UCI_HOME_DIR="$(mktemp -d)" ./setup.sh doctor --verbose
UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
readonly UCI_HOME_DIR

# shellcheck source=scripts/lib/logging.sh
source "${UCI_ROOT_DIR}/scripts/lib/logging.sh"
# shellcheck source=scripts/bootstrap/preflight.sh
source "${UCI_ROOT_DIR}/scripts/bootstrap/preflight.sh"
# shellcheck source=scripts/diagnostics/doctor.sh
source "${UCI_ROOT_DIR}/scripts/diagnostics/doctor.sh"

# --- Flujo interactivo histórico ------------------------------------------
# Todo lo que sigue hasta main_setup() es el contenido original de este
# archivo antes del Hito 2, sin cambios de comportamiento. Los únicos ajustes
# son: (a) usar las variables de color definidas en scripts/lib/logging.sh en
# vez de redeclararlas aquí, y (b) blindar los `read` que solo pausan la
# ejecución (o que alimentan una decisión y/n) para que un EOF/entrada vacía
# no aborte el script bajo `set -e` — antes, sin modo estricto, un `read`
# fallido simplemente dejaba la variable vacía y el flujo caía a la rama
# "no instalado"; con `set -e` un `read` fallido sin blindar habría cortado
# la ejecución en seco, lo cual sería un cambio de comportamiento real.

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
    read -r || true
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

        local install_deps=""
        read -p "¿Instalar dependencias automáticamente? (y/N): " install_deps || true

        if [[ "$install_deps" =~ ^[Yy]$ ]]; then
            print_info "Instalando dependencias básicas..."
            if sudo apt update && sudo apt install -y "${missing_deps[@]}"; then
                print_status "Dependencias básicas instaladas correctamente."
                echo ""
                print_info "Presiona ENTER para continuar..."
                read -r || true
                return 0
            else
                print_error "Error al instalar dependencias básicas. Por favor, instálalas manualmente."
                echo ""
                print_info "Comando para instalar manualmente:"
                echo -e "${CYAN}sudo apt update && sudo apt install ${missing_deps[*]}${NC}"
                echo ""
                print_info "Presiona ENTER para salir..."
                read -r || true
                exit 1
            fi
        else
            print_warning "Dependencias básicas no instaladas. El script no puede continuar."
            echo ""
            print_info "Instala las dependencias manualmente y vuelve a ejecutar el script."
            echo ""
            print_info "Presiona ENTER para salir..."
            read -r || true
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

        local install_node=""
        read -p "¿Instalar Node.js automáticamente? (y/N): " install_node || true

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
                        read -r || true
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
                read -r || true
                exit 1
            fi
        else
            print_warning "Node.js no instalado. El script no puede continuar."
            echo ""
            print_info "Instala Node.js manualmente y vuelve a ejecutar el script."
            echo ""
            print_info "Presiona ENTER para salir..."
            read -r || true
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

# Main function (flujo interactivo histórico). El único agregado del Hito 2
# es el `cd` inicial, para que el proyecto pueda ejecutarse desde cualquier
# directorio y no solo desde la raíz del repositorio.
main_setup() {
    cd "${UCI_ROOT_DIR}"

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

# --- Router de comandos (Hito 2) ------------------------------------------

# Versión del proyecto, leída de package.json sin depender de Node.js.
resolve_version() {
    local pkg="${UCI_ROOT_DIR}/package.json"
    if [[ -f "${pkg}" ]]; then
        grep -m1 '"version"' "${pkg}" | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*/\1/'
    else
        echo "desconocida"
    fi
}

print_usage() {
    cat <<'EOF'
Ubuntu Workstation - setup.sh

Uso:
  ./setup.sh                Ejecuta el flujo interactivo (comportamiento por defecto)
  ./setup.sh interactive    Ejecuta explícitamente el flujo interactivo
  ./setup.sh help           Muestra esta ayuda
  ./setup.sh --help         Igual que 'help'
  ./setup.sh version        Muestra la versión del proyecto
  ./setup.sh doctor         Diagnóstico de solo lectura de la workstation
  ./setup.sh doctor --verbose   Diagnóstico con detalle adicional

Variables de entorno:
  UCI_DEBUG=1               Activa mensajes de depuración (log_debug)
  UCI_HOME_DIR=<ruta>       Home a usar en vez de $HOME (para pruebas/simulación)

Comandos planificados, todavía no disponibles (ver docs/ROADMAP.md):
  backup, migrate, validate
EOF
}

cmd_version() {
    echo "Ubuntu Workstation $(resolve_version)"
}

cmd_doctor() {
    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    if ! doctor_run "${UCI_HOME_DIR}" "$@"; then
        exit 1
    fi
}

cmd_interactive() {
    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    # Diagnóstico no bloqueante de los requisitos exclusivos del modo
    # interactivo (archivos del repo, Node.js/npm). No es una compuerta dura:
    # el propio flujo histórico (check_and_install_nodejs) ya le ofrece a la
    # persona usuaria instalar Node.js si falta.
    preflight_interactive "${UCI_ROOT_DIR}" || true

    main_setup
}

main() {
    local cmd="${1:-interactive}"
    if [[ $# -gt 0 ]]; then
        shift
    fi

    case "${cmd}" in
        interactive)
            cmd_interactive
            ;;
        help|--help|-h)
            print_usage
            ;;
        version|--version|-v)
            cmd_version
            ;;
        doctor)
            cmd_doctor "$@"
            ;;
        *)
            log_error "Comando desconocido: '${cmd}'"
            echo ""
            print_usage
            exit 1
            ;;
    esac
}

main "$@"
