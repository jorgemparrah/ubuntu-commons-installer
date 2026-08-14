#!/usr/bin/env bash
# scripts/lib/tools_registry.sh
#
# Registro central de metadata de instaladores (Hito 11, ver
# docs/ROADMAP.md y docs/adr/0030-registro-central-de-metadata-de-instaladores.md).
# Catálogo en Bash puro, sin YAML/JSON ni parser externo — mismo patrón ya
# aceptado en UCI_RUNTIME_CATALOG (scripts/lib/runtime.sh, Hito 8).
#
# Puramente aditivo: no se sourcea desde setup.sh/setup.js, no reemplaza
# el array `tools` de setup.js, no cambia el comportamiento de ningún
# instalador ni del dispatcher/helpers compartidos. Solo describe
# metadata de solo lectura sobre las herramientas ya registradas.
#
# Uso:
#   tools_registry_register <id> campo=valor [campo=valor...]
#   tools_registry_ids                       # todos los ids registrados, uno por línea
#   tools_registry_field <id> <campo>         # valor de un campo (vacío si no existe)
#   tools_registry_has <id>                   # 0 si el id está registrado, 1 si no
#
# Campos mínimos esperados (ver ADR 0030): name, category, manager,
# packages (lista separada por comas), script, supported_os,
# supported_arch, requires_gui, requires_manual_validation,
# migration_status.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_TOOLS_REGISTRY_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_TOOLS_REGISTRY_SH_LOADED=1

UCI_TOOLS_REGISTRY_IDS=()
declare -A UCI_TOOLS_REGISTRY_META

# tools_registry_register <id> campo=valor [campo=valor...]
# Registra (o vuelve a registrar, sobrescribiendo) una herramienta. Los
# campos se guardan como pares clave "id:campo" -> valor; no hay un
# esquema fijo forzado a nivel de la biblioteca (el esquema mínimo
# recomendado vive en ADR 0030, no acá), para no acoplar esta biblioteca
# a una lista de campos que podría crecer.
tools_registry_register() {
    local id="$1"
    shift

    if ! tools_registry_has "${id}"; then
        UCI_TOOLS_REGISTRY_IDS+=("${id}")
    fi

    local pair key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        UCI_TOOLS_REGISTRY_META["${id}:${key}"]="${value}"
    done
}

# tools_registry_has <id>
tools_registry_has() {
    local id="$1" existing
    for existing in "${UCI_TOOLS_REGISTRY_IDS[@]:-}"; do
        if [[ "${existing}" == "${id}" ]]; then
            return 0
        fi
    done
    return 1
}

# tools_registry_ids
# Todos los ids registrados, uno por línea, en orden de registro.
tools_registry_ids() {
    local id
    for id in "${UCI_TOOLS_REGISTRY_IDS[@]:-}"; do
        [[ -n "${id}" ]] && echo "${id}"
    done
}

# tools_registry_field <id> <campo>
# Imprime el valor del campo, o nada si no existe (nunca falla el
# proceso: un campo ausente es información legítima, no un error).
tools_registry_field() {
    local id="$1" field="$2"
    echo "${UCI_TOOLS_REGISTRY_META["${id}:${field}"]:-}"
}
