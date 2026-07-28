# 0046. Mecanismos para las interfaces locales de IA del Hito 53: `pip-mise` y `appimage-direct`

Fecha: 2026-07-28
Estado: Aceptada

## Contexto

El Hito 53 (ver `docs/ROADMAP.md`) incorpora tres interfaces locales de IA. Ninguna se distribuye como paquete del sistema, y cada una lo resuelve distinto:

- **AnythingLLM**: publica un `installer.sh` oficial en GitHub Releases que instala un AppImage y crea su `.desktop`. Encaja tal cual en el mecanismo ya existente `curl-script` ([ADR 0037](0037-mecanismo-curl-script-para-clis-de-ia.md)), mismo caso que Joplin. **No requiere mecanismo nuevo.** (De paso: el objetivo del Hito asumía que publicaba un `.deb`; confirmado en vivo contra la API de GitHub que **no** — solo AppImage, `.dmg`, `.exe` y el `installer.sh`.)
- **Open WebUI**: es un servicio web local (dashboard en `localhost:8080`), no una aplicación instalable. Sus métodos oficiales son `pip install open-webui` y Docker.
- **LM Studio**: aplicación de escritorio, gratuita pero de **código cerrado**. Se distribuye únicamente como AppImage crudo desde una URL estable de "última versión", sin script de instalación oficial.

### Por qué Open WebUI no puede usar el Python del sistema

Los metadatos reales del paquete en PyPI declaran `requires_python: >=3.11,<3.13.0a1` (confirmado en vivo contra la API de PyPI). Contrastado con las dos versiones de Ubuntu que este proyecto soporta:

- Ubuntu 24.04 trae Python 3.12.3 → **cumple**.
- Ubuntu 26.04 traerá Python 3.13+ → **no cumple**.

Un `pip install` contra el intérprete del sistema funcionaría hoy en 24.04 y se rompería en 26.04. Como el proyecto ya usa **Mise como único gestor de runtimes** ([ADR 0002](0002-mise-como-unico-gestor-runtime.md)) y `scripts/lib/runtime.sh` ya contempla Python en su catálogo de runtimes, fijar el intérprete con Mise da un comportamiento idéntico en ambas versiones. Esta observación es del dueño del proyecto.

Se evaluó y descartó la alternativa de Docker (el método que el propio proyecto más promociona): introduciría el concepto de **gestionar un servicio de larga duración** (contenedor con `--restart always`), algo que este catálogo nunca hizo — hasta ahora instala software, no administra servicios. Decisión explícita del dueño del proyecto.

### Licencia de Open WebUI

El objetivo del Hito pedía "confirmar que la cláusula de marca no restringe el uso local". Leída la licencia real: es una BSD-3-Clause con una cláusula 4 adicional que prohíbe **alterar, remover u ocultar el branding "Open WebUI"**, con excepción explícita para despliegues de hasta 50 usuarios finales. No restringe de ninguna forma el uso local de la herramienta tal cual viene. **Corrección al objetivo**: ya no es MIT — GitHub la clasifica como `NOASSERTION` y el propio repositorio la llama "Open WebUI License".

### Licencia de LM Studio

Gratuito pero de código cerrado. Su inclusión fue **consultada y aprobada explícitamente por el dueño del proyecto**, con el precedente ya establecido de otras herramientas no-FOSS del catálogo (Obsidian, Discord, Slack, Steam, Terraform, Vagrant).

## Decisión

Se agregan dos mecanismos nuevos, cada uno con **un solo caso real** por ahora.

Siguiendo el criterio de [ADR 0032](0032-mecanismo-condicional-por-version-de-ubuntu.md) —esperar un segundo caso real antes de abstraer— **ninguno extrae una biblioteca compartida en `scripts/lib/`**: la lógica vive dentro de su propio instalador. Esto los diferencia de `flatpak` ([ADR 0045](0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md)), que nació con dos casos y sí justificó la biblioteca desde el inicio. Es el mismo tratamiento que ya recibieron `izpack-installer` (SoapUI) y `aws-cli-installer` (AWS CLI).

### `manager=pip-mise` (Open WebUI)

Paquete de Python instalado con `pip` sobre un intérprete **fijado por Mise**, no el del sistema. Reutiliza `scripts/lib/runtime.sh` sin modificarlo:

- `install`: `runtime_ensure_mise` → `runtime_install <home> python 3.11` → `mise exec python@3.11 -- pip install --upgrade <paquete>` → `mise reshim` (para que el ejecutable de consola quede accesible).
- Se fija **3.11**, la versión que la documentación oficial recomienda explícitamente, dentro del rango que declara PyPI.
- `status`: `UNKNOWN` si Mise no está disponible (mismo criterio que Snap/Flatpak: distinguir "no puedo saberlo" de "no está instalado"); `INSTALLED`/`NOT_INSTALLED` según `pip show`.
- No distingue `OUTDATED`: requeriría consultar PyPI por red, violando que `status` sea liviano y local (mismo criterio que Snap/Flatpak). `update` existe igual como verbo explícito.
- `repair` no se implementa; el dispatcher lo rechaza con código 3.
- **El instalador no arranca ni gestiona el servicio.** Deja disponible el comando `open-webui serve` y lo informa. Coherente con el límite que este catálogo se puso: instala software, no administra servicios de larga duración.

### `manager=appimage-direct` (LM Studio)

AppImage descargado de una URL estable de "última versión" del proveedor, sin script oficial de por medio:

- La URL no lleva versión (`lmstudio.ai/download/latest/linux/x64?format=AppImage`, confirmada en vivo: responde 200 y redirige al `.AppImage` versionado), igual que el endpoint estable de Discord o el `.zip` de AWS CLI — no hace falta resolver la versión contra una API.
- El AppImage se instala en `~/.local/share/<app>/`, se marca ejecutable y se crea un `.desktop` en `~/.local/share/applications/` — sin esto quedaría un archivo suelto sin integración con el escritorio, el mismo motivo por el que se rechazó el instalador oficial de Kitty (Hito 40).
- Instala `libfuse2` vía APT: los AppImage lo requieren y Ubuntu 24.04+ ya no lo trae por defecto. Precedente de gestionar una dependencia de sistema dentro del instalador: `apt_vendor_repo_ensure_gnupg`, `flatpak_ensure_flathub`.
- `status`: `INSTALLED` si el AppImage existe y es ejecutable; `BROKEN` si existe pero no es ejecutable; `NOT_INSTALLED` si falta. No distingue `OUTDATED` (la URL estable no expone la versión sin descargar).
- `update`: vuelve a descargar desde la URL estable. `repair`: rehace permisos y `.desktop`.

## Consecuencias

- **Dos mecanismos nuevos con un caso cada uno.** Si aparece un segundo caso real de cualquiera de los dos, corresponde extraer `scripts/lib/pip_mise.sh` / `scripts/lib/appimage_direct.sh`, igual que se hizo con `flatpak.sh`. Hasta entonces, duplicar sería abstraer sin evidencia.
- **Open WebUI arrastra una instalación de Python vía Mise** (~100 MB) aunque el usuario no use Python para nada más. Es el costo de tener un comportamiento estable en las dos versiones de Ubuntu; la alternativa (Python del sistema) se rompe en 26.04.
- **`requires_manual_validation=yes` para las tres.** Ninguna se valida funcionalmente en los contenedores de CI: Open WebUI requiere descargar un runtime completo de Python y un paquete pesado; LM Studio y AnythingLLM son AppImages GUI que necesitan FUSE y un escritorio real. La cobertura automatizada son contratos mockeados.
- **LM Studio queda documentado como código cerrado** en `docs/TOOLS.md` y en el catálogo, para que la excepción sea visible y no se descubra por accidente.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md) (Mise como único gestor de runtimes), [ADR 0032](0032-mecanismo-condicional-por-version-de-ubuntu.md) (esperar un segundo caso antes de abstraer), [ADR 0037](0037-mecanismo-curl-script-para-clis-de-ia.md) (AnythingLLM reutiliza este mecanismo), [ADR 0045](0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md) (precedente de mecanismo nuevo con biblioteca compartida).
