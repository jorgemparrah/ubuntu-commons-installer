# Ubuntu Workstation

> Nombre interno del proyecto: **Ubuntu Workstation**. El repositorio en GitHub mantiene su nombre histórico (`ubuntu-commons-installer`) — ver [ADR 0015](docs/adr/0015-idioma-de-la-documentacion.md) y [`AGENT.md`](AGENT.md).

Gestor del ciclo de vida de una workstation Ubuntu: aprovisiona herramientas de desarrollo, diagnostica el estado de la máquina, respalda configuración antes de tocarla, y migra estado histórico (por ejemplo, NVM) de forma segura.

**Documentación de referencia:**

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — diseño técnico
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — plan de evolución y estado de cada hito
- [`docs/TESTING.md`](docs/TESTING.md) — cómo probar el proyecto (incluye Docker para lo que instala/modifica de verdad)
- [`docs/TEST_CASES.md`](docs/TEST_CASES.md) — casos de prueba funcionales
- [`docs/TOOLS.md`](docs/TOOLS.md) — inventario de herramientas gestionadas
- [`docs/adr/`](docs/adr/README.md) — decisiones de arquitectura (ADRs)

## Uso

`setup.sh` es un **router de comandos**:

```bash
./setup.sh                    # flujo interactivo (comportamiento por defecto)
./setup.sh interactive        # lo mismo, de forma explícita
./setup.sh help                # ayuda; no requiere Node.js
./setup.sh --help              # igual que 'help'
./setup.sh version              # versión del proyecto; no requiere Node.js
./setup.sh doctor                # diagnóstico de solo lectura de la workstation
./setup.sh doctor --verbose       # diagnóstico con detalle adicional
./setup.sh backup                 # respalda la configuración conocida de shell/runtime
./setup.sh backup --dry-run        # muestra qué se respaldaría, sin crear nada
./setup.sh migrate --list           # lista las migraciones y su estado
./setup.sh migrate --dry-run         # muestra qué haría cada migración pendiente, sin aplicar nada
./setup.sh migrate                    # aplica las migraciones pendientes
./setup.sh runtime status              # qué runtimes gestiona Mise (Node/Python/Java/Go/Rust)
```

Un comando desconocido muestra un error y la ayuda, y termina con código de salida distinto de cero. `doctor` nunca modifica el sistema, solo reporta (ver `AGENT.md` sección 10 y [ADR 0001](docs/adr/0001-bootstrap-bash-sin-node.md)).

### Variables de entorno

```bash
UCI_DEBUG=1               # activa mensajes de depuración (log_debug)
UCI_HOME_DIR=<ruta>        # home a usar en vez de $HOME, para pruebas/simulación
```

`UCI_HOME_DIR` es la forma en que este proyecto se prueba a sí mismo sin arriesgar el `$HOME` real: apunta a una carpeta temporal para simular un home (por ejemplo `UCI_HOME_DIR="$(mktemp -d)" ./setup.sh doctor --verbose`). Ver [ADR 0023](docs/adr/0023-variable-uci-home-dir-para-pruebas.md).

### Idempotencia del menú interactivo

Una herramienta ya instalada **nunca se reinstala por defecto**. El mapeo de estado a acción es:

```
NOT_INSTALLED → install
INSTALLED     → skip
OUTDATED      → update
BROKEN        → repair
UNSUPPORTED   → skip
UNKNOWN       → skip
```

`reinstall` sigue existiendo, pero solo como acción explícita: si seleccionas una herramienta ya instalada, el menú pregunta específicamente si quieres forzar la reinstalación (por defecto, no). Ver [ADR 0004](docs/adr/0004-idempotencia-instalado-igual-skip.md) y [ADR 0012](docs/adr/0012-modelo-de-estado-enriquecido.md) (modelo de estado enriquecido: `INSTALLED`/`NOT_INSTALLED`/`OUTDATED`/`BROKEN`/`UNSUPPORTED`/`UNKNOWN`).

### Mise como único gestor de runtimes

Este proyecto usa **Mise** para gestionar runtimes (Node, Python, Java, Go, Rust) — ver [ADR 0002](docs/adr/0002-mise-como-unico-gestor-runtime.md). El flujo interactivo (`./setup.sh` sin argumentos) instala Mise con confirmación explícita si falta, y Node.js a través de Mise; **no instala NVM**.

`runtime status` es de solo lectura y reporta, para cada runtime soportado, si Mise lo tiene activo y con qué versión. La instalación/activación de cualquier runtime (usada también por la migración NVM→Mise) vive en `scripts/lib/runtime.sh`, la única forma en que el proyecto debe tocar Mise.

**NVM solo existe como estado histórico que puede migrarse.** Si tu máquina ya tiene NVM instalado (por ejemplo, de una instalación anterior con `/home` reutilizado), `./setup.sh migrate` lo detecta y lo reemplaza por Mise de forma segura: respalda la configuración de shell, limpia solo las líneas exactas y reconocidas que agregó el instalador de NVM (nunca un patrón amplio), reinstala cada versión de Node detectada vía Mise, y mueve `~/.nvm` a un backup — nunca lo borra directamente. Ver [ADR 0003](docs/adr/0003-migracion-nvm-sin-borrado-directo.md), [ADR 0007](docs/adr/0007-bloques-gestionados-en-archivos-de-shell.md) y [ADR 0024](docs/adr/0024-alcance-migracion-nvm-a-mise.md).

Esta migración instala software real, así que solo se prueba dentro de contenedores Docker desechables — ver `docs/TESTING.md` y `docs/TEST_CASES.md`.

### Backups

`backup` crea una sesión con timestamp en `${UCI_HOME_DIR:-$HOME}/.local/state/ubuntu-workstation/backups/SESSION_ID/`, con un `manifest.tsv` (origen, destino, tipo, fecha), y **nunca sobrescribe una sesión existente**. `backup_move_dir` (usado por las migraciones) solo elimina el origen si un manifiesto completo — rutas, tipos, permisos, tamaños, symlinks y hashes — coincide exactamente entre origen y destino; si no coincide, no borra nada y reporta la discrepancia. Ver [ADR 0005](docs/adr/0005-gestor-de-backups-centralizado.md).

### `/home` reutilizado

El proyecto asume que `/home` puede venir de una instalación anterior (runtimes, claves SSH, configuración de shell ya existentes). Ninguna acción destructiva ocurre sin un backup previo, y `doctor`/`--dry-run` permiten inspeccionar el estado antes de cambiar nada. Ver `AGENT.md` sección 7 y [ADR 0003](docs/adr/0003-migracion-nvm-sin-borrado-directo.md).

### Framework de migraciones

`migrate` descubre las migraciones en `scripts/migrations/*.sh` (contrato completo en `scripts/migrations/README.md`), nunca reaplica una ya marcada como hecha, y se detiene sin marcar finalización si una migración falla. Ver [ADR 0006](docs/adr/0006-framework-de-migraciones-versionado.md).

## Estructura del repositorio

```
.
├── setup.sh                    # Router de comandos (Bash)
├── setup.js                    # Interfaz interactiva (Node.js)
├── package.json                 # Dependencias de Node.js
├── AGENT.md                      # Lineamientos del proyecto
├── docs/                          # Documentación (ver arriba)
│   └── adr/                        # Decisiones de arquitectura
├── scripts/
│   ├── lib/                        # Bibliotecas compartidas (logging, backup, migrations)
│   ├── bootstrap/                   # Verificaciones de preflight
│   ├── diagnostics/                  # doctor
│   ├── migrations/                    # Migraciones versionadas
│   ├── system/                         # Instaladores: sistema
│   ├── editors/                         # Instaladores: editores de código
│   ├── development/                      # Instaladores: herramientas de desarrollo
│   ├── productivity/                      # Instaladores: productividad
│   └── maintenance/                        # Instaladores: mantenimiento
└── tests/
    ├── docker/                     # Imágenes y pruebas que instalan software real
    └── fixtures/                    # Datos de prueba (home de ejemplo, etc.)
```

## Instaladores por categoría

Cada instalador es un script Bash independiente bajo `scripts/CATEGORY/`. El contrato final, ya aprobado, es de **6 verbos**: `status`, `install`, `uninstall`, `reinstall`, `update`, `repair` (ver [ADR 0004](docs/adr/0004-idempotencia-instalado-igual-skip.md), [ADR 0012](docs/adr/0012-modelo-de-estado-enriquecido.md) y [ADR 0029](docs/adr/0029-contrato-completo-de-instalador-referencia.md)). `scripts/editors/install_vim.sh` es el instalador de referencia que ya lo implementa completo.

La migración de los instaladores heredados hacia este contrato es **incremental** (Hito 11, ver `docs/ROADMAP.md`): se hace en fases pequeñas, sobre la infraestructura compartida `scripts/lib/installer_cli.sh` (dispatcher) y `scripts/lib/apt.sh` (helpers APT), no de una sola vez. Migrados hasta ahora: `install_vim.sh` (siempre fue la referencia), `install_cmatrix.sh` (Fase 1, piloto), `install_ranger.sh`, `install_terminator.sh` e `install_flameshot.sh` (Fase 2). El resto todavía implementa solo `status`/`install`/`uninstall`/`reinstall` — válido de forma transitoria mientras espera su turno. Ver el detalle y la clasificación de cada herramienta en [`docs/TOOLS.md`](docs/TOOLS.md).

#### **📝 `scripts/editors/`**
- `install_vscode.sh` — Visual Studio Code
- `install_cursor.sh` — Cursor AI IDE
- `install_vim.sh` — Vim (instalador de referencia del contrato de estado enriquecido)

#### **⚙️ `scripts/development/`**
- `install_docker.sh` — Docker Engine
- `install_nodejs.sh` — **legado/deprecado**: instalaba Node.js vía NVM; el bootstrap ya no lo usa (ver arriba). `install`/`uninstall`/`reinstall` se niegan a operar siempre, sin ninguna variable de entorno que los reactive (`status` se mantiene, de solo lectura)
- `install_yarn.sh` — Yarn
- `install_postman.sh` — Postman
- `install_dbeaver.sh` — DBeaver
- `install_gitkraken.sh` — GitKraken
- `install_insomnia.sh` — Insomnia
- `install_mongodb_compass.sh` — MongoDB Compass
- `install_kubectl.sh` — kubectl (vía snap)

#### **🖥️ `scripts/system/`**
- `install_system_update.sh`, `install_kernel.sh`, `install_development_tools.sh`, `install_system_utils.sh`, `install_multimedia.sh`, `install_terminator.sh`, `install_oh_my_zsh.sh`, `install_powerlevel10k.sh`, `install_ranger.sh`, `install_cmatrix.sh`, `install_gimp.sh`, `install_obs_studio.sh`

#### **🎯 `scripts/productivity/`**
- `install_ulauncher.sh`, `install_chrome.sh`, `install_spotify.sh`, `install_zoom.sh`, `install_flameshot.sh`

#### **🔧 `scripts/maintenance/`**
- `install_final_update.sh`

## Requisitos

- Ubuntu 24.04 LTS o 26.04 (política de soporte vigente, ver `docs/ROADMAP.md`)
- Conexión a internet
- Permisos de administrador (`sudo`)

## Cómo probar

Ver [`docs/TESTING.md`](docs/TESTING.md) para el detalle completo. Resumen:

```bash
# Sintaxis y pruebas unitarias (seguras en cualquier máquina)
bash -n setup.sh
find scripts tests -type f -name '*.sh' -exec bash -n {} \;
bash tests/test_router.sh
bash tests/test_doctor.sh
node tests/test_status_mapping.js

# Todo lo que instala/modifica de verdad (Mise, NVM, backups reales):
# único punto de entrada, corre dentro de contenedores Docker desechables
bash tests/docker/build-and-test-all.sh
```
