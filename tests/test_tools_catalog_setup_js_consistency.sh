#!/usr/bin/env bash
# tests/test_tools_catalog_setup_js_consistency.sh
#
# Segundo consumidor real del registro central de metadata (el primero,
# tests/test_tools_catalog_docs_consistency.sh, valida docs/TOOLS.md; este
# valida el menú interactivo de setup.js). Confirma que cada herramienta
# registrada en scripts/lib/tools_catalog.sh que el menú DEBERÍA ofrecer
# (es decir, que no es miembro interno de un agrupador — ver ADR 0031)
# tiene una entrada real en el array `tools` de setup.js. Si un instalador
# se registra en el catálogo pero se olvida de agregar/queda huérfano en
# setup.js, esta prueba falla.
#
# No instala nada real ni modifica ningún archivo.
#
# Uso:
#   bash tests/test_tools_catalog_setup_js_consistency.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
UCI_SETUP_JS="${UCI_REPO_ROOT}/setup.js"
readonly UCI_SETUP_JS

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"
# shellcheck source=../scripts/lib/tools_catalog.sh
source "${UCI_REPO_ROOT}/scripts/lib/tools_catalog.sh"

if [[ ! -f "${UCI_SETUP_JS}" ]]; then
    fail "setup.js no existe; no se puede validar consistencia"
    print_test_summary
    exit_with_test_summary
fi

echo "== Recolectar ids que son miembros internos de algún agrupador (no deberían tener entrada propia en setup.js) =="
declare -A UCI_GROUP_MEMBERS=()
while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    if [[ "$(tools_registry_field "${id}" "kind")" == "group" ]]; then
        members_field="$(tools_registry_field "${id}" "members")"
        IFS=',' read -ra members_arr <<< "${members_field}"
        for member_id in "${members_arr[@]}"; do
            UCI_GROUP_MEMBERS["${member_id}"]=1
        done
    fi
done < <(tools_registry_ids)
echo "  ${#UCI_GROUP_MEMBERS[@]} id(s) excluidos por ser miembros de un agrupador"

echo ""
echo "== setup.js ofrece un script propio para cada herramienta del catálogo (agrupadores y herramientas independientes) =="
while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    if [[ -n "${UCI_GROUP_MEMBERS["${id}"]:-}" ]]; then
        continue
    fi

    script_field="$(tools_registry_field "${id}" "script")"
    script_basename="$(basename "${script_field}")"

    if grep -qF "${script_basename}" "${UCI_SETUP_JS}"; then
        pass "'${id}': '${script_basename}' está ofrecido en el menú de setup.js"
    else
        fail "'${id}': '${script_basename}' NO aparece en setup.js — el menú interactivo divergió del catálogo"
    fi
done < <(tools_registry_ids)

print_test_summary
exit_with_test_summary
