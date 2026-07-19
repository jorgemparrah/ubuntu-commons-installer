#!/usr/bin/env bash
# tests/test_tools_catalog_docs_consistency.sh
#
# Primer consumidor real del registro central de metadata (ver
# docs/adr/0030-registro-central-de-metadata-de-instaladores.md, sección
# "Consecuencias": "Consumir este catálogo para generar o validar
# docs/TOOLS.md... es trabajo futuro"). A diferencia de
# tests/test_tools_registry.sh (que valida el catálogo contra el
# filesystem real), esta prueba valida DOCUMENTACIÓN contra el catálogo:
# confirma que cada instalador registrado en scripts/lib/tools_catalog.sh
# tiene su script mencionado en docs/TOOLS.md, para que el inventario de
# herramientas gestionadas no diverja en silencio del catálogo estructurado.
#
# No instala nada real ni modifica ningún archivo.
#
# Uso:
#   bash tests/test_tools_catalog_docs_consistency.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
UCI_TOOLS_MD="${UCI_REPO_ROOT}/docs/TOOLS.md"
readonly UCI_TOOLS_MD

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
# shellcheck source=../scripts/lib/tools_catalog.sh
source "${UCI_REPO_ROOT}/scripts/lib/tools_catalog.sh"

if [[ ! -f "${UCI_TOOLS_MD}" ]]; then
    fail "docs/TOOLS.md no existe; no se puede validar consistencia"
    print_test_summary
    exit_with_test_summary
fi

echo "== docs/TOOLS.md menciona el script de cada instalador registrado en el catálogo =="
while IFS= read -r id; do
    [[ -z "${id}" ]] && continue

    script_field="$(tools_registry_field "${id}" "script")"
    script_basename="$(basename "${script_field}")"

    if grep -qF "${script_basename}" "${UCI_TOOLS_MD}"; then
        pass "'${id}': '${script_basename}' está documentado en docs/TOOLS.md"
    else
        fail "'${id}': '${script_basename}' NO aparece en docs/TOOLS.md — el inventario de herramientas divergió del catálogo"
    fi
done < <(tools_registry_ids)

print_test_summary
exit_with_test_summary
