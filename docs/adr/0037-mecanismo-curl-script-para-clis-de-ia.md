# 0037. Mecanismo `curl-script` para las CLIs de IA del Hito 16

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

Las candidatas de IA clasificadas `required`/`optional` en el Hito 16 que son CLIs de desarrollo (Claude Code, Codex CLI, OpenCode, el CLI `agy` de Antigravity) y los agentes de propósito general (OpenClaw, Hermes Agent) comparten un mismo mecanismo de instalación oficial: un script remoto servido por el propio proveedor, ejecutado con `curl -fsSL <url> | bash` (o `sh`), que instala el binario típicamente en `~/.local/bin`. Ninguno de los mecanismos ya cubiertos por el catálogo (`apt`, `apt-vendor-repo`, `snap`, `mise`, `deb-direct`, `git-clone`) modela esto: no agregan un repositorio APT, no son paquetes de un gestor de paquetes de sistema, no pasan por Mise.

Claude Desktop (incluye Cowork) queda fuera de esta ADR: tiene un repositorio APT propio de Anthropic (`downloads.claude.ai/claude-desktop/apt/stable`), así que usa `manager=apt-vendor-repo` (mecanismo ya existente), no este nuevo.

## Decisión

Se agrega un mecanismo nuevo, `manager=curl-script`, con una biblioteca compartida `scripts/lib/curl_script.sh` (hermana de `apt.sh`/`snap.sh`/`apt_vendor_repo.sh`/`deb_direct.sh`/`git_clone.sh`):

- `curl_script_installed <binario>`: `command -v` para el chequeo de `status`.
- `curl_script_run <url> <bash|sh>`: descarga el script a un archivo temporal y lo ejecuta con el intérprete indicado, en vez de un pipe directo (`curl | bash`) — funcionalmente equivalente para instaladores no interactivos, pero permite mockear `curl` en las pruebas sin invocar un intérprete real contra una URL falsa.
- `curl_script_uninstall_local_bin <home_dir> <binario>`: remueve el binario de `~/.local/bin/<binario>` si existe — es la única ruta de desinstalación documentada, ya que ninguno de estos proyectos publica un `uninstall` oficial propio. Es una limitación honesta, no una desinstalación completa garantizada por el proveedor (por ejemplo, Hermes Agent bundlea dependencias adicionales como `uv`/Python/Node que este mecanismo no rastrea ni remueve).
- `status` no distingue `OUTDATED`/`BROKEN`: no hay forma barata de consultar la versión remota más reciente sin depender de la API específica de cada proveedor, y ninguno de estos scripts documenta un concepto de "instalación parcial" detectable sin ambigüedad.
- `repair` no se implementa: el dispatcher lo rechaza explícitamente (código 3), mismo criterio que Snap/Mise para este tipo de limitación.
- `reinstall` usa el fallback mecánico del dispatcher (desinstalar + instalar), ya que el script oficial de instalación ya es idempotente por diseño en todos los casos investigados.

## Consecuencias

- Antigravity se implementa **solo en su CLI (`agy`)** vía este mecanismo, registrado en `category=development`/`subcategory=ai-cli` — su IDE/Desktop queda explícitamente diferido: no tiene apt/snap oficial, solo un tarball manual sin checksum/firma descripta, lo que no cumple el estándar de seguridad del proyecto (`AGENT.md` §16). Se retoma cuando exista un mecanismo verificable.
- OpenClaw requiere Node.js 22.22.3+/24.15+/25.9+ para correr — este instalador no lo instala por su cuenta (no es su responsabilidad gestionar dependencias de runtime del proyecto instalado, ver criterio ya aplicado a otros instaladores de este catálogo); si Node no está disponible, el script oficial de OpenClaw es responsable de fallar con su propio mensaje.
- Pruebas: contrato mockeado (intercepta `curl` con un script falso en PATH temporal), mismo criterio que los mocks de `apt-get`/`snap` ya usados en el resto del catálogo — no se agregan pruebas funcionales reales contra los dominios oficiales de estos proveedores en esta ronda (a diferencia de kubectl/Yarn/gh vía Mise, o WezTerm vía su repo APT), dado que son servicios externos nuevos para este proyecto sin historial de estabilidad verificado en CI.
- Relacionado: [ADR 0036](0036-candidatas-de-ia-en-categorias-existentes.md) (categorías/subcategorías de estas herramientas), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md) (registro central sin esquema forzado).
