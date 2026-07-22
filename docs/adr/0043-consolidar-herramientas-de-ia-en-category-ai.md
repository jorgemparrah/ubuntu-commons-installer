# 0043. Consolidar las herramientas de IA en una `category=ai` propia

Fecha: 2026-07-22
Estado: Aceptada

## Contexto

[ADR 0036](0036-candidatas-de-ia-en-categorias-existentes.md) distribuyó las candidatas de IA del Hito 16 en las categorías ya existentes según su función real (`development`/`subcategory=ai-cli`, `editors`/`subcategory=ai-ide`, `productivity`/`subcategory=ai-agent`), y `subcategory=ai-runtime` (Ollama, Hito 28) se agregó después con el mismo criterio dentro de `development`.

Con el catálogo creciendo (74 herramientas y una lista de ~50 más ya planificadas en `docs/ROADMAP.md`, Hitos 31-40), el dueño del proyecto pidió explícitamente revisar la categorización completa. Al hacerlo, decidió que el criterio de ADR 0036 — spread por función real dentro de categorías generalistas — ya no refleja cómo quiere navegar el catálogo: la IA es hoy un dominio con suficiente volumen e identidad propia (asistentes de escritorio, CLIs, IDEs y modelos locales) como para tener su propia categoría de primer nivel, en vez de quedar repartida entre `development`/`editors`/`productivity`.

## Decisión

Se crea `category=ai`, con 4 subcategorías:

- **`subcategory=ai-assistants`** (antes `productivity`/`ai-agent`): Claude Desktop, OpenClaw, Hermes Agent.
- **`subcategory=ai-cli`** (antes `development`/`ai-cli`, mismo nombre de subcategoría): Claude Code, Codex CLI, OpenCode, Antigravity CLI (`agy`).
- **`subcategory=ai-ide`** (antes `editors`/`ai-ide`, mismo nombre de subcategoría): Cursor AI IDE, Antigravity IDE.
- **`subcategory=local-models`** (antes `development`/`ai-runtime`): Ollama.

El campo `profiles` de cada herramienta no cambia: es un dato ya calculado y guardado (no se recalcula en tiempo de ejecución, ver `docs/ARCHITECTURE.md` §20), así que mover `category`/`subcategory` no afecta qué perfiles instalan qué. El perfil `ai-cli` (que filtra por `subcategory=ai-cli`) sigue funcionando igual, ya que ese nombre de subcategoría no cambió.

Esto reemplaza el criterio de ADR 0036 (agrupar por función real dentro de categorías generalistas) específicamente para el dominio de IA — el resto del criterio de ADR 0035/0036 (agrupar por función real, no por etiqueta de marketing) sigue vigente para todo lo que no sea IA.

## Consecuencias

- `scripts/lib/tools_catalog.sh`: 9 entradas cambian de `category`/`subcategory` (`antigravity`, `claude_code`, `codex_cli`, `opencode`, `ollama`, `cursor`, `antigravity_ide`, `claude_desktop`, `openclaw`, `hermes_agent` — 10 en total).
- `setup.js`: las opciones de menú de estas 10 herramientas se mueven de las secciones DEVELOPMENT/EDITORS/PRODUCTIVITY a una sección nueva AI.
- `docs/TOOLS.md`: se agrega una sección `## AI` nueva; las filas correspondientes se mueven ahí desde Development/Editors/Productivity.
- Ningún instalador cambia de comportamiento — es puramente una reorganización de metadata de catálogo/menú, igual que ADR 0035.
