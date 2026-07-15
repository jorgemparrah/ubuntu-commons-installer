# 0011. Alcance explícitamente diferido para los primeros hitos

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Durante la evaluación inicial del repositorio surgieron varias ideas de arquitectura que son razonables a futuro, pero que aumentarían el riesgo y distraerían del objetivo inmediato: una reinstalación segura de Ubuntu con `/home` retenido.

Fuente: ASSESSMENT.md, sección 14 ("Decisions That Should Be Deferred").

## Decisión

No se implementan en los primeros hitos:

- una arquitectura de plugins completa (ver [0009](0009-postergar-arquitectura-de-plugins.md));
- instalación dirigida por YAML para cada herramienta;
- reemplazar la interfaz interactiva de Node.js;
- renombrar el repositorio (el nombre interno sí cambia, ver docs/ARCHITECTURE.md y AGENT.md — el repo Git se mantiene igual);
- mover todos los scripts existentes de una sola vez;
- soportar múltiples distribuciones Linux;
- borrado automático de backups de migración;
- restauración automática de todos los paquetes globales de NVM;
- un framework grande de gestión de dotfiles;
- aprovisionamiento remoto de workstations.

## Consecuencias

- Cualquier propuesta que caiga en esta lista requiere una nueva ADR que reemplace explícitamente a esta antes de implementarse.
- Esta lista se revisa junto con ROADMAP.md a medida que avanzan las etapas; no es permanente, es el alcance del primer tramo de trabajo.
