#!/usr/bin/env bash
# tests/test_tools_catalog_ubuntu_compatibility_consistency.sh
#
# Tercer consumidor real del registro central de metadata (los dos
# primeros, ver tests/test_tools_catalog_docs_consistency.sh (I19) y
# tests/test_tools_catalog_setup_js_consistency.sh (I21), validan
# docs/TOOLS.md y setup.js). Este valida docs/UBUNTU_COMPATIBILITY.md
# contra `requires_manual_validation` del catálogo: si el catálogo dice
# que una herramienta YA tiene evidencia automatizada suficiente
# (`requires_manual_validation=no`), la matriz de compatibilidad no
# debería seguir marcándola como "no verificable automáticamente"
# (pendiente de validación manual) — y viceversa, si el catálogo dice que
# SÍ necesita validación manual, la matriz no debería declararla
# "compatible" a secas (eso implica evidencia automatizada completa en
# ambas versiones de Ubuntu).
#
# No exige que TODA entrada del catálogo tenga fila en
# docs/UBUNTU_COMPATIBILITY.md todavía (varios instaladores individuales
# creados al separar los multi-paquete, ver ADR 0031, no tienen fila
# propia ahí — expandir esa matriz fila por fila es trabajo de
# documentación separado, no de esta prueba): para las que SÍ tienen fila
# (encontrada por el nombre del script), exige que no se contradigan.
#
# No instala nada real ni modifica ningún archivo.
#
# Uso:
#   bash tests/test_tools_catalog_ubuntu_compatibility_consistency.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
UCI_COMPAT_MD="${UCI_REPO_ROOT}/docs/UBUNTU_COMPATIBILITY.md"
readonly UCI_COMPAT_MD

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
# shellcheck source=../scripts/lib/tools_catalog.sh
source "${UCI_REPO_ROOT}/scripts/lib/tools_catalog.sh"

if [[ ! -f "${UCI_COMPAT_MD}" ]]; then
    fail "docs/UBUNTU_COMPATIBILITY.md no existe; no se puede validar consistencia"
    print_test_summary
    exit_with_test_summary
fi

UCI_COVERED=0
UCI_NOT_COVERED=0

echo "== docs/UBUNTU_COMPATIBILITY.md no contradice requires_manual_validation del catálogo =="
while IFS= read -r id; do
    [[ -z "${id}" ]] && continue

    script_field="$(tools_registry_field "${id}" "script")"
    script_basename="$(basename "${script_field}")"
    requires_manual="$(tools_registry_field "${id}" "requires_manual_validation")"

    row_line="$(grep -F "${script_basename}" "${UCI_COMPAT_MD}" | head -n1 || true)"
    if [[ -z "${row_line}" ]]; then
        UCI_NOT_COVERED=$((UCI_NOT_COVERED + 1))
        continue
    fi
    UCI_COVERED=$((UCI_COVERED + 1))

    if [[ "${requires_manual}" == "no" ]] && [[ "${row_line}" == *"no verificable automáticamente"* ]]; then
        fail "'${id}': el catálogo dice requires_manual_validation=no, pero docs/UBUNTU_COMPATIBILITY.md todavía lo marca 'no verificable automáticamente'"
    elif [[ "${requires_manual}" == "yes" ]] && [[ "${row_line}" == *"**compatible**"* ]]; then
        fail "'${id}': el catálogo dice requires_manual_validation=yes, pero docs/UBUNTU_COMPATIBILITY.md ya lo marca 'compatible' (evidencia automatizada completa)"
    else
        pass "'${id}': requires_manual_validation=${requires_manual} no contradice su fila en docs/UBUNTU_COMPATIBILITY.md"
    fi
done < <(tools_registry_ids)

echo ""
echo "Cobertura: ${UCI_COVERED} entrada(s) del catálogo con fila en docs/UBUNTU_COMPATIBILITY.md, ${UCI_NOT_COVERED} sin fila todavía (no es un fallo — ver nota arriba)."

print_test_summary
exit_with_test_summary
