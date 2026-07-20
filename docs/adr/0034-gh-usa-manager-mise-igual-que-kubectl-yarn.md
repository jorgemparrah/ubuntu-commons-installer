# 0034. `gh` usa `manager=mise`, igual que kubectl y Yarn (corrige 0033)

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

[ADR 0033](0033-mise-amplia-su-rol-a-clis-via-registry.md) propuso un valor nuevo, `manager=mise-tool`, para distinguir en `tools_catalog.sh` una CLI instalada vía Mise (sin política de versiones propia, instala `latest`) de un runtime de lenguaje instalado vía Mise (con política de versiones, ver [ADR 0016](0016-politica-de-versiones-node-mise.md)).

Al implementar `install_gh.sh` se confirmó que ese caso ya existe en el catálogo y ya está resuelto sin un valor nuevo: `kubectl` ([ADR 0018](0018-kubectl-via-mise.md)) y Yarn ([ADR 0017](0017-mise-instala-yarn-pnpm-directo.md)) son exactamente el mismo caso — CLIs sin política de versiones propia, instaladas vía Mise con `latest` — y ambos usan `manager=mise` en `tools_catalog.sh`, sin distinción respecto a los runtimes de lenguaje. La ADR 0033 se escribió sin conocer ese precedente y habría introducido dos valores (`mise` y `mise-tool`) para el mismo mecanismo real, una inconsistencia sin beneficio: el campo `manager` no se valida contra una lista cerrada en ningún consumidor del catálogo (`docs/TOOLS.md`, `setup.js`, `docs/UBUNTU_COMPATIBILITY.md`), así que no hay necesidad técnica de diferenciarlos, y la distinción "con/sin política de versiones" ya es visible mirando si el instalador aplica `docs/adr/0016` o no, no por el valor de `manager`.

## Decisión

- No se introduce `manager=mise-tool`. `gh` se registra en `tools_catalog.sh` con `manager=mise`, igual que `kubectl` y Yarn.
- El resto de la ADR 0033 (Mise amplía su rol más allá de runtimes, puede usarse como mecanismo de instalación para CLIs vía su registry cuando la herramienta está disponible ahí, evaluado caso por caso, sin reemplazar la jerarquía de fuentes de `AGENT.md` §15 para el resto del catálogo) sigue vigente — esta ADR corrige únicamente el nombre del valor de `manager`, no la decisión de fondo.
- `docs/TOOLS.md` y `docs/ROADMAP.md` se actualizan para reflejar `manager=mise` en vez de `manager=mise-tool` en las menciones a `gh`.

## Consecuencias

- Un solo valor de `manager` (`mise`) cubre tanto runtimes de lenguaje como CLIs sin política de versiones propia instaladas vía Mise; la diferencia entre ambos casos se documenta en el propio instalador y en `docs/TOOLS.md`, no en el catálogo.
- Herramientas candidatas futuras que se evalúen para Mise (por ejemplo, algunas de las CLIs de IA del Hito 16) se registran también con `manager=mise` si se decide ese mecanismo, sin necesidad de un tercer valor.
- [ADR 0033](0033-mise-amplia-su-rol-a-clis-via-registry.md) queda marcada como reemplazada por esta ADR únicamente en cuanto al nombre del valor de `manager`; su decisión de fondo (ampliar el rol de Mise) no se revierte.
- Relacionado: [ADR 0033](0033-mise-amplia-su-rol-a-clis-via-registry.md), [ADR 0018](0018-kubectl-via-mise.md), [ADR 0017](0017-mise-instala-yarn-pnpm-directo.md), [ADR 0002](0002-mise-como-unico-gestor-runtime.md).
