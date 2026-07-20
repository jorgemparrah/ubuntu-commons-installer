#!/usr/bin/env bash
# tests/test_tools_registry.sh
#
# Pruebas no destructivas de scripts/lib/tools_registry.sh (el mecanismo)
# y scripts/lib/tools_catalog.sh (los datos registrados, ver
# docs/adr/0030-registro-central-de-metadata-de-instaladores.md y
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md).
# La validación cruzada recorre TODAS las entradas registradas (incluidos
# los 14 instaladores individuales y 3 agrupadores de ADR 0031), no una
# lista fija. No instala nada real ni modifica ningún archivo.
#
# Uso:
#   bash tests/test_tools_registry.sh
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
TOOLS_REGISTRY_SH="${UCI_REPO_ROOT}/scripts/lib/tools_registry.sh"
readonly TOOLS_REGISTRY_SH
TOOLS_CATALOG_SH="${UCI_REPO_ROOT}/scripts/lib/tools_catalog.sh"
readonly TOOLS_CATALOG_SH

# shellcheck source=lib/assertions.sh
source "${UCI_TEST_DIR}/lib/assertions.sh"

echo "== Mecanismo: tools_registry.sh (entradas de prueba, sin datos reales) =="
# shellcheck source=../scripts/lib/tools_registry.sh
source "${TOOLS_REGISTRY_SH}"

tools_registry_register "demo-tool" "name=Demo Tool" "category=demo" "manager=apt"

if tools_registry_has "demo-tool"; then
    pass "tools_registry_has reporta verdadero para un id recién registrado"
else
    fail "tools_registry_has debería reportar verdadero para 'demo-tool'"
fi

if ! tools_registry_has "no-existe"; then
    pass "tools_registry_has reporta falso para un id nunca registrado"
else
    fail "tools_registry_has no debería reportar verdadero para un id inexistente"
fi

if [[ "$(tools_registry_field "demo-tool" "name")" == "Demo Tool" ]]; then
    pass "tools_registry_field devuelve el valor correcto de un campo registrado"
else
    fail "tools_registry_field no devolvió el valor esperado para 'name'"
fi

if [[ -z "$(tools_registry_field "demo-tool" "campo-inexistente")" ]]; then
    pass "tools_registry_field devuelve vacío (no falla) para un campo no declarado"
else
    fail "tools_registry_field debería devolver vacío para un campo no declarado"
fi

if [[ "$(tools_registry_ids)" == *"demo-tool"* ]]; then
    pass "tools_registry_ids incluye los ids registrados"
else
    fail "tools_registry_ids no incluyó 'demo-tool'"
fi

echo ""
echo "== Volver a registrar el mismo id no lo duplica en tools_registry_ids =="
tools_registry_register "demo-tool" "name=Demo Tool (actualizado)"
DEMO_COUNT="$(tools_registry_ids | grep -c '^demo-tool$')"
if [[ "${DEMO_COUNT}" -eq 1 ]]; then
    pass "un id ya registrado no se duplica al volver a registrarlo"
else
    fail "'demo-tool' aparece ${DEMO_COUNT} veces en tools_registry_ids, debería ser 1"
fi
if [[ "$(tools_registry_field "demo-tool" "name")" == "Demo Tool (actualizado)" ]]; then
    pass "volver a registrar un id sobrescribe sus campos"
else
    fail "el campo 'name' no se actualizó al volver a registrar 'demo-tool'"
fi

echo ""
echo "== Datos: tools_catalog.sh registra cmatrix y ranger =="
# shellcheck source=../scripts/lib/tools_catalog.sh
source "${TOOLS_CATALOG_SH}"

for id in cmatrix ranger; do
    if tools_registry_has "${id}"; then
        pass "'${id}' está registrado en el catálogo"
    else
        fail "'${id}' debería estar registrado en el catálogo"
    fi
done

echo ""
echo "== Validación cruzada: TODA entrada del catálogo coincide con el archivo real =="
# Recorre tools_registry_ids() en vez de una lista fija: cualquier entrada
# que se agregue a tools_catalog.sh a futuro queda validada automáticamente
# sin tocar este test (ver ADR 0030/0031).
while IFS= read -r id; do
    [[ -z "${id}" || "${id}" == "demo-tool" ]] && continue

    script_field="$(tools_registry_field "${id}" "script")"
    script_path="${UCI_REPO_ROOT}/${script_field}"

    if [[ -f "${script_path}" ]]; then
        pass "'${id}': el script declarado ('${script_field}') existe en el repositorio"
    else
        fail "'${id}': el script declarado ('${script_field}') no existe"
    fi

    kind_field="$(tools_registry_field "${id}" "kind")"
    manager_field="$(tools_registry_field "${id}" "manager")"
    migration_field="$(tools_registry_field "${id}" "migration_status")"
    # 'usa scripts/lib/apt.sh' es un rasgo de migration_status=migrated, no
    # de manager=apt en sí: install_vim.sh es manager=apt pero
    # migration_status=legacy (implementa los 6 verbos desde antes del
    # Hito 11, con su propia lógica de dpkg — ver docs/ARCHITECTURE.md §15)
    # y nunca sourceó apt.sh a propósito.
    if [[ "${manager_field}" == "apt" && "${kind_field}" != "group" && "${migration_field}" == "migrated" ]]; then
        if grep -q "lib/apt\.sh" "${script_path}" 2>/dev/null; then
            pass "'${id}': declara manager=apt+migrated y el script sourcea scripts/lib/apt.sh"
        else
            fail "'${id}': declara manager=apt+migrated pero el script no sourcea scripts/lib/apt.sh"
        fi
    fi
    if [[ "${migration_field}" == "migrated" ]]; then
        if grep -q "installer_run_cli" "${script_path}" 2>/dev/null; then
            pass "'${id}': declara migration_status=migrated y el script usa installer_run_cli"
        else
            fail "'${id}': declara migration_status=migrated pero el script no usa installer_run_cli"
        fi
    fi

    if [[ "${kind_field}" == "group" ]]; then
        members_field="$(tools_registry_field "${id}" "members")"
        if [[ -z "${members_field}" ]]; then
            fail "'${id}': es kind=group pero no declara 'members'"
        else
            IFS=',' read -ra members_arr <<< "${members_field}"
            all_members_exist=1
            for member_id in "${members_arr[@]}"; do
                tools_registry_has "${member_id}" || all_members_exist=0
            done
            if [[ "${all_members_exist}" -eq 1 ]]; then
                pass "'${id}': todos sus 'members' (${members_field}) están registrados en el catálogo"
            else
                fail "'${id}': al menos un id en 'members' (${members_field}) no está registrado"
            fi
        fi
    fi
done < <(tools_registry_ids)

print_test_summary
exit_with_test_summary
