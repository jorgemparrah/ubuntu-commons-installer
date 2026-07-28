#!/usr/bin/env bash
# tests/manual/lib_manual.sh
#
# Helpers compartidos por los scripts de tests/manual/ (Hito 18, ver
# docs/ROADMAP.md). A diferencia de tests/lib/assertions.sh (Nivel 1,
# mocks) y tests/docker/ (Nivel 2, contenedores desechables), estos
# scripts instalan/desinstalan software REAL contra la red real, y
# algunos requieren una sesión de escritorio GNOME real (dbus/gsettings)
# o un reinicio (kernel HWE) — nunca deben correr en CI ni en la máquina
# de desarrollo de este repositorio, solo en una VM Ubuntu 24.04/26.04
# Desktop dedicada a esta prueba.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (mismo criterio que scripts/lib/*.sh, ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_MANUAL_LIB_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_MANUAL_LIB_LOADED=1

UCI_MANUAL_CHECKS=0
UCI_MANUAL_FAILS=0

manual_section() {
    echo ""
    echo "======================================================================"
    echo "== $1"
    echo "======================================================================"
}

manual_step() {
    echo ""
    echo "--- $1 ---"
}

# manual_check <descripción> <condición_literal>
# Misma convención que tests/docker/*.sh (ver docs/TESTING.md, "Convención:
# eval en los tests funcionales"): la condición es siempre un literal
# hardcodeado en el propio archivo de test (puede referenciar variables
# locales por nombre, que `eval` resuelve con el valor real en ese
# momento), nunca una cadena construida concatenando datos externos.
manual_check() {
    local description="$1" condition="$2"
    UCI_MANUAL_CHECKS=$((UCI_MANUAL_CHECKS + 1))
    if eval "${condition}"; then
        echo "  OK    - ${description}"
    else
        UCI_MANUAL_FAILS=$((UCI_MANUAL_FAILS + 1))
        echo "  FALLO - ${description}"
    fi
}

# manual_note <texto>
# Línea informativa que NO cuenta como chequeo. Para contexto que ayuda a
# leer el log (tamaños de descarga, pasos que quedan a mano, etc.).
manual_note() {
    echo "  ..    - $1"
}

# manual_skip <descripción> <motivo>
# Deja constancia en el log de algo que deliberadamente no se probó, sin
# contarlo como fallo. Sirve para que el log diga por qué falta algo, en
# vez de que el hueco pase inadvertido.
manual_skip() {
    echo "  SKIP  - $1 (${2})"
}

# manual_require_vm
# Guarda común de todos los scripts de este directorio: instalan software
# real y varios necesitan una sesión de escritorio, así que no deben
# correr dentro de un contenedor.
manual_require_vm() {
    if [[ -f /.dockerenv ]]; then
        echo "Este script instala software real y está pensado para una VM Ubuntu" >&2
        echo "Desktop, no para un contenedor Docker. Abortando." >&2
        exit 1
    fi
}

manual_summary() {
    echo ""
    echo "== Resumen =="
    echo "Chequeos: ${UCI_MANUAL_CHECKS}"
    echo "Fallos: ${UCI_MANUAL_FAILS}"
}

manual_exit_with_summary() {
    manual_summary
    if [[ "${UCI_MANUAL_FAILS}" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

# manual_run_action <script_path> <acción>
# Corre una acción del instalador dejando su salida en vivo en el log, y
# devuelve su código en UCI_MANUAL_LAST_CODE.
#
# IMPORTANTE: los scripts que sourcean esta biblioteca corren con
# `set -Eeuo pipefail`, y varias salidas legítimas de un instalador son
# distintas de cero (NOT_INSTALLED, BROKEN, OUTDATED…). Capturar el
# código con la forma `cmd; code=$?` haría que `set -e` abortara la
# corrida ANTES de registrar nada — que es justamente lo que pasaba antes
# de este arreglo: la batería moría en el primer 'status inicial' de la
# primera herramienta, porque NOT_INSTALLED devuelve 1. La forma
# `cmd && code=0 || code=$?` es la única que preserva el código sin
# disparar `set -e`.
UCI_MANUAL_LAST_CODE=0
manual_run_action() {
    local script="$1" action="$2"
    "${script}" "${action}" && UCI_MANUAL_LAST_CODE=0 || UCI_MANUAL_LAST_CODE=$?
    echo "(código: ${UCI_MANUAL_LAST_CODE})"
}

# manual_capture_status <script_path>
# Corre 'status' capturando su salida en UCI_MANUAL_LAST_OUTPUT y su
# código en UCI_MANUAL_LAST_CODE, sin disparar `set -e` (ver arriba).
UCI_MANUAL_LAST_OUTPUT=""
manual_capture_status() {
    local script="$1"
    UCI_MANUAL_LAST_OUTPUT="$("${script}" status 2>&1)" && UCI_MANUAL_LAST_CODE=0 || UCI_MANUAL_LAST_CODE=$?
    echo "${UCI_MANUAL_LAST_OUTPUT}"
    echo "(código: ${UCI_MANUAL_LAST_CODE})"
}

# manual_run_lifecycle <script_path> <etiqueta>
# Ciclo de vida completo status->install->status->uninstall->status contra
# un instalador real. Imprime toda la salida real de cada paso (para poder
# copiar/pegar el log completo), y deja asserts de alto nivel sobre el
# resultado esperado en cada paso.
manual_run_lifecycle() {
    local script="$1" label="$2"

    if [[ ! -x "${script}" ]]; then
        echo "  FALLO - ${label}: ${script} no existe o no es ejecutable, se omite" >&2
        UCI_MANUAL_CHECKS=$((UCI_MANUAL_CHECKS + 1))
        UCI_MANUAL_FAILS=$((UCI_MANUAL_FAILS + 1))
        return 1
    fi

    manual_step "${label}: status inicial"
    manual_capture_status "${script}"

    manual_step "${label}: install"
    manual_run_action "${script}" install
    local install_code="${UCI_MANUAL_LAST_CODE}"
    manual_check "${label}: 'install' sale con código 0" '[[ ${install_code} -eq 0 ]]'

    manual_step "${label}: status tras instalar"
    manual_capture_status "${script}"
    local status_after="${UCI_MANUAL_LAST_OUTPUT}" status_after_code="${UCI_MANUAL_LAST_CODE}"
    manual_check "${label}: 'status' reporta INSTALLED tras instalar" '[[ "${status_after}" == *"INSTALLED"* ]] && [[ "${status_after}" != *"NOT_INSTALLED"* ]]'
    manual_check "${label}: 'status' sale con código 0 tras instalar" '[[ ${status_after_code} -eq 0 ]]'

    manual_step "${label}: uninstall"
    manual_run_action "${script}" uninstall
    local uninstall_code="${UCI_MANUAL_LAST_CODE}"
    manual_check "${label}: 'uninstall' sale con código 0" '[[ ${uninstall_code} -eq 0 ]]'

    manual_step "${label}: status tras desinstalar"
    manual_capture_status "${script}"
    local status_final="${UCI_MANUAL_LAST_OUTPUT}"
    manual_check "${label}: 'status' reporta NOT_INSTALLED tras desinstalar" '[[ "${status_final}" == *"NOT_INSTALLED"* ]]'
}
