# 0035. Eliminar los agrupadores delgados de ADR 0031 y recategorizar el catálogo

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

[ADR 0031](0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md) separó 3 instaladores que bandeaban varios paquetes no relacionados (`install_development_tools.sh`, `install_multimedia.sh`, `install_system_utils.sh`) en 14 instaladores individuales, pero conservó los 3 archivos originales como **agrupadores delgados** que delegan en sus miembros, únicamente para no romper las 3 opciones de menú de `setup.js` que ya existían.

Al revisar el catálogo completo (`scripts/lib/tools_catalog.sh`, 49 entradas) para mejorar su categorización — la categoría `category=system` había crecido de forma ad-hoc, agregando cada herramienta nueva a medida que se registraba, sin una estrategia de agrupación deliberada, hasta concentrar 26 de las 49 entradas (más de la mitad) mezclando utilidades CLI de sistema, terminales, gestores de archivos de terminal, personalización de shell, apps GUI, acciones de mantenimiento y los 3 agrupadores — el dueño del proyecto pidió explícitamente que los agrupadores dejen de existir como tales: cada instalador individual se expone directamente en el menú y se reclasifica según su propósito real, en vez de mantener una capa de compatibilidad de menú que ya no aporta nada (los 14 instaladores individuales llevan desde el Hito 11 implementando el contrato completo de 6 verbos por sí mismos).

## Decisión

- Se eliminan `scripts/system/install_development_tools.sh`, `scripts/system/install_multimedia.sh` y `scripts/system/install_system_utils.sh`, junto con sus registros en `tools_catalog.sh` (`development_tools_group`, `multimedia_group`, `system_utils_group`, todos `kind=group`) y sus 3 entradas en el menú de `setup.js`.
- Los 14 instaladores individuales que ya existían (creados por ADR 0031, sin cambios en su lógica) pasan a exponerse **directamente** en el menú de `setup.js` — antes solo estaban registrados en el catálogo pero ocultos detrás de su agrupador.
- Se elimina `tests/test_system_utils_contract.sh` (probaba la delegación de los 3 agrupadores hacia sus miembros): sin agrupadores, esa delegación no existe. El ciclo de vida de los 14 instaladores individuales ya está cubierto por `tests/test_split_installers_contract.sh` (I18) — no se pierde cobertura real, solo la prueba de un mecanismo que se retira.
- `tests/test_tools_catalog_setup_js_consistency.sh` (I21) no necesita cambios de código: ya excluye de su chequeo únicamente a los ids marcados `kind=group`; al no quedar ninguno, automáticamente exige que los 14 individuales tengan entrada propia en `setup.js` — es decir, valida exactamente el estado nuevo sin modificaciones.
- Se agrega un campo no-esquemático nuevo, `subcategory`, a `tools_catalog.sh` (mismo mecanismo sin esquema forzado de ADR 0030) para subdividir `category=system` sin tocar la estructura de menú de `setup.js` (que sigue usando solo `category`):
  - `subcategory=cli-utils`: wget, curl, Git, GnuPG, build-essential, software-properties-common, apt-transport-https (los 7 ex miembros de Development Tools).
  - `subcategory=terminals`: Terminator, Ghostty, WezTerm, Ranger, nnn, lf, Yazi.
  - `subcategory=shell-personalization`: Oh My Zsh, Powerlevel10k.
  - `subcategory=gui-utils`: Meld, Baobab, GParted (ex miembros de System Utilities), GIMP, OBS Studio.
  - `subcategory=misc`: cmatrix (única entrada que no encaja en ninguna de las anteriores).
  - Los 4 ex miembros de Multimedia Tools (Cheese, v4l-utils, ubuntu-restricted-extras, VLC) no necesitan subcategoría: ya vivían correctamente en `category=multimedia`, no en `system`.
- Se corrige una inconsistencia menor detectada de paso: `install_system_update.sh` e `install_kernel.sh` tenían `category=system` pese a ser `kind=maintenance`, mientras que `install_final_update.sh` (mismo `kind=maintenance`) ya tenía `category=maintenance`. Los 3 quedan con `category=maintenance` para ser consistentes entre sí.
- Se reserva `category=ai-tools` (con subcategorías `ai-cli`/`ai-desktop`) para cuando se implementen las 7 candidatas de IA del Hito 16 — no se registra nada nuevo en el catálogo todavía, ya que ningún instalador de esas candidatas existe aún.

## Consecuencias

- `docs/TOOLS.md` se reorganiza: se elimina la fila de los 3 agrupadores (los scripts ya no existen), se reestructura la sección `## System` en subsecciones por subcategoría, y `install_system_update.sh`/`install_kernel.sh` pasan a la sección `## Maintenance`.
- `docs/TEST_CASES.md`: los casos I01-I04 (probaban los 3 agrupadores) se marcan retirados en vez de eliminarse silenciosamente — quedan documentados como parte de la historia del proyecto, con referencia a esta ADR.
- `docs/ARCHITECTURE.md` y `docs/ROADMAP.md` conservan su narrativa histórica del Hito 11 (2026-07-19, cuando se crearon los agrupadores) sin reescribirla, y agregan una nota fechada (2026-07-20) señalando la reversión y remitiendo a esta ADR — nunca se reescribe la historia, se agrega sobre ella.
- No se elimina ninguna funcionalidad real: los 14 instaladores individuales siguen instalando exactamente los mismos paquetes con el mismo mecanismo; el único cambio de comportamiento visible es que ahora aparecen como opciones de menú propias en vez de agrupadas bajo "Development Tools"/"Multimedia Tools"/"System Utilities".
- Relacionado: [ADR 0031](0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md) (reemplazada parcialmente por esta ADR, solo en cuanto a mantener agrupadores delgados — la decisión de separar en instaladores individuales sigue vigente), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md) (registro central sin esquema forzado).
