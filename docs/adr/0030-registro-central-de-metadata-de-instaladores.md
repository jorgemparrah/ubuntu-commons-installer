# 0030. Registro central de metadata de instaladores (catálogo Bash, sin YAML/JSON)

Fecha: 2026-07-19
Estado: Aceptada

## Contexto

Con el Hito 11 en marcha (Fase 1: infraestructura compartida; Fase 2: 3 instaladores apt-simples migrados), una auditoría de los 30 instaladores existentes (ver `docs/TECHNICAL_REVIEW.md`, hallazgo M6, y el trabajo previo a esta ADR) encontró que los mismos hechos sobre cada herramienta (categoría, mecanismo de instalación, arquitecturas soportadas, si requiere validación manual, si requiere entorno gráfico, estado de migración) viven hoy dispersos y mantenidos a mano en **cinco lugares que ya divergen entre sí**: `docs/TOOLS.md`, `docs/UBUNTU_COMPATIBILITY.md`, `docs/TEST_CASES.md`, la prosa de `docs/ROADMAP.md`, y el array `tools` de `setup.js`. Ningún instalador declara esta metadata de forma estructurada; solo existe como variables sueltas (`TOOL_NAME`, `PACKAGE_NAME`/`SNAP_PACKAGE`) sin esquema común.

Antes de migrar 20-30 instaladores más, esta divergencia se agravaría: cada migración nueva tendría que actualizar a mano los mismos 5 lugares, con el mismo riesgo de drift que [ADR 0009](0009-postergar-arquitectura-de-plugins.md) ya aceptó como riesgo conocido a corto plazo.

Esto es una decisión de arquitectura distinta a la que diferió [ADR 0009](0009-postergar-arquitectura-de-plugins.md): esa ADR postergó una **arquitectura de plugins** (descubrimiento dinámico de instaladores, `metadata.yaml` por herramienta, sin registro central). Esta ADR propone únicamente un **catálogo de metadata de solo lectura**, aditivo, que no descubre nada dinámicamente ni reemplaza el array de `setup.js` — un paso mucho más chico y acotado, que no contradice ni reemplaza la postergación de ADR 0009.

## Decisión

Se crea `scripts/lib/tools_registry.sh`, un catálogo de metadata **en Bash puro**, con el mismo patrón ya aceptado en `UCI_RUNTIME_CATALOG` (`scripts/lib/runtime.sh`, Hito 8): un array de identificadores más un array asociativo de pares `"id:campo" -> valor`, poblado por una función `tools_registry_register <id> campo=valor...`.

**No se usa YAML/JSON.** Un formato de archivo separado exigiría un parser (`yq`/`jq`), una dependencia externa no garantizada en la máquina del usuario, en contra de `AGENT.md` sección 23 ("nunca introducir dependencias innecesarias"). El catálogo Bash no depende de nada fuera del propio proyecto.

**Campos mínimos por herramienta:** `name`, `category`, `manager` (`apt`/`apt-vendor-repo`/`snap`/`mise`/`deb-direct`/`git-clone`), `packages` (lista separada por comas — casi siempre un elemento, pero soporta honestamente los 3 instaladores multi-paquete existentes sin forzar una ficción 1:1), `script` (ruta relativa al instalador responsable), `supported_os`, `supported_arch`, `requires_gui`, `requires_manual_validation`, `migration_status` (`legacy`/`migrated` — si usa `scripts/lib/installer_cli.sh`/`scripts/lib/apt.sh`).

**Alcance de esta fase — puramente aditivo e incremental:**

- El registro no se sourcea desde `setup.sh` ni `setup.js`; no reemplaza el array `tools` existente.
- No modifica el comportamiento de ningún instalador, del dispatcher (`installer_cli.sh`) ni de los helpers APT (`apt.sh`).
- Solo se registran 2 instaladores ya migrados (`cmatrix`, `ranger`) como validación del diseño, no como migración completa.
- Una prueba (`tests/test_tools_registry.sh`) valida cada entrada registrada contra el archivo real (existe el script; si `manager=apt`, el script sourcea `scripts/lib/apt.sh`), para que el catálogo no pueda mentir en silencio sobre el código real.

## Consecuencias

- Migraciones futuras del Hito 11 pueden registrar cada instalador migrado con una sola llamada a `tools_registry_register`, en vez de actualizar 5 documentos a mano — sin que esto sea obligatorio todavía (el registro es opcional mientras no se decida consumirlo desde algún lugar real).
- Consumir este catálogo para generar o validar `docs/TOOLS.md`/`docs/UBUNTU_COMPATIBILITY.md`/el menú de `setup.js` es trabajo futuro explícitamente fuera de esta ADR — requeriría su propia decisión cuando haya suficientes instaladores registrados para que valga la pena.
- Si más adelante se decide reemplazar el array de `setup.js` por este catálogo, o introducir descubrimiento dinámico de instaladores, corresponde revisar [ADR 0009](0009-postergar-arquitectura-de-plugins.md) explícitamente — esta ADR no la reemplaza.
- Relacionado: [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato de 6 verbos), [ADR 0009](0009-postergar-arquitectura-de-plugins.md) (arquitectura de plugins postergada).
