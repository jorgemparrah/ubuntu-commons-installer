#!/usr/bin/env bash
# scripts/lib/logging.sh
#
# Biblioteca mínima y reutilizable de logging para Ubuntu Workstation.
# Ver docs/ROADMAP.md (Hito 2: Bootstrap) y docs/adr/0001-bootstrap-bash-sin-node.md.
#
# Pensada para cargarse con `source`, nunca para ejecutarse directamente.
# Por eso NO declara `set -Eeuo pipefail`: sourcing propaga las opciones de
# shell al script que la carga, y el que decide el modo estricto es siempre
# el script que se ejecuta (setup.sh), no esta biblioteca.

# Guarda de carga única: evita reasignar las variables `readonly` de más
# abajo si este archivo se termina cargando más de una vez (por ejemplo,
# porque otra biblioteca sourceada también lo carga).
if [[ "${UCI_LOGGING_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_LOGGING_SH_LOADED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
readonly RED GREEN YELLOW BLUE CYAN PURPLE NC

log_info() {
    echo -e "${CYAN}ℹ $*${NC}"
}

log_warn() {
    echo -e "${YELLOW}! $*${NC}"
}

log_error() {
    echo -e "${RED}✗ $*${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

# Solo imprime si UCI_DEBUG=1. Ejemplo: UCI_DEBUG=1 ./setup.sh help
log_debug() {
    if [[ "${UCI_DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[debug] $*${NC}" >&2
    fi
}
