# 0033. Mise amplía su rol: de "solo runtimes" a también gestionar CLIs vía su registry

Fecha: 2026-07-20
Estado: Reemplazada parcialmente por 0034 (solo en cuanto al valor de `manager` para `gh`; la decisión de fondo de esta ADR sigue vigente, ver [0034](0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md))

## Contexto

Al investigar el mecanismo de instalación oficial de `gh` (GitHub CLI) para agregarlo al catálogo, se confirmó que:

- `gh` está en los repositorios oficiales de Ubuntu (`universe`, 24.04 y 26.04), lo que bajo la jerarquía de fuentes vigente (`AGENT.md` §15, [ADR 0027](0027-orden-de-fuentes-por-categoria.md)) lo pondría directamente en `apt`.
- `gh` también está disponible en el registry de Mise (`mise registry gh` → `aqua:cli/cli`, `asdf:bartlomiejdanek/asdf-github-cli`).

`AGENT.md` §8 y `docs/ARCHITECTURE.md` §10 dicen hoy que "Mise es el único gestor de runtimes soportado" y listan Node.js/Python/Java/Go/Rust como los runtimes a gestionar — sin mencionar CLIs de herramientas que no son lenguajes. Migrar `gh` a Mise tal cual esas reglas están escritas contradiría el alcance documentado.

El dueño del proyecto pidió explícitamente ampliar el rol de Mise más allá de runtimes, para poder usarlo también como mecanismo de instalación de CLIs (aprovechando que Mise ya expone backends de terceros como `aqua`, `asdf` y `ubi` para binarios que no son runtimes de lenguaje).

## Decisión

Se amplía el rol de Mise en este proyecto:

- Mise sigue siendo el **único gestor de runtimes** soportado (Node.js, Python, Java, Go, Rust) — [ADR 0002](0002-mise-como-unico-gestor-runtime.md) no se reemplaza, se extiende.
- Además, Mise pasa a ser un **mecanismo de instalación válido para CLIs de herramientas** (no solo runtimes de lenguaje) cuando la herramienta está disponible en el registry de Mise (`mise registry <nombre>`), usando cualquiera de sus backends (`aqua`, `asdf`, `ubi`, etc.).
- Este mecanismo se registra en `tools_catalog.sh` con el mismo `manager=mise` que ya usan `kubectl` y Yarn — **corrección** (ver [ADR 0034](0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md)): esta ADR proponía originalmente un valor nuevo, `manager=mise-tool`, para distinguirlo de los runtimes de lenguaje, pero `kubectl`/Yarn ya resuelven exactamente este caso (CLI sin política de versiones propia, instala `latest`) con `manager=mise` sin esa distinción, así que no se introduce un valor nuevo.
- **`gh` es el primer caso**: se instala vía Mise (`mise use -g gh@latest` o equivalente), no vía apt, aun cuando también está en los repositorios oficiales de Ubuntu — decisión explícita del dueño del proyecto, no una consecuencia automática de la jerarquía de fuentes de `AGENT.md` §15 (esa jerarquía sigue rigiendo para paquetes que no pasan por Mise).
- Esto **no** cambia la jerarquía general de fuentes (`apt` > proveedor > instalador oficial > snap > flatpak) para el resto de las herramientas del catálogo — Mise-para-CLIs es una vía adicional, evaluada caso por caso, no un reemplazo de esa jerarquía.

## Consecuencias

- `AGENT.md` §8 y `docs/ARCHITECTURE.md` §10 se actualizan con una nota breve que remite a esta ADR, para que un colaborador nuevo no interprete "único gestor de runtimes" como excluyente de este uso adicional.
- Falta definir, al implementar `install_gh.sh`, si se necesita un helper compartido nuevo (`scripts/lib/mise_tool.sh`, hermano de `scripts/lib/runtime.sh`) o si alcanza con reutilizar funciones existentes de `runtime.sh` — se decide en la fase de implementación, no en esta ADR.
- Herramientas candidatas futuras que aparezcan en el registry de Mise (por ejemplo, algunas de las CLIs de IA evaluadas en el Hito 12) pueden evaluarse contra este mecanismo antes de asumir automáticamente apt/deb-directo/script oficial.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md), [ADR 0027](0027-orden-de-fuentes-por-categoria.md).
