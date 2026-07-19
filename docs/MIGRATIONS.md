# MIGRATIONS.md

## Migraciones versionadas ya ejecutadas

Registro de migraciones de `scripts/migrations/` que ya se dieron por completadas en el proyecto (ver `AGENT.md` §5). El mecanismo, contrato y ciclo de vida de una migración viven en `scripts/migrations/README.md` y en [ADR 0006](adr/0006-framework-de-migraciones-versionado.md); este documento es el historial de cuáles ya corrieron, para qué población de usuarios aplican, y qué decisiones de alcance tomaron.

Este documento no existía hasta el cierre técnico de 2026-07-18 (`docs/TECHNICAL_REVIEW.md`, hallazgo A7), pese a que la migración 001 ya estaba `Done` desde el Hito 7 — se completa retroactivamente acá.

---

### 001 — NVM → Mise

**Script:** `scripts/migrations/001_nvm_to_mise.sh`

**Hito:** 7 (Migración NVM → Mise), `Done`.

**A quién aplica:** cualquier `/home` reutilizado que tenga NVM instalado (una o más versiones de Node) al adoptar este proyecto. No aplica (se omite en `check`) a una workstation nueva sin NVM previo.

**Qué hace:**

1. Detecta las versiones de Node instaladas vía NVM y el alias por defecto.
2. Respalda la configuración de shell (`.bashrc`/`.zshrc`/`.profile`) y el propio directorio `~/.nvm` antes de tocar nada (ver [ADR 0005](adr/0005-gestor-de-backups-centralizado.md), gestor de backups centralizado).
3. Instala Mise si no está presente (método oficial, `https://mise.run`, ver [ADR 0025](adr/0025-metodo-instalacion-oficial-de-mise.md)).
4. Instala vía Mise las versiones de Node detectadas — preservando lo que ya existía, sin aplicar la política de versiones por defecto del proyecto (ver [ADR 0024](adr/0024-alcance-migracion-nvm-a-mise.md), alcance de la migración).
5. Mueve `~/.nvm` al backup (no lo borra en el lugar) y quita las referencias a NVM de los archivos de shell, dentro de bloques gestionados y reversibles (ver [ADR 0007](adr/0007-bloques-gestionados-en-archivos-de-shell.md)).
6. Deja un sentinel de finalización (`.001_nvm_to_mise.apply-completado`) distinto de la marca oficial `.done`, para poder distinguir "el movimiento de datos ya ocurrió, falta validar" de "toda la migración está completa" — ver `docs/TESTING.md`, sección de fallos parciales (M07).

**Decisiones de arquitectura relacionadas:** [ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md) (Mise como único gestor de runtimes), [ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md) (mover en vez de borrar), [ADR 0024](adr/0024-alcance-migracion-nvm-a-mise.md), [ADR 0025](adr/0025-metodo-instalacion-oficial-de-mise.md).

**Evidencia:** cobertura funcional completa dentro de contenedores Docker desechables — casos M01-M08 en `docs/TEST_CASES.md`, incluida inyección de fallos en 5 checkpoints distintos (`tests/docker/test_nvm_to_mise_fault_injection.sh`) y 3 escenarios de home reutilizado (NVM+1 versión, NVM+2 versiones con alias no-más-reciente, Mise ya preinstalado). Nunca se ejecutó ni se ejecutará contra un `$HOME` real de una máquina de desarrollo (ver `docs/TESTING.md`).

**Reversión manual:** `scripts/migrations/001_nvm_to_mise.sh rollback-notes` imprime las notas de rollback (restaurar `~/.nvm` y los archivos de shell desde la sesión de backup correspondiente). No hay un comando de rollback automático — es intencional, ver `scripts/migrations/README.md`.
