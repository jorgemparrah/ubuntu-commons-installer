# 0029. `install_vim.sh` es el contrato de referencia; el Hito 11 migra el resto hacia él

Fecha: 2026-07-18
Estado: Aceptada

## Contexto

ADR 0004 decidió que el modelo de acciones por defecto fuera `NOT_INSTALLED→install`, `INSTALLED→skip`, `OUTDATED→update`, `BROKEN→repair`, con `reinstall` como acción avanzada explícita — y aceptó explícitamente que los instaladores individuales fueran incorporando `update`/`repair` "de forma incremental, sin exigirlo a todos desde el día uno".

Una revisión técnica integral del proyecto (`docs/TECHNICAL_REVIEW.md`, hallazgo Crítico C1) encontró que, dos años de hitos después, esa incorporación incremental nunca avanzó más allá del piloto: de los ~30 instaladores del repositorio, **solo `install_vim.sh`** implementa el contrato completo (`status|install|uninstall|reinstall|update|repair`, con `check_status` distinguiendo `OUTDATED`/`BROKEN` de `INSTALLED`/`NOT_INSTALLED`). Los otros ~29 implementan únicamente `status|install|uninstall|reinstall`.

Esto dejó una ambigüedad real: `docs/ROADMAP.md` (objetivo del Hito 11) y `AGENT.md` §9 describen el contrato objetivo citando `status/install/update/repair` sin mencionar `uninstall`/`reinstall` con la misma prioridad, mientras que el código convergió de hecho hacia `uninstall`/`reinstall` como los verbos realmente usados en todas partes. Nadie había decidido formalmente si el rumbo correcto era consolidar el modelo de 4 verbos ya extendido, o completar la migración hacia el modelo de 6 verbos que ADR 0004/0012 ya habían aprobado y que `install_vim.sh` ya demuestra que funciona.

## Decisión

Se confirma la dirección original de ADR 0004 y ADR 0012, sin reemplazarlas: **el contrato objetivo para todo instalador es el que ya implementa `scripts/editors/install_vim.sh`**:

```
status | install | uninstall | reinstall | update | repair
```

- `install_vim.sh` queda designado explícitamente como **instalador de referencia** a copiar (no solo un ejemplo entre otros) para cualquier instalador que se modernice.
- El Hito 11 ("Modernización de instaladores") mantiene su alcance original: migrar los ~29 instaladores restantes hacia este contrato completo, incluyendo que `check_status()` distinga `OUTDATED`/`BROKEN` cuando el mecanismo de instalación lo permita (por ejemplo, vía `apt list --upgradable` para paquetes de `apt`).
- `AGENT.md` §9 y `docs/ARCHITECTURE.md` se corrigen para citar los 6 verbos completos (incluyendo `uninstall` y `reinstall` explícitamente, no solo `update`/`repair`), en vez de una lista parcial que no refleja ni el código real ni el objetivo aprobado.
- No se exige a los instaladores existentes implementar `update`/`repair` fuera del Hito 11 — mientras tanto, el comportamiento actual (rechazar esos subcomandos con código de salida ≠0 y un mensaje de uso claro) sigue siendo válido, tal como ya lo anticipaba ADR 0004.

## Consecuencias

- El objetivo del Hito 11 en `docs/ROADMAP.md` se reformula para referenciar explícitamente esta ADR y a `install_vim.sh` como plantilla, en vez de una lista de verbos ambigua.
- `AGENT.md` §9 y `docs/ARCHITECTURE.md` §21 dejan de citar un contrato de 4 verbos parcial; citan los 6 verbos completos.
- Cuando el Hito 11 migre un instalador, ese cambio debe incluir a la vez el modo estricto de Bash exigido por [ADR 0008](0008-bash-estricto-en-scripts-nuevos.md) — ambas migraciones tocan el mismo archivo, conviene hacerlas juntas.
- No se reemplaza ni se contradice ADR 0004 ni ADR 0012: esta ADR solo cierra la ambigüedad sobre qué instalador es la referencia y confirma que la migración sigue siendo el objetivo, no una alternativa descartada.
