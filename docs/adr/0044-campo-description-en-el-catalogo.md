# 0044. Agregar campo `description` al esquema del catálogo

Fecha: 2026-07-22
Estado: Aceptada

## Contexto

El catálogo (`scripts/lib/tools_catalog.sh`) hoy solo expone `name` como texto legible por humanos — un nombre corto, no siempre suficiente para que alguien reconozca qué hace una herramienta antes de instalarla (p. ej. "SoapUI", "OnlyOffice", "ngrok", "zoxide" no son autoexplicativos para todo el mundo). El dueño del proyecto pidió poder revisar una descripción de cada app antes de instalarla, tanto en el menú interactivo (`setup.js`) como en los comandos de consulta (`setup.sh list`/`info`).

## Decisión

Se agrega un campo nuevo, `description=<texto corto>`, al esquema recomendado del catálogo (mismo mecanismo sin esquema forzado que el resto de los campos, ver [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md)) — una frase de una línea, en español, que explica qué es/hace la herramienta (no repite el nombre, no es marketing).

Alcance de la migración:

- **Retroactivo**: las 74 entradas existentes del catálogo necesitan su `description` agregada — es un trabajo de una sola pasada, no incremental, y se registra como su propio Hito (ver Hito 41 en `docs/ROADMAP.md`) en vez de hacerse "de paso" en cualquier PR que toque el catálogo.
- **Hacia adelante**: todo instalador nuevo que se registre desde este ADR en adelante (incluidos los Hitos 31-40) debe incluir `description` desde su primer commit — no queda como deuda a resolver después.
- **Visibilidad**: se muestra en `setup.sh list`/`setup.sh info` (agrega una columna) y en el menú interactivo de `setup.js` (visible al navegar/seleccionar cada opción del checklist).

## Consecuencias

- `scripts/lib/tools_catalog.sh`: 74 entradas existentes ganan `description=...` (Hito 41); todas las entradas nuevas de los Hitos 31-40 en adelante la incluyen desde el inicio.
- `setup.sh list`/`info` (`scripts/lib/*` que los implementan, ver ADR sobre Hito 13): agregan una columna `DESCRIPCIÓN`.
- `setup.js`: el checklist interactivo (usa `inquirer`) muestra la descripción de cada opción — investigar el mecanismo concreto (`choice.name` multilínea vs. algún plugin de `inquirer` para "hint"/detalle expandible) como parte de la implementación del Hito 41, no se prescribe aquí.
- No cambia el comportamiento de ningún instalador ni del dispatcher — es puramente un campo de metadata adicional, igual en naturaleza a `name`/`category`.
