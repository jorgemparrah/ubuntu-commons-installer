# 0008. Modo estricto de Bash en scripts nuevos y migrados

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Los scripts actuales usan `#!/bin/bash` sin establecer modo estricto de forma consistente, lo que oculta errores silenciosos (variables sin definir, comandos que fallan sin detener el pipeline, etc.).

Fuente: ASSESSMENT.md, HI-05. Ver también AGENT.md sección 12.

## Decisión

Todo script nuevo, y todo script existente al ser migrado o reescrito, usa:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Se adopta `-E` si más adelante se introducen traps de error compartidos. Los scripts existentes se migran de forma incremental — no se fuerza el modo estricto de golpe en todo el árbol, porque puede exponer suposiciones ocultas que rompan instaladores en producción.

## Consecuencias

- Cada vez que se toca un script legacy, corresponde subirlo a este estándar como parte del cambio.
- No bloquea el trabajo de bootstrap/backup/migraciones, que se escriben desde el inicio con este estándar.
