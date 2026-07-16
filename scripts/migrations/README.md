# scripts/migrations/

Migraciones versionadas del Hito 6 (ver `docs/ROADMAP.md` y
[ADR 0006](../../docs/adr/0006-framework-de-migraciones-versionado.md)).

## Convención de nombres

```
NNN_slug_descriptivo.sh
```

`NNN` es un prefijo numérico de 3 dígitos que define el orden de ejecución (`001`, `002`, ...). El prefijo `000` está reservado para el ejemplo de referencia (`000_example_noop.sh`); nunca lo reutilices para una migración real.

## Contrato

Cada migración es un script ejecutable (`chmod +x`) que responde a estas acciones como primer argumento:

| Acción | Efecto | Debe ser de solo lectura |
|---|---|---|
| `describe` | Imprime una descripción de una línea | Sí |
| `check` | `exit 0` si la migración aplica y falta ejecutarla; `exit != 0` si no aplica (nada que hacer — **no es un error**) | Sí |
| `dry-run` | Imprime qué haría, sin modificar nada | Sí |
| `apply` | Aplica la migración de verdad | No |
| `validate` | `exit 0` si el resultado quedó como se esperaba | Sí |
| `rollback-notes` | Imprime notas legibles de cómo revertir manualmente | Sí |

El motor (`scripts/lib/migrations.sh`) invoca cada acción como un proceso separado (`"${path}" <acción>`), nunca hace `source` de las migraciones — así que cada migración es responsable de su propio `set -Eeuo pipefail` (ver [ADR 0008](../../docs/adr/0008-bash-estricto-en-scripts-nuevos.md)) y de leer `UCI_HOME_DIR` del entorno (exportada por `setup.sh`, con `${HOME}` como default si se ejecuta la migración de forma standalone).

## Ciclo de vida

1. `setup.sh migrate --list` — muestra cada migración descubierta, con su estado (`pendiente`/`hecha`) según exista o no su marca de finalización.
2. `setup.sh migrate --dry-run` — para cada migración pendiente y aplicable, corre `describe` + `check` + `dry-run`. Nunca escribe una marca de finalización.
3. `setup.sh migrate` — aplica cada migración pendiente y aplicable en orden: `apply`, y si tuvo éxito, `validate`. Solo si ambas pasan se escribe la marca de finalización en `${home_dir}/.local/state/ubuntu-workstation/migrations/<id>.done`. Si `apply` o `validate` fallan, la ejecución se detiene ahí (no sigue con la siguiente migración) y se muestran las notas de rollback.

Una migración ya marcada como hecha nunca se reaplica automáticamente (ejecución repetible). Si necesitas forzar que se vuelva a correr, elimina manualmente su archivo `.done` — no hay todavía un comando para eso (ver preguntas abiertas / trabajo futuro).

## Ejemplo de referencia

`000_example_noop.sh` no modifica ninguna configuración real: solo escribe un archivo informativo dentro de su propio directorio de estado, para poder probar el framework de punta a punta sin riesgo. Úsalo como plantilla para escribir nuevas migraciones.
