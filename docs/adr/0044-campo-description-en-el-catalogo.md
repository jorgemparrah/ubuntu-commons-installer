# 0044. Agregar campo `description` al esquema del catálogo

Fecha: 2026-07-22
Estado: Aceptada
Actualizada: 2026-07-23 (implementación real, ver Consecuencias)

## Contexto

El catálogo (`scripts/lib/tools_catalog.sh`) hoy solo expone `name` como texto legible por humanos — un nombre corto, no siempre suficiente para que alguien reconozca qué hace una herramienta antes de instalarla (p. ej. "SoapUI", "OnlyOffice", "ngrok", "zoxide" no son autoexplicativos para todo el mundo). El dueño del proyecto pidió poder revisar una descripción de cada app antes de instalarla, tanto en el menú interactivo (`setup.js`) como en los comandos de consulta (`setup.sh list`/`info`).

## Decisión

Se agrega un campo nuevo, `description=<texto corto>`, al esquema recomendado del catálogo (mismo mecanismo sin esquema forzado que el resto de los campos, ver [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md)) — una frase de una línea, en español, que explica qué es/hace la herramienta (no repite el nombre, no es marketing).

Alcance de la migración:

- **Retroactivo**: las 74 entradas existentes del catálogo necesitan su `description` agregada — es un trabajo de una sola pasada, no incremental, y se registra como su propio Hito (ver Hito 41 en `docs/ROADMAP.md`) en vez de hacerse "de paso" en cualquier PR que toque el catálogo.
- **Hacia adelante**: todo instalador nuevo que se registre desde este ADR en adelante (incluidos los Hitos 31-40) debe incluir `description` desde su primer commit — no queda como deuda a resolver después.
- **Visibilidad**: se muestra en `setup.sh list`/`setup.sh info` (agrega una columna) y en el menú interactivo de `setup.js` (visible al navegar/seleccionar cada opción del checklist).

## Consecuencias

- **Implementación real (2026-07-23)**: en la práctica, los Hitos 31-40 (26 herramientas nuevas) se implementaron sin `description` pese a lo planeado en esta ADR — quedó como deuda hasta este Hito 41, que terminó agregando el campo a las **100 entradas** del catálogo en una sola pasada (las 74 originales + las 26 de los Hitos 31-40), en vez de a 74 nomás. Resultado más simple de verificar (una sola pasada consistente) que el plan incremental original.
- `scripts/lib/tools_catalog.sh`: 100 entradas con `description=...`, insertado siempre inmediatamente después de `name=...` en cada registro.
- `setup.sh list`/`info` (`catalog_list_run` en `setup.sh`): agrega una columna `DESCRIPCIÓN` al final de la tabla (después de `PERFILES`), tanto con `show_status=0` (list) como `show_status=1` (info).
- `setup.js`: **duplicado manual** — el array `tools` ya era una copia de metadata mantenida a mano en paralelo a `tools_catalog.sh` (mismo patrón ya existente para `name`/`script`/`category`, sin mecanismo de sincronización automática entre Bash y JS); se le agregó un campo `description` por entrada con el mismo texto. El checklist interactivo (`inquirer`, tipo `checkbox`) no tiene un panel de detalle/hint nativo sin agregar una dependencia nueva — se optó por mostrar la descripción inline en la etiqueta de cada opción (`${icon} ${tool.name} (${text}) — ${tool.description}`), sin agregar paquetes nuevos.
- No cambia el comportamiento de ningún instalador ni del dispatcher — es puramente un campo de metadata adicional, igual en naturaleza a `name`/`category`.
