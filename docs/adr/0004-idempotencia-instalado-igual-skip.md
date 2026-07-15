# 0004. Una herramienta instalada se omite por defecto, no se reinstala

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El menú interactivo mapea hoy `INSTALLED → reinstall` y `NOT_INSTALLED → install`. Esto significa que seleccionar una herramienta ya instalada dispara su desinstalación y reinstalación, aunque esté sana. La ejecución no es convergente: correr el instalador dos veces no produce el mismo resultado sin efectos secundarios.

Fuente: ASSESSMENT.md, CR-03 y ME-02 (`reinstall` como respuesta universal ante una instalación existente, en vez de exponer `update`/`repair`).

## Decisión

El modelo de acciones por defecto pasa a ser:

```
NOT_INSTALLED → install
INSTALLED     → skip
OUTDATED      → update
BROKEN        → repair
```

`reinstall` sigue existiendo, pero solo como acción avanzada explícita, nunca como comportamiento por defecto.

## Consecuencias

- El menú interactivo debe distinguir "instalado y sano" de "instalado pero desactualizado/roto" (ver [0012](0012-modelo-de-estado-enriquecido.md), modelo de estado más rico).
- Los instaladores individuales deben ir incorporando `update`/`repair` de forma incremental, sin exigirlo a todos desde el día uno. Las acciones no soportadas por un instalador legacy deben devolver un código y mensaje consistentes en vez de fallar de forma confusa.
