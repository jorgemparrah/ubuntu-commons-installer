#!/usr/bin/env bash
# scripts/lib/tools_catalog.sh
#
# Datos del registro central de instaladores (Hito 11, Fase 4 —
# integración mínima, ver docs/adr/0030-registro-central-de-metadata-de-instaladores.md).
# Separado de scripts/lib/tools_registry.sh (el mecanismo) a propósito:
# este archivo solo declara entradas, para poder probar el mecanismo y
# los datos por separado.
#
# Registra ÚNICAMENTE 2 de los 5 instaladores ya migrados a
# scripts/lib/installer_cli.sh + scripts/lib/apt.sh, como validación del
# diseño — no es una migración completa del catálogo. Agregar el resto
# (terminator, flameshot, vim) y los instaladores de fases futuras del
# Hito 11 es trabajo posterior, no de esta fase.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_TOOLS_CATALOG_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_TOOLS_CATALOG_SH_LOADED=1

UCI_TOOLS_CATALOG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TOOLS_CATALOG_SCRIPT_DIR
# shellcheck source=tools_registry.sh
source "${UCI_TOOLS_CATALOG_SCRIPT_DIR}/tools_registry.sh"

tools_registry_register "cmatrix" \
    "name=cmatrix" \
    "category=system" \
    "manager=apt" \
    "packages=cmatrix" \
    "script=scripts/system/install_cmatrix.sh" \
    "supported_os=24.04,26.04" \
    "supported_arch=any" \
    "requires_gui=no" \
    "requires_manual_validation=no" \
    "migration_status=migrated"

tools_registry_register "ranger" \
    "name=Ranger" \
    "category=system" \
    "manager=apt" \
    "packages=ranger" \
    "script=scripts/system/install_ranger.sh" \
    "supported_os=24.04,26.04" \
    "supported_arch=any" \
    "requires_gui=no" \
    "requires_manual_validation=no" \
    "migration_status=migrated"
