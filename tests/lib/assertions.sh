#!/usr/bin/env bash
# tests/lib/assertions.sh
#
# Harness mínimo compartido por los tests de Nivel 1 (tests/test_*.sh):
# contador de pruebas, pass()/fail(), y el resumen final estándar. Antes
# de esto, 12 archivos de test duplicaban el mismo bloque de ~15 líneas
# (ver docs/TECHNICAL_REVIEW.md, hallazgo M4) — cualquier mejora al
# harness requería editar los 12 a mano.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (mismo criterio que scripts/lib/*.sh, ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_TEST_ASSERTIONS_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_TEST_ASSERTIONS_SH_LOADED=1

UCI_TESTS_RUN=0
UCI_TESTS_FAILED=0

pass() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    echo "  OK  - $1"
}

fail() {
    UCI_TESTS_RUN=$((UCI_TESTS_RUN + 1))
    UCI_TESTS_FAILED=$((UCI_TESTS_FAILED + 1))
    echo "FALLO - $1"
}

# print_test_summary
# Imprime el resumen estándar ("== Resumen ==" + conteo de pruebas/fallos).
# No sale del proceso: el propio archivo de test puede imprimir notas
# adicionales (ver tests/test_kernel_hwe_fallback.sh,
# tests/test_snap_installers_contract.sh) antes de llamar a
# exit_with_test_summary.
print_test_summary() {
    echo ""
    echo "== Resumen =="
    echo "Pruebas ejecutadas: ${UCI_TESTS_RUN}"
    echo "Fallos: ${UCI_TESTS_FAILED}"
}

# exit_with_test_summary
# Última línea de cada archivo de test: sale 1 si hubo fallos, 0 si no.
exit_with_test_summary() {
    if [[ "${UCI_TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}
