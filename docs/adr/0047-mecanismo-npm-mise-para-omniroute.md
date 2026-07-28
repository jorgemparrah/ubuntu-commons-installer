# 0047. Mecanismo `npm-mise` para OmniRoute, y subcategoría `ai-gateway`

Fecha: 2026-07-28
Estado: Aceptada

## Contexto

El Hito 56 (ver `docs/ROADMAP.md`) incorpora **OmniRoute** (`diegosouzapw/OmniRoute`, MIT): un gateway de IA que expone un endpoint local compatible con OpenAI y enruta las peticiones hacia muchos proveedores, con fallback por cuota, caché, compresión de tokens y observabilidad. Se ejecuta como servicio local: dashboard en `http://localhost:20128` y API en `/v1`.

Sus métodos de instalación documentados son, en orden de prominencia: `npm install -g omniroute`, imagen Docker multi-arch oficial, instalación desde fuente y AUR.

### Corrección al objetivo del Hito: no es un gateway "de LLM locales"

El objetivo lo describía como "gateway de IA local" y proponía, como una de las opciones, reutilizar la subcategoría `local-models` (la de Ollama). Verificado en vivo, la descripción es imprecisa en un punto que importa para clasificarlo: OmniRoute **no ejecuta inferencia local**. Enruta hacia 290+ proveedores, en su mayoría remotos (Claude, GPT, Gemini, DeepSeek…). Lo único local es el **endpoint** que expone.

Agruparlo con Ollama, LM Studio, Open WebUI y AnythingLLM —que sí corren o sirven modelos en la máquina— confundiría dos cosas distintas: "corre modelos acá" y "enruta hacia modelos de terceros desde acá". Se adopta por eso la otra opción que el propio objetivo contemplaba: una subcategoría nueva **`ai-gateway`**.

### Por qué no el Node del sistema

Los metadatos reales del paquete en el registry de npm declaran:

```
engines: { node: ">=22.0.0 <23 || >=24.0.0 <27" }
```

Es decir: Node 22 o Node 24/25/26, y explícitamente **no** Node 23. Es la misma clase de problema que Open WebUI planteó con Python ([ADR 0046](0046-mecanismos-para-interfaces-locales-de-ia.md)): un rango de versiones que el intérprete del sistema no garantiza. Depender del Node de Ubuntu haría que el resultado dependiera de qué versión traiga cada release, un dato que además cambia entre 24.04 y 26.04.

Este proyecto ya usa **Mise como único gestor de runtimes** ([ADR 0002](0002-mise-como-unico-gestor-runtime.md)), `scripts/lib/runtime.sh` ya contempla Node en su catálogo, y toda la política de versiones de Node del proyecto pasa por ahí ([ADR 0016](0016-politica-de-versiones-node-mise.md)). Fijar la versión con Mise es la opción coherente y determinista.

Se fija **Node 24**: es LTS vigente (Krypton, verificado en vivo contra `nodejs.org/dist/index.json`) y cae dentro del rango `>=24.0.0 <27`.

### Por qué no Docker

Se evaluó la imagen oficial multi-arch. Se descarta por el mismo motivo ya decidido para Open WebUI en ADR 0046: introduciría **gestionar un servicio de larga duración**, algo que este catálogo nunca hizo. El catálogo instala software; no administra servicios. Mantener el criterio también evita que dos herramientas casi gemelas (Open WebUI y OmniRoute, ambas dashboards locales) se instalen por vías distintas sin una razón de fondo.

### Verificaciones que el objetivo pedía

- **Sin sistema de facturación** — el README lo afirma y se verificó en vivo: *"OmniRoute has no billing system"*. Sin cobro propio; solo se paga a los proveedores directamente.
- **Sin telemetría** — *"Zero telemetry by default — your prompts go only to the providers you choose, nowhere else."* Cumple el estándar del proyecto.
- **Licencia** — MIT, confirmada tanto en los metadatos del repo como en el `package.json` publicado en npm.

## Decisión

### `manager=npm-mise` (OmniRoute)

Paquete npm global instalado sobre un **Node fijado por Mise**, nunca el del sistema:

1. `runtime_ensure_mise` — garantiza Mise.
2. `runtime_install "$HOME" node 24` — fija el runtime.
3. `npm install -g omniroute` ejecutado *a través* de ese Node (`mise exec node@24 -- npm ...`).
4. `mise reshim` — sin esto, el ejecutable del paquete global no queda expuesto en el PATH.

`status` devuelve **`UNKNOWN`** cuando Mise no está disponible, en vez de `NOT_INSTALLED`: sin Mise no se puede saber si el paquete está instalado, y afirmar "no instalado" sería inventar. Es el mismo criterio ya establecido para snap, flatpak y `pip-mise`.

El instalador **no arranca el servicio**: deja disponible el comando `omniroute` e informa que el dashboard se levanta con él. Igual que Open WebUI.

### Sin biblioteca compartida nueva

`npm-mise` es el **segundo** caso de la misma familia que `pip-mise`: el gestor de paquetes de un lenguaje corriendo sobre un runtime fijado por Mise. Según el criterio de [ADR 0032](0032-mecanismo-condicional-por-version-de-ubuntu.md), un segundo caso real es justamente lo que habilita abstraer — así que la pregunta se evaluó en serio y la respuesta es **no**, por lo siguiente:

La parte realmente común ya está abstraída: es `scripts/lib/runtime.sh`, que ambos instaladores usan sin modificar. Lo único que quedaría por extraer es el wrapper de una línea

```bash
runtime_cmd "${home}" exec "${runtime}@${version}" -- "${pkg_cmd}" "$@"
```

y a partir de ahí los dos casos divergen en todo lo demás: `pip show` vs `npm ls -g`, `pip uninstall -y` vs `npm uninstall -g`, `pip install --upgrade` vs `npm install -g` (que ya actualiza). Una biblioteca que envuelve una línea y no unifica ninguno de los verbos agrega indirección sin quitar duplicación. Se reevaluará si aparece un tercer caso o si los verbos empiezan a coincidir de verdad.

### Subcategoría nueva `ai-gateway`

Se agrega dentro de `category=ai`, distinta de `local-models`. Por ahora con un solo integrante; a diferencia de un mecanismo, una subcategoría es solo una etiqueta de agrupación en el menú y no implica código a mantener, así que no aplica el criterio de "esperar un segundo caso".

## Consecuencias

- El catálogo gana un mecanismo (`npm-mise`) y una subcategoría (`ai-gateway`).
- Queda un precedente claro para futuros paquetes npm globales: van sobre un Node de Mise con versión fijada, no sobre el del sistema.
- Instalar OmniRoute implica que Mise instale Node 24 si todavía no está, lo que puede tardar la primera vez. Es el mismo costo que ya acepta `pip-mise` con Python.
- Un paquete npm global vive dentro de la instalación de Node que lo instaló. Si en el futuro se cambia la versión fijada acá, habrá que reinstalar el paquete; por eso la versión se fija explícitamente en el instalador en vez de usar "la que haya".
- `uninstall` no elimina la configuración ni los datos de OmniRoute (claves de proveedores, base de datos local), coherente con AGENT.md §2 y §11.
