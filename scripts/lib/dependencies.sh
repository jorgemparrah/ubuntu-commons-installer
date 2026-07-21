#!/usr/bin/env bash
# scripts/lib/dependencies.sh
#
# Helpers para instaladores que dependen de que otra herramienta del
# catálogo ya esté instalada (Hito 17, ver
# docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md).
# Primer caso: Powerlevel10k depende de Oh My Zsh.
#
# Política explícita (confirmada con el dueño del proyecto): si falta la
# dependencia, el instalador RECHAZA con un mensaje claro — nunca la
# instala por su cuenta sin que se le haya pedido explícitamente (mismo
# principio de "explícito antes que implícito" de AGENT.md sección 2).
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El
# script que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_DEPENDENCIES_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_DEPENDENCIES_SH_LOADED=1

# dependency_is_installed <script_path>
# Corre 'status' del script de la dependencia y confirma si reporta
# INSTALLED u OUTDATED (ambos cuentan como "la dependencia está presente",
# mismo criterio que usan los propios instaladores para decidir si pueden
# seguir operando, ver docs/adr/0012-modelo-de-estado-enriquecido.md).
# Revisa NOT_INSTALLED antes que INSTALLED a propósito: "NOT_INSTALLED"
# contiene la subcadena "INSTALLED" (mismo bug de substring ya detectado y
# corregido en setup.sh, ver Hito 13).
dependency_is_installed() {
    local script_path="$1"
    local status_output
    status_output="$("${script_path}" status 2>&1 || true)"

    if [[ "${status_output}" == *"NOT_INSTALLED"* ]]; then
        return 1
    fi
    [[ "${status_output}" == *"INSTALLED"* || "${status_output}" == *"OUTDATED"* ]]
}

# dependency_require_installed <script_path> <etiqueta_legible>
# Rechaza con un mensaje claro si la dependencia no está instalada.
# <etiqueta_legible> es solo para el mensaje de error (ej. "Oh My Zsh").
dependency_require_installed() {
    local script_path="$1" label="$2"

    if ! dependency_is_installed "${script_path}"; then
        echo "Falta instalar ${label} primero (dependencia, ver docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md): ${script_path} install" >&2
        return 1
    fi
    return 0
}
