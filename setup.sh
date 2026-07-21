#!/usr/bin/env bash
# setup.sh - Router de comandos de Ubuntu Workstation.
#
# Router de comandos Bash (Hito 2), con `doctor` de solo lectura (Hito 4).
# Ver docs/ROADMAP.md. El flujo interactivo histórico (antes toda la lógica
# de este archivo) se preserva dentro de main_setup(), con una excepción
# deliberada: la instalación de Node.js ya no pasa por NVM
# (scripts/development/install_nodejs.sh, ahora legado/deprecado), sino por
# Mise (ver ensure_node_via_mise() y docs/adr/0002-mise-como-unico-gestor-runtime.md).
# Ese cambio se hizo en la fase de estabilización de los Hitos 2-7, no en
# el Hito 2 original.
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
# Se exporta porque las migraciones (scripts/migrations/*.sh) corren como
# procesos separados y la necesitan heredada del entorno.
UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
readonly UCI_HOME_DIR
export UCI_HOME_DIR

# shellcheck source=scripts/lib/logging.sh
source "${UCI_ROOT_DIR}/scripts/lib/logging.sh"
# shellcheck source=scripts/bootstrap/preflight.sh
source "${UCI_ROOT_DIR}/scripts/bootstrap/preflight.sh"
# shellcheck source=scripts/diagnostics/doctor.sh
source "${UCI_ROOT_DIR}/scripts/diagnostics/doctor.sh"
# shellcheck source=scripts/lib/backup.sh
source "${UCI_ROOT_DIR}/scripts/lib/backup.sh"
# shellcheck source=scripts/lib/migrations.sh
source "${UCI_ROOT_DIR}/scripts/lib/migrations.sh"
# shellcheck source=scripts/lib/runtime.sh
source "${UCI_ROOT_DIR}/scripts/lib/runtime.sh"
# shellcheck source=scripts/lib/tools_catalog.sh
source "${UCI_ROOT_DIR}/scripts/lib/tools_catalog.sh"

# Bloque gestionado de activación de Mise en archivos de shell (ADR 0007).
# Mismos marcadores que usa scripts/migrations/001_nvm_to_mise.sh.
UCI_MISE_BLOCK_BEGIN="# >>> ubuntu-workstation: mise >>>"
UCI_MISE_BLOCK_END="# <<< ubuntu-workstation: mise <<<"
readonly UCI_MISE_BLOCK_BEGIN UCI_MISE_BLOCK_END

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

# Function to show project introduction
show_introduction() {
    clear || true
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
    log_info "Presiona ENTER para continuar..."
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

    # snapd sigue en la lista básica pese a que ADR 0027 prioriza apt oficial
    # sobre Snap para la mayoría de las categorías — varios instaladores lo
    # tratan como mecanismo de último recurso. No se retira de acá sin una
    # revisión de coherencia con ADR 0027 (ver docs/TECHNICAL_REVIEW.md,
    # hallazgo B1); mientras tanto, sigue siendo necesario para los 8
    # instaladores que todavía dependen exclusivamente de Snap.
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
            log_info "Instalando dependencias básicas..."
            if sudo apt update && sudo apt install -y "${missing_deps[@]}"; then
                log_success "Dependencias básicas instaladas correctamente."
                echo ""
                log_info "Presiona ENTER para continuar..."
                read -r || true
                return 0
            else
                log_error "Error al instalar dependencias básicas. Por favor, instálalas manualmente."
                echo ""
                log_info "Comando para instalar manualmente:"
                echo -e "${CYAN}sudo apt update && sudo apt install ${missing_deps[*]}${NC}"
                echo ""
                log_info "Presiona ENTER para salir..."
                read -r || true
                exit 1
            fi
        else
            log_warn "Dependencias básicas no instaladas. El script no puede continuar."
            echo ""
            log_info "Instala las dependencias manualmente y vuelve a ejecutar el script."
            echo ""
            log_info "Presiona ENTER para salir..."
            read -r || true
            exit 1
        fi
    fi
}

# mise_bootstrap_shell_block_ensure <rc_file> <shell_name> <mise_bin>
# Agrega el bloque gestionado de activación de Mise (ADR 0007) a <rc_file>
# si todavía no está, para que futuras terminales tengan Node disponible
# sin pasar por el bootstrap de nuevo. Nunca duplica el bloque.
mise_bootstrap_shell_block_ensure() {
    local rc_file="$1" shell_name="$2" mise_bin="$3"

    if grep -qF "${UCI_MISE_BLOCK_BEGIN}" "${rc_file}" 2>/dev/null; then
        return 0
    fi

    {
        echo ""
        echo "${UCI_MISE_BLOCK_BEGIN}"
        echo "eval \"\$(${mise_bin} activate ${shell_name})\""
        echo "${UCI_MISE_BLOCK_END}"
    } >> "${rc_file}"
}

# Function to ensure Node.js/npm are available via Mise.
#
# Reemplaza el antiguo check_and_install_nodejs(), que instalaba NVM vía
# scripts/development/install_nodejs.sh (ahora legado/deprecado, ver ese
# archivo). El proyecto usa Mise como único gestor de runtimes (ADR 0002).
ensure_node_via_mise() {
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        return 0
    fi

    echo -e "${YELLOW}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                  📦 NODE.JS VÍA MISE (runtime del bootstrap) 📦             ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                              ║"
    echo "║  Para usar la interfaz interactiva, necesitas Node.js. Este proyecto usa    ║"
    echo "║  Mise como único gestor de runtimes (ya no NVM, ver ADR 0002).              ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    local mise_bin="${UCI_HOME_DIR}/.local/bin/mise"

    # 1) Detectar Mise.
    if [[ ! -x "${mise_bin}" ]] && ! command -v mise &> /dev/null; then
        # 2) Instalar Mise si falta, con confirmación explícita.
        local install_mise=""
        read -p "¿Instalar Mise para gestionar Node.js? (y/N): " install_mise || true

        if [[ ! "${install_mise}" =~ ^[Yy]$ ]]; then
            log_warn "Mise no instalado. El script no puede continuar."
            echo ""
            log_info "Instala Mise manualmente (https://mise.jdx.dev/) y vuelve a ejecutar el script."
            exit 1
        fi

        log_info "Instalando Mise (https://mise.run)..."
        if ! curl -fsSL https://mise.run | sh; then
            log_error "No se pudo instalar Mise (revisa el código de salida y la salida de curl arriba)."
            exit 1
        fi
    fi

    local mise_cmd_bin=""
    if [[ -x "${mise_bin}" ]]; then
        mise_cmd_bin="${mise_bin}"
    elif command -v mise &> /dev/null; then
        mise_cmd_bin="$(command -v mise)"
    fi

    if [[ -z "${mise_cmd_bin}" ]]; then
        log_error "Mise no quedó instalado en ${mise_bin} tras el intento de instalación."
        exit 1
    fi

    local mise_version
    mise_version="$("${mise_cmd_bin}" --version 2>/dev/null || echo 'versión desconocida')"
    log_success "Mise listo: ${mise_version} (${mise_cmd_bin})"

    # 3) Instalar mediante Mise la versión de Node de la política del
    # proyecto. El bootstrap solo necesita UNA versión funcional para
    # correr la interfaz; ver ADR 0016 para la política completa de
    # versiones (que aplica de forma más completa en el Gestor de runtimes).
    log_info "Instalando Node.js (LTS) vía Mise..."
    if ! "${mise_cmd_bin}" use --global node@lts; then
        log_error "No se pudo instalar Node.js vía Mise."
        exit 1
    fi

    local node_bin
    node_bin="$("${mise_cmd_bin}" which node 2>/dev/null || true)"
    if [[ -z "${node_bin}" ]]; then
        log_error "Mise no resolvió un ejecutable de node tras instalarlo."
        exit 1
    fi
    export PATH="$(dirname "${node_bin}"):${PATH}"

    # 4) Verificar node y npm.
    if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
        log_error "Node.js/npm no quedaron disponibles en PATH tras instalar vía Mise."
        exit 1
    fi

    log_success "Node.js $(node --version) y npm $(npm --version) disponibles vía Mise."

    # Dejar Mise activado en los archivos de shell existentes, para que
    # futuras terminales tengan Node disponible sin repetir este bootstrap.
    local rc_file
    for rc_file in "${UCI_HOME_DIR}/.bashrc" "${UCI_HOME_DIR}/.zshrc"; do
        if [[ -f "${rc_file}" ]]; then
            local shell_name="bash"
            [[ "${rc_file}" == *.zshrc ]] && shell_name="zsh"
            mise_bootstrap_shell_block_ensure "${rc_file}" "${shell_name}" "${mise_cmd_bin}"
        fi
    done

    echo ""
    log_info "Presiona ENTER para continuar..."
    read -r || true
}

# Function to setup Node.js dependencies
setup_nodejs_dependencies() {
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        log_error "package.json no encontrado. Asegúrate de que esté en el directorio del proyecto."
        exit 1
    fi

    # Check if setup.js exists
    if [[ ! -f "setup.js" ]]; then
        log_error "setup.js no encontrado. Asegúrate de que esté en el directorio del proyecto."
        exit 1
    fi

    # Install Node.js dependencies
    if [[ ! -d "node_modules" ]]; then
        log_info "Instalando dependencias de Node.js..."
        if npm install; then
            log_success "Dependencias de Node.js instaladas correctamente."
        else
            log_error "Error al instalar dependencias de Node.js."
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

    # Asegurar Node.js vía Mise (ya no NVM, ver ADR 0002)
    ensure_node_via_mise

    # Setup Node.js dependencies
    setup_nodejs_dependencies

    # Make all install scripts executable
    chmod +x scripts/*/*.sh 2>/dev/null || true

    # Launch Node.js interface
    log_info "Iniciando interfaz interactiva..."
    echo ""
    sleep 2
    clear || true
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
  ./setup.sh backup         Respalda la configuración conocida de shell/runtime
  ./setup.sh backup --dry-run   Muestra qué se respaldaría, sin crear nada
  ./setup.sh migrate --list     Lista las migraciones y su estado
  ./setup.sh migrate --dry-run  Muestra qué haría cada migración pendiente
  ./setup.sh migrate            Aplica las migraciones pendientes
  ./setup.sh runtime status     Muestra qué runtimes gestiona Mise (Node/Python/Java/Go/Rust)
  ./setup.sh install --profile <nombre>   Instala un perfil de herramientas (ver Hito 13)
  ./setup.sh install --profile custom     Igual que el flujo interactivo (elegir herramienta por herramienta)

Perfiles disponibles (docs/ROADMAP.md, Hito 13):
  minimal, cli, desktop, developer, workstation, full,
  creator, productivity, coding, editor, ai-cli

Variables de entorno:
  UCI_DEBUG=1               Activa mensajes de depuración (log_debug)
  UCI_HOME_DIR=<ruta>       Home a usar en vez de $HOME (para pruebas/simulación)
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

cmd_backup() {
    local dry_run=0
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --dry-run)
                dry_run=1
                ;;
            *)
                log_error "Opción desconocida para 'backup': '${arg}'"
                exit 1
                ;;
        esac
    done

    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    if ! backup_run "${UCI_HOME_DIR}" "${dry_run}"; then
        exit 1
    fi
}

cmd_migrate() {
    local list=0 dry_run=0
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --list)
                list=1
                ;;
            --dry-run)
                dry_run=1
                ;;
            *)
                log_error "Opción desconocida para 'migrate': '${arg}'"
                exit 1
                ;;
        esac
    done

    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    if [[ "${list}" == "1" ]]; then
        migrations_list "${UCI_HOME_DIR}"
        return 0
    fi

    if ! migrations_run "${UCI_HOME_DIR}" "${dry_run}"; then
        exit 1
    fi
}

cmd_runtime() {
    local subcommand="${1:-status}"
    if [[ $# -gt 0 ]]; then
        shift
    fi

    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    case "${subcommand}" in
        status)
            runtime_status_all "${UCI_HOME_DIR}"
            ;;
        *)
            log_error "Subcomando desconocido para 'runtime': '${subcommand}' (disponible: status)"
            exit 1
            ;;
    esac
}

# UCI_INSTALL_PROFILES: perfiles válidos para 'install --profile' (Hito 13,
# ver docs/ROADMAP.md). El valor real de cada perfil (qué herramientas
# incluye) vive en el campo 'profiles' de scripts/lib/tools_catalog.sh, no
# acá — esta lista solo sirve para validar el nombre pedido.
UCI_INSTALL_PROFILES=(minimal cli desktop developer workstation full creator productivity coding editor ai-cli)
readonly UCI_INSTALL_PROFILES

# profile_installer_run <profile>
# Instala, sin interacción, cada herramienta del catálogo cuyo campo
# 'profiles' incluya <profile>. Respeta ADR 0004 (una herramienta ya
# INSTALLED se omite, nunca se reinstala por defecto): corre 'status'
# antes de cada 'install' y solo instala si no reporta código 0.
profile_installer_run() {
    local profile="$1"
    local valid=0 p
    for p in "${UCI_INSTALL_PROFILES[@]}"; do
        [[ "${p}" == "${profile}" ]] && valid=1
    done
    if [[ "${valid}" -ne 1 ]]; then
        log_error "Perfil desconocido: '${profile}' (disponibles: ${UCI_INSTALL_PROFILES[*]}, o 'custom' para el flujo interactivo)"
        return 1
    fi

    local id script_field profiles_field script_path
    local -a profile_arr
    local status_output status_code
    local installed=0 skipped=0 failed=0

    while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        profiles_field="$(tools_registry_field "${id}" "profiles")"
        IFS=',' read -ra profile_arr <<< "${profiles_field}"
        local match=0
        for p in "${profile_arr[@]}"; do
            [[ "${p}" == "${profile}" ]] && match=1
        done
        [[ "${match}" -eq 0 ]] && continue

        script_field="$(tools_registry_field "${id}" "script")"
        script_path="${UCI_ROOT_DIR}/${script_field}"

        set +e
        status_output="$("${script_path}" status 2>&1)"
        status_code=$?
        set -e

        if [[ "${status_code}" -eq 0 ]]; then
            log_info "${id}: ya instalado, se omite"
            skipped=$((skipped + 1))
            continue
        fi

        log_info "${id}: instalando..."
        if "${script_path}" install; then
            installed=$((installed + 1))
        else
            log_error "${id}: falló la instalación"
            failed=$((failed + 1))
        fi
    done < <(tools_registry_ids)

    echo ""
    log_info "Perfil '${profile}': ${installed} instalado(s), ${skipped} ya presente(s), ${failed} con error."
    [[ "${failed}" -gt 0 ]] && return 1
    return 0
}

cmd_install() {
    local profile=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                profile="${2:-}"
                shift 2
                ;;
            --profile=*)
                profile="${1#--profile=}"
                shift
                ;;
            *)
                log_error "Opción desconocida para 'install': '$1'"
                exit 1
                ;;
        esac
    done

    if [[ -z "${profile}" || "${profile}" == "custom" ]]; then
        cmd_interactive
        return
    fi

    if ! preflight_core; then
        log_error "El preflight básico no se cumplió. Revisa los mensajes anteriores."
        exit 1
    fi

    if ! profile_installer_run "${profile}"; then
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
    # el propio flujo histórico (ensure_node_via_mise) ya le ofrece a la
    # persona usuaria instalar Mise/Node si falta.
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
        backup)
            cmd_backup "$@"
            ;;
        migrate)
            cmd_migrate "$@"
            ;;
        runtime)
            cmd_runtime "$@"
            ;;
        install)
            cmd_install "$@"
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
