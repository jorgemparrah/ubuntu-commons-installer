#!/usr/bin/env bash
# scripts/lib/installer_cli.sh
#
# Dispatcher compartido para la CLI de los instaladores (Hito 11, Fase 1 —
# ver docs/ROADMAP.md y docs/adr/0029-contrato-completo-de-instalador-referencia.md).
# Reemplaza el bloque `main()`/`case` que ~29 de los ~30 instaladores del
# proyecto duplicaban de forma casi idéntica.
#
# Contrato de 6 verbos aprobado por ADR 0004, ADR 0012 y ADR 0029, más un
# 7° verbo opcional agregado en el Hito 17 (ver ADR 0042):
#
#   status | install | uninstall | reinstall | update | repair | configure
#
# Uso: cada instalador define `TOOL_NAME` y las funciones que necesite,
# sourcea esta biblioteca, y termina con una única línea:
#
#   installer_run_cli "$@"
#
# Funciones OBLIGATORIAS (el instalador no puede omitirlas):
#   - check_status    (verbo 'status')
#   - install_tool     (verbo 'install')
#   - uninstall_tool   (verbo 'uninstall')
#
# Si alguna de las tres no está definida cuando se invoca el verbo que la
# necesita, el dispatcher lo detecta con `declare -F` (comprobación
# estática de Bash, sin ejecutar nada) y reporta un error interno claro,
# en vez de fallar con "command not found" a mitad de camino.
#
# Funciones OPCIONALES, con semántica distinta cada una:
#   - reinstall_tool: si el instalador no la define, el dispatcher usa el
#     comportamiento mecánico que YA era el estándar de facto en el
#     proyecto (desinstalar + instalar). Esto no es una acción por
#     defecto ante una herramienta instalada y sana (ADR 0004) — solo se
#     ejecuta si la persona usuaria pide 'reinstall' explícitamente.
#   - update_tool / repair_tool / configure_tool: NO tienen fallback
#     implícito. Si el instalador no las define, el dispatcher rechaza el
#     verbo con un mensaje explícito y código de salida distinto ('no
#     soportado'), citando ADR 0029 (update/repair) o ADR 0042
#     (configure). 'update' y 'repair' tienen semántica propia (responden
#     a los estados OUTDATED/BROKEN de ADR 0012) — NUNCA se redirigen en
#     silencio a 'reinstall', que es una operación distinta (destructiva:
#     desinstala antes de volver a instalar). 'configure' (Hito 17, ADR
#     0042) es para pasos post-instalación que solo tienen sentido si la
#     herramienta ya está instalada (por ejemplo, el atajo de teclado de
#     Flameshot) — cada instalador que la implemente es responsable de
#     rechazarla si su propio `check_status` no reporta `INSTALLED`,
#     mismo criterio que ya usa `repair_tool` para rechazar sobre
#     `NOT_INSTALLED` (el dispatcher no lo fuerza centralmente, para no
#     asumir cómo cada instalador define "instalado").
#
# Diseño explícitamente verificado contra los requisitos del Hito 11 Fase 1:
#   - No usa `eval` en ningún punto (declare -F es una comprobación
#     estática de Bash, no ejecuta código arbitrario).
#   - No oculta códigos de salida: cada rama propaga el código de la
#     función invocada (bajo `set -e`, un código ≠0 aborta el proceso con
#     ese mismo código; el `return $?` es defensivo para cuando se
#     invoca sin modo estricto).
#   - No depende de Node.js: Bash puro.
#   - No modifica `$HOME` ni el filesystem por sí mismo: solo enruta.
#   - Funciona bajo `set -Eeuo pipefail`: usa `"${1:-}"` para tolerar la
#     ausencia de argumentos sin "unbound variable".
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El
# script que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_INSTALLER_CLI_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_INSTALLER_CLI_SH_LOADED=1

# Códigos de salida explícitos del propio dispatcher (no confundir con los
# que devuelva la lógica de negocio del instalador, que se propagan tal
# cual). Documentados para que un caller (tests, CI) pueda distinguir
# "uso inválido" de "el instalador no implementa esto todavía".
UCI_INSTALLER_CLI_EXIT_USAGE=1
UCI_INSTALLER_CLI_EXIT_MISSING_FN=2
UCI_INSTALLER_CLI_EXIT_UNSUPPORTED=3
readonly UCI_INSTALLER_CLI_EXIT_USAGE UCI_INSTALLER_CLI_EXIT_MISSING_FN UCI_INSTALLER_CLI_EXIT_UNSUPPORTED

# installer_cli_usage
installer_cli_usage() {
    echo "Uso: $0 {status|install|uninstall|reinstall|update|repair|configure}" >&2
}

# installer_cli_require_fn <nombre_de_funcion>
# `declare -F` es una comprobación estática de Bash: 0 si la función está
# definida, 1 si no. Nunca ejecuta el contenido de la función.
installer_cli_require_fn() {
    local fn_name="$1"
    if ! declare -F "${fn_name}" > /dev/null; then
        echo "Error interno: ${TOOL_NAME:-este instalador} no implementa la función obligatoria '${fn_name}()'." >&2
        return 1
    fi
    return 0
}

# installer_cli_reinstall_default
# Comportamiento mecánico estándar de 'reinstall' cuando el instalador no
# define su propio reinstall_tool: desinstalar y volver a instalar.
installer_cli_reinstall_default() {
    uninstall_tool
    install_tool
}

# installer_run_cli <verbo>
# Punto de entrada único. Última línea de cada instalador migrado.
installer_run_cli() {
    local verb="${1:-}"

    case "${verb}" in
        status)
            installer_cli_require_fn check_status || return "${UCI_INSTALLER_CLI_EXIT_MISSING_FN}"
            check_status
            return $?
            ;;
        install)
            installer_cli_require_fn install_tool || return "${UCI_INSTALLER_CLI_EXIT_MISSING_FN}"
            install_tool
            return $?
            ;;
        uninstall)
            installer_cli_require_fn uninstall_tool || return "${UCI_INSTALLER_CLI_EXIT_MISSING_FN}"
            uninstall_tool
            return $?
            ;;
        reinstall)
            installer_cli_require_fn uninstall_tool || return "${UCI_INSTALLER_CLI_EXIT_MISSING_FN}"
            installer_cli_require_fn install_tool || return "${UCI_INSTALLER_CLI_EXIT_MISSING_FN}"
            if declare -F reinstall_tool > /dev/null; then
                reinstall_tool
            else
                installer_cli_reinstall_default
            fi
            return $?
            ;;
        update)
            if ! declare -F update_tool > /dev/null; then
                echo "${TOOL_NAME:-Este instalador} todavía no implementa 'update' (ver docs/adr/0029-contrato-completo-de-instalador-referencia.md)." >&2
                return "${UCI_INSTALLER_CLI_EXIT_UNSUPPORTED}"
            fi
            update_tool
            return $?
            ;;
        repair)
            if ! declare -F repair_tool > /dev/null; then
                echo "${TOOL_NAME:-Este instalador} todavía no implementa 'repair' (ver docs/adr/0029-contrato-completo-de-instalador-referencia.md)." >&2
                return "${UCI_INSTALLER_CLI_EXIT_UNSUPPORTED}"
            fi
            repair_tool
            return $?
            ;;
        configure)
            if ! declare -F configure_tool > /dev/null; then
                echo "${TOOL_NAME:-Este instalador} todavía no implementa 'configure' (ver docs/adr/0042-configuraciones-post-instalacion-y-dependencias.md)." >&2
                return "${UCI_INSTALLER_CLI_EXIT_UNSUPPORTED}"
            fi
            configure_tool
            return $?
            ;;
        *)
            installer_cli_usage
            return "${UCI_INSTALLER_CLI_EXIT_USAGE}"
            ;;
    esac
}
