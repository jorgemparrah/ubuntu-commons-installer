# 0040. Cerrar el Hito 14 (Arquitectura de plugins) vía `tools_catalog.sh`, sin reescribir instaladores

Fecha: 2026-07-21
Estado: Aceptada

## Contexto

[ADR 0009](0009-postergar-arquitectura-de-plugins.md) postergó una arquitectura de plugins/metadata declarativa para resolver un problema concreto: el nombre, categoría y ruta de script de cada herramienta se declaraban manualmente en `setup.js`, mientras cada instalador definía su propia identidad por separado — agregar un script exigía editar dos lugares, y renombrar uno podía romper el otro sin avisar. La estructura futura que esa ADR imaginaba como posible solución era un directorio por herramienta (`scripts/installers/docker/metadata.json` + `installer.sh`).

Ese problema de fondo (metadata duplicada, sin una fuente única de verdad) ya se resolvió por una vía distinta a la que ADR 0009 imaginó: `scripts/lib/tools_catalog.sh` (Hito 11, [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md)) centraliza nombre, categoría, subcategoría, clasificación, mecanismo, ruta de script, sistemas operativos soportados, perfiles y más para las 53 herramientas del catálogo, con 3 consumidores automatizados (`tests/test_tools_catalog_docs_consistency.sh` I19, `tests/test_tools_catalog_setup_js_consistency.sh` I21, `tests/test_tools_catalog_ubuntu_compatibility_consistency.sh` I24) que impiden que `docs/TOOLS.md`, `setup.js` y `docs/UBUNTU_COMPATIBILITY.md` diverjan del catálogo.

El objetivo *literal* del Hito 14 ("convertir los instaladores en plugins descubribles", un directorio por herramienta con `metadata.yaml` + `install.sh`/`update.sh`/`repair.sh`/`status.sh` separados) implicaría reescribir los 53 instaladores existentes, que hoy son un único script por herramienta con el contrato de 6 verbos vía `scripts/lib/installer_cli.sh` (Hito 11, [ADR 0029](0029-contrato-completo-de-instalador-referencia.md)). Esa reescritura no resolvería ningún problema que no esté ya resuelto por `tools_catalog.sh`, y contradice el principio de "cambios pequeños, evitar reescrituras grandes" del proyecto (`AGENT.md`, sección 2).

## Decisión

Se cierra el Hito 14 como cumplido, reinterpretando su objetivo (metadata centralizada y descubrible para los instaladores, sin duplicación) como ya alcanzado por `tools_catalog.sh` en el Hito 11 — no por la estructura de directorios que ADR 0009 había imaginado como posible solución. No se reescribe ningún instalador existente: los 53 siguen siendo un único script por herramienta, con el dispatcher compartido de `installer_cli.sh`.

"Descubrible" ya se cumple hoy sin directorios separados: `tools_registry_ids()`/`tools_registry_field()` permiten recorrer y consultar cualquier herramienta registrada mecánicamente (usado, por ejemplo, por `doctor_check_executables` del Hito 12 y por `profile_installer_run` del Hito 13) — la "arquitectura de plugins" que buscaba el Hito 14 ya existe en la práctica, con una forma distinta a la originalmente prevista.

## Consecuencias

- `docs/ROADMAP.md` (Hito 14) se actualiza: pasa de `Blocked` a `Done`, documentando esta reinterpretación sin describir un trabajo pendiente que ya no aplica.
- [ADR 0009](0009-postergar-arquitectura-de-plugins.md) no se reemplaza formalmente (su decisión de postergar en su momento fue correcta); esta ADR documenta cómo se resolvió el problema de fondo que esa ADR había identificado, por una vía distinta a la que proponía como posible estructura futura.
- Si en el futuro surge una necesidad real no cubierta por `tools_catalog.sh` (por ejemplo, plugins de terceros fuera de este repositorio), correspondería una ADR nueva evaluando esa necesidad puntual — no reabrir este hito tal como estaba planteado.
- Relacionado: [ADR 0009](0009-postergar-arquitectura-de-plugins.md), [ADR 0029](0029-contrato-completo-de-instalador-referencia.md), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md).
