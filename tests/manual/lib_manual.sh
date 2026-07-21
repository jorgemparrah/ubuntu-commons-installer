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
    local status_before status_before_code
    status_before="$("${script}" status 2>&1)"
    status_before_code=$?
    echo "${status_before}"
    echo "(código: ${status_before_code})"

    manual_step "${label}: install"
    "${script}" install
    local install_code=$?
    echo "(código: ${install_code})"
    manual_check "${label}: 'install' sale con código 0" '[[ ${install_code} -eq 0 ]]'

    manual_step "${label}: status tras instalar"
    local status_after status_after_code
    status_after="$("${script}" status 2>&1)"
    status_after_code=$?
    echo "${status_after}"
    echo "(código: ${status_after_code})"
    manual_check "${label}: 'status' reporta INSTALLED tras instalar" '[[ "${status_after}" == *"INSTALLED"* ]] && [[ "${status_after}" != *"NOT_INSTALLED"* ]]'
    manual_check "${label}: 'status' sale con código 0 tras instalar" '[[ ${status_after_code} -eq 0 ]]'

    manual_step "${label}: uninstall"
    "${script}" uninstall
    local uninstall_code=$?
    echo "(código: ${uninstall_code})"
    manual_check "${label}: 'uninstall' sale con código 0" '[[ ${uninstall_code} -eq 0 ]]'

    manual_step "${label}: status tras desinstalar"
    local status_final status_final_code
    status_final="$("${script}" status 2>&1)"
    status_final_code=$?
    echo "${status_final}"
    echo "(código: ${status_final_code})"
    manual_check "${label}: 'status' reporta NOT_INSTALLED tras desinstalar" '[[ "${status_final}" == *"NOT_INSTALLED"* ]]'
}
