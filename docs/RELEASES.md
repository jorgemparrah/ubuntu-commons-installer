# RELEASES.md

## Historial de hitos entregados

El proyecto no usa versionado semántico ni tags de Git todavía (no hay releases empaquetadas para instalar — el "release" de este proyecto es el estado de `main` en un momento dado). Este documento registra, en su lugar, el cierre de cada hito de `docs/ROADMAP.md`, que es la unidad real de entrega del proyecto.

Este documento no existía hasta el cierre técnico de 2026-07-18 (`docs/TECHNICAL_REVIEW.md`, hallazgo A7), pese a que ya había 9 hitos `Done`/`Review` — se completa retroactivamente acá. Las fechas de los hitos 1-8 son aproximadas, reconstruidas a partir de las fechas de las ADRs asociadas a cada uno (no se registró la fecha de cierre exacta de cada hito en su momento); desde el Hito 9 en adelante las fechas ya quedan registradas de forma precisa en `docs/ROADMAP.md`.

| Hito | Nombre | Estado | Cierre (aprox.) | Decisiones clave |
|---|---|---|---|---|
| 1 | Evaluación del repositorio | Done | 2026-07-15 | Diagnóstico inicial; base para [ADR 0001](adr/0001-bootstrap-bash-sin-node.md), [0009](adr/0009-postergar-arquitectura-de-plugins.md), [0011](adr/0011-alcance-diferido-para-el-primer-hito.md) |
| 2 | Bootstrap | Done | 2026-07-15 | Bootstrap en Bash puro, sin depender de Node ([ADR 0001](adr/0001-bootstrap-bash-sin-node.md)) |
| 3 | Idempotencia del menú y modelo de estado enriquecido | Done | 2026-07-15 | `INSTALLED→skip` por defecto ([ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md)); modelo de estado `INSTALLED/NOT_INSTALLED/OUTDATED/BROKEN/UNSUPPORTED/UNKNOWN` ([ADR 0012](adr/0012-modelo-de-estado-enriquecido.md)) |
| 4 | Doctor | Done | 2026-07-15 | Diagnóstico de solo lectura (`scripts/diagnostics/doctor.sh`) |
| 5 | Gestor de Backups | Done | 2026-07-15 | Backups centralizados con timestamp, nunca se sobrescriben ni se borran silenciosamente ([ADR 0005](adr/0005-gestor-de-backups-centralizado.md)) |
| 6 | Framework de migraciones | Done | 2026-07-15 | Migraciones versionadas con contrato `describe/check/dry-run/apply/validate/rollback-notes` ([ADR 0006](adr/0006-framework-de-migraciones-versionado.md)) |
| 7 | Migración NVM → Mise | Done | 2026-07-15/16 | Primera migración real (001), mover en vez de borrar ([ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md)); ver `docs/MIGRATIONS.md` |
| 8 | Gestor de runtimes | Done | 2026-07-16 | Mise como único gestor de runtimes para todo el proyecto, no solo Node ([ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md), [0025](adr/0025-metodo-instalacion-oficial-de-mise.md)) |
| 9 | Compatibilidad con Ubuntu 26 | Review | 2026-07-18 | Auditoría completa de 30 instaladores; matriz de evidencia por versión (`docs/UBUNTU_COMPATIBILITY.md`); [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md), [0028](adr/0028-arquitectura-soportada-amd64.md), [0029](adr/0029-contrato-completo-de-instalador-referencia.md). Quedan dos validaciones manuales pendientes (Snap en Ubuntu 26.04 Desktop real, kernel HWE en VM) antes de poder marcarse `Done` |
| 10 | Gate de calidad automatizado (CI) | Done | 2026-07-17 | CI en GitHub Actions adelantado antes del Hito 9 ([ADR 0026](adr/0026-adelantar-hito-10-ci-antes-que-hito-9.md)); cache de capas Docker agregado en el cierre técnico de 2026-07-18 |

Hitos 11 en adelante siguen `Blocked`/pendientes — ver `docs/ROADMAP.md` para el detalle y las dependencias entre ellos.

## Revisión técnica integral (no es un hito, pero es un hito de calidad del proyecto)

**2026-07-18** — `docs/TECHNICAL_REVIEW.md`: primera revisión técnica de todo el repositorio (estilo Staff Engineer), con hallazgos priorizados Crítico/Alto/Medio/Bajo. Los hallazgos Crítico y Alto se corrigieron el mismo día (ver commits de la rama `correcciones-criticas-altas-revision-tecnica`); Medio/Bajo quedan como backlog documentado, sin fecha comprometida.
