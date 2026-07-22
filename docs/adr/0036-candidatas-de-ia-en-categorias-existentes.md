# 0036. Distribuir las candidatas de IA del Hito 16 en categorías existentes, no una `ai-tools` nueva

Fecha: 2026-07-20
Estado: Reemplazada por [0043](0043-consolidar-herramientas-de-ia-en-category-ai.md)

## Contexto

[ADR 0035](0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md) reservó `category=ai-tools` (con subcategorías `ai-cli`/`ai-desktop`) para cuando se implementen las 7 candidatas de IA del Hito 16, agrupándolas por ser "herramientas de IA" sin distinguir su función real.

Al revisarlas una por una, el dueño del proyecto notó que esa agrupación mezclaría cosas muy distintas en los mismos términos que ADR 0035 acababa de corregir para `category=system`: **Antigravity** (Google) tiene un componente IDE propio — un editor de código real, igual en naturaleza a Cursor (ya en `EDITORS`) —, mientras que **Claude Code**, **Codex CLI** y **OpenCode** son CLIs que se usan dentro de un flujo de desarrollo (terminal, dentro de un repo), más parecidas a `gh`/`kubectl` (ya en `DEVELOPMENT`) que a una categoría separada. **Claude Desktop** (incluye Cowork), **OpenClaw** y **Hermes Agent**, en cambio, son agentes/apps de propósito general (chat, memoria persistente, espacio de trabajo), no herramientas de codificación en sí.

## Decisión

No se crea `category=ai-tools`. Cuando se implementen, las 7 candidatas se registran en las categorías ya existentes, según su función real:

- **`category=editors`**: Antigravity (su componente IDE/Desktop).
- **`category=development`, `subcategory=ai-cli`**: Claude Code, Codex CLI, OpenCode, y el CLI `agy` de Antigravity si se implementa como instalador separado de su IDE.
- **`category=productivity`, `subcategory=ai-agent`**: Claude Desktop (incluye Cowork), OpenClaw, Hermes Agent.

Esto es consistente con el criterio ya aplicado en ADR 0035 para el resto del catálogo: agrupar por función real (mecanismo/propósito), no por el origen o la etiqueta de marketing de la herramienta ("es de IA" no es, por sí sola, una categoría de menú útil).

## Consecuencias

- `docs/ROADMAP.md` (Hito 16) y `docs/TOOLS.md` (sección "Candidatas de IA") se actualizan para reflejar esta distribución en vez de la reserva de `category=ai-tools`.
- Ningún instalador de estas 7 candidatas existe todavía; este cambio es puramente de planificación, no toca `tools_catalog.sh` ni `setup.js`.
- Si Antigravity se implementa con un único instalador que cubre CLI + IDE (en vez de dos separados), queda en `category=editors` directamente — la subdivisión CLI/IDE de esta ADR es una guía para cuando se decida el mecanismo real de instalación, no una obligación de separarlo en dos scripts.
- Relacionado: [ADR 0035](0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md) (corrige parcialmente, solo en cuanto a la categoría reservada para las candidatas de IA — el resto de esa ADR sigue vigente sin cambios).
