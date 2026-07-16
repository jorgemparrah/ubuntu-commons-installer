# ROADMAP.md

# Ubuntu Workstation

## Roadmap Técnico

**Estado:** Activo

---

# Propósito

Este roadmap define la evolución de largo plazo de Ubuntu Workstation.

Sirve como backlog técnico tanto para colaboradores humanos como para agentes de IA.

El roadmap prioriza intencionalmente la **evolución incremental** por sobre las reescrituras grandes.

Cada fase completada debe dejar el repositorio en un estado funcional.

---

# Flujo de trabajo

Cada fase sigue el mismo ciclo de vida:

```text
Ready
↓

In Progress
↓

Review

↓

Done
```

Si está bloqueada:

```text
Blocked
```

Si se abandona:

```text
Cancelled
```

---

# Reglas de desarrollo

Cada fase debe:

* preservar la retrocompatibilidad siempre que sea posible
* evitar refactors innecesarios
* producir commits pequeños
* incluir actualizaciones de documentación cuando corresponda
* pasar la validación antes de darse por completada

Ninguna fase debe modificar datos del usuario silenciosamente.

---

# Hito 1

## Evaluación del repositorio

**Prioridad**

Crítica

**Estado**

Done

### Objetivo

Entender el estado actual del repositorio antes de introducir cambios de arquitectura.

### Tareas

* Inventariar todos los instaladores
* Inventariar scripts auxiliares
* Detectar código duplicado
* Detectar herramientas obsoletas
* Detectar métodos de instalación deprecados
* Identificar dependencias de runtime
* Revisar la estructura del repositorio
* Revisar la documentación
* Identificar deuda técnica

### Entregables

* Evaluación inicial del repositorio (2026-07-13). Su contenido se distribuyó luego en `docs/adr/` (decisiones), `docs/TOOLS.md` (inventario de herramientas) y este roadmap (preguntas abiertas).

### Criterios de aceptación

* [x] Ningún código modificado
* [x] Inventario completo del repositorio generado
* [x] Riesgos identificados
* [x] Oportunidades de mejora documentadas

---

# Hito 2

## Bootstrap

**Prioridad**

Crítica

**Estado**

Review

Depende de:

* Evaluación del repositorio

### Objetivo

Crear un proceso de bootstrap robusto e independiente de Node.js.

### Tareas

* Chequeos de preflight
* Inicialización de logging
* Inicialización del workspace
* Verificación del sistema operativo
* Verificación de privilegios
* Verificación de conexión a internet

### Entregables

* `setup.sh` como router de comandos (`interactive` por defecto, `help`, `--help`, `version`)
* `scripts/lib/logging.sh` — biblioteca mínima de logging (`log_info`, `log_warn`, `log_error`, `log_success`, `log_debug`)
* `scripts/bootstrap/preflight.sh` — verificaciones de solo lectura, separadas en `preflight_core` (requisitos de los comandos Bash) y `preflight_interactive` (requisitos exclusivos del modo interactivo)
* `tests/test_router.sh` — pruebas no destructivas del router y el preflight

### Criterios de aceptación

El bootstrap se completa exitosamente sin modificar la configuración del usuario.

**Pendiente:** la tarea "Verificación de conexión a internet" listada arriba no se implementó en esta iteración — no formaba parte del alcance mínimo de preflight solicitado explícitamente para este hito. Queda para una iteración posterior de Bootstrap o para Doctor (Hito 4).

### Decisión relacionada

[ADR 0001](adr/0001-bootstrap-bash-sin-node.md) — `setup.sh` como router de comandos Bash, independiente de Node.

---

# Hito 3

## Idempotencia del menú y modelo de estado enriquecido

**Prioridad**

Crítica

**Estado**

Review

Depende de:

* Bootstrap

### Objetivo

Corregir el hallazgo crítico de idempotencia (una herramienta instalada se reinstala por defecto) antes de avanzar con Doctor, Backups y Migraciones. Es un cambio acotado, principalmente en `setup.js`/la lógica de mapeo estado→acción, que no depende de tener el bootstrap Bash completo salvo por el router de comandos ya creado en el Hito 2.

### Tareas

* Adoptar el contrato de estado enriquecido (`INSTALLED`, `NOT_INSTALLED`, `OUTDATED`, `BROKEN`, `UNSUPPORTED`, `UNKNOWN`) en el resultado de `status`, aunque los instaladores lo adopten de forma incremental
* Cambiar el mapeo por defecto del menú interactivo: `NOT_INSTALLED → install`, `INSTALLED → skip`, `OUTDATED → update`, `BROKEN → repair`
* Dejar `reinstall` como acción avanzada explícita, nunca por defecto

### Entregables

* `setup.js`: normalización de estado (`normalizeStatus`), mapeo estado→acción por defecto, y confirmación explícita (`confirmForcedReinstalls`) antes de forzar un `reinstall` sobre algo ya instalado
* `scripts/editors/install_vim.sh`: instalador de referencia con el contrato de estado enriquecido completo (`status` + `update` + `repair`)
* `tests/test_status_mapping.js`: prueba no destructiva del mapeo estado→acción

### Criterios de aceptación

* [x] Seleccionar una herramienta ya instalada y sana no dispara `uninstall`/`install`
* [x] `reinstall` sigue disponible como acción explícita
* [x] Al menos un instalador de referencia expone el contrato de estado enriquecido de punta a punta

### Decisiones relacionadas

[ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md) — una herramienta instalada se omite por defecto.
[ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) — modelo de estado enriquecido para `status`.

---

# Hito 4

## Doctor

**Prioridad**

Crítica

**Estado**

Review

Depende de:

* Idempotencia del menú y modelo de estado enriquecido

### Objetivo

Inspeccionar el estado de la workstation.

### Tareas

Detectar:

* [x] versión de Ubuntu
* [x] shell
* [x] Git
* [x] Docker (instalado + si el demonio está activo)
* [x] Node (instalado + de dónde viene: nvm/mise/apt/snap)
* [x] Mise
* [x] AWS CLI
* [x] kubectl
* [x] Helm
* [x] SSH (solo presencia y cantidad de claves, nunca contenido)
* [x] runtimes existentes / indicadores de home retenido (rutas de la [ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md))

### Entregables

* `setup.sh doctor` / `setup.sh doctor --verbose`
* `scripts/diagnostics/doctor.sh`
* `tests/test_doctor.sh` — incluye una verificación de que `doctor` no modifica `$HOME`

### Criterios de aceptación

* [x] Doctor nunca modifica el sistema
* [x] Produce un reporte legible
* [x] Soporta modo verbose (`--verbose`/`-v`)
* [x] Usa el contrato de estado enriquecido del Hito 3 — **nota de diseño:** Doctor no invoca el `status` de cada instalador de `scripts/`; inspecciona directamente las herramientas de sistema que le pide AGENT.md sección 10 (Git, Docker, Node, Mise, AWS CLI, kubectl, Helm) y reporta información más rica que un simple instalado/no-instalado (por ejemplo, origen de Node —nvm/mise/apt/snap— y si el demonio de Docker está activo). Si se prefiere que Doctor además reporte el estado enriquecido de cada herramienta gestionada por `scripts/*/install_*.sh`, es un ajuste incremental a futuro, no bloqueante para este hito.

---

# Hito 5

## Gestor de Backups

**Prioridad**

Crítica

**Estado**

Review

Depende de:

* Doctor

### Objetivo

Crear un sistema de backups centralizado.

### Tareas

Respaldar:

* [x] configuración del shell (`.bashrc`, `.zshrc`, `.profile`)
* [x] configuración de runtime (`.gitconfig`, `.config/mise/config.toml`)
* [ ] carpetas migradas — primitiva lista (`backup_move_dir`), sin un llamador todavía; la usará la migración NVM→Mise del Hito 7
* [ ] archivos modificados por instaladores — se conectará al modernizar instaladores (Hito 11) o al implementar migraciones concretas (Hito 6-7)

### Entregables

* `scripts/lib/backup.sh` — `backup_init_session`, `backup_copy_file`, `backup_copy_dir`, `backup_move_dir` (primitiva para mover con verificación, aún sin usar), manifiesto TSV
* `setup.sh backup` / `setup.sh backup --dry-run`
* `tests/fixtures/sample_home/` — home de ejemplo para probar backups sin tocar `$HOME` real
* `tests/test_backup.sh`

### Criterios de aceptación

* [x] Backups con timestamp (`<timestamp>-<pid>`, único por sesión)
* [x] Sin sobrescritura (una sesión existente nunca se reutiliza; un archivo ya respaldado en la sesión no se pisa)
* [x] Sin comportamiento destructivo (`backup_copy_file`/`backup_copy_dir` nunca tocan el origen; `backup_move_dir` solo borra el origen tras verificar la copia, y no se invoca desde ningún flujo todavía)
* [x] Soporta `--dry-run` (no crea nada en el filesystem, solo reporta)

### Decisión relacionada

[ADR 0005](adr/0005-gestor-de-backups-centralizado.md).
[ADR 0023](adr/0023-variable-uci-home-dir-para-pruebas.md) — `UCI_HOME_DIR` se usó para probar este hito de punta a punta sin tocar el `$HOME` real.

---

# Hito 6

## Framework de migraciones

**Prioridad**

Crítica

**Estado**

Review

Depende de:

* Gestor de Backups

### Objetivo

Proveer un sistema de migraciones reutilizable.

### Tareas

* [x] registro de migraciones (`migrations_discover`, `setup.sh migrate --list`)
* [x] marcas de finalización (`<home>/.local/state/ubuntu-workstation/migrations/<id>.done`)
* [x] estrategia de rollback (acción `rollback-notes` del contrato; notas legibles, no rollback automático)
* [x] ejecución de migraciones (`setup.sh migrate`, `--dry-run`)

### Entregables

* `scripts/lib/migrations.sh` — motor: descubrimiento, listado, ejecución con marcas de finalización
* `scripts/migrations/README.md` — contrato completo para escribir migraciones (`describe|check|dry-run|apply|validate|rollback-notes`)
* `scripts/migrations/000_example_noop.sh` — migración de referencia, no toca nada real, sirve de plantilla para el Hito 7
* `setup.sh migrate` / `--list` / `--dry-run`
* `tests/test_migrations.sh`

### Criterios de aceptación

* [x] Ejecución repetible (una migración ya hecha nunca se reaplica; probado corriendo `migrate` dos veces)
* [x] Ejecución segura (`--dry-run` no toca el filesystem; una migración fallida no se marca como hecha y no se sigue con la siguiente)
* [x] Historial de migraciones registrado (marcas `.done` + `migrate --list`)

### Decisión relacionada

[ADR 0006](adr/0006-framework-de-migraciones-versionado.md).

---

# Hito 7

## Migración NVM → Mise

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

Framework de migraciones

### Objetivo

Reemplazar NVM por Mise.

### Tareas

Detectar:

* versiones de Node instaladas
* paquetes globales

Respaldar:

* .nvm
* configuración del shell

Instalar:

* Mise

Restaurar:

* runtimes de Node

Validar:

* PATH
* ejecutables

### Criterios de aceptación

Node ya no depende de NVM.

La migración es repetible.

### Decisiones relacionadas

[ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md), [ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md), [ADR 0007](adr/0007-bloques-gestionados-en-archivos-de-shell.md).

---

# Hito 8

## Gestor de runtimes

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Migración NVM

### Objetivo

Centralizar la gestión de runtimes.

### Tareas

Soportar:

* Node
* Python
* Java
* Go
* Rust

a través de Mise siempre que sea posible.

### Criterios de aceptación

Todos los runtimes soportados se gestionan de forma consistente.

---

# Hito 9

## Compatibilidad con Ubuntu 26

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Gestor de runtimes

### Objetivo

Revisar cada instalador para Ubuntu 26.

### Tareas

Revisar:

* repositorios
* nombres de paquetes
* comandos deprecados
* métodos de instalación

### Criterios de aceptación

Todos los instaladores soportados funcionan correctamente en Ubuntu 26.

---

# Hito 10

## Gate de calidad automatizado (CI)

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Compatibilidad con Ubuntu 26

### Objetivo

Agregar un workflow de CI no destructivo antes de modernizar instaladores en volumen.

### Tareas

* Validar `bash -n` en todos los scripts de shell
* Validar con ShellCheck
* Lint del código Node.js
* Ejecutar tests si existen

### Entregables

Workflow de CI.

### Criterios de aceptación

El CI no ejecuta instaladores reales contra un sistema; solo valida sintaxis y estilo.

### Decisión relacionada

[ADR 0014](adr/0014-gate-de-calidad-ci.md).

---

# Hito 11

## Modernización de instaladores

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Gate de calidad automatizado (CI)

### Objetivo

Estandarizar las interfaces de los instaladores.

Cada instalador debe exponer:

* status
* install
* update
* repair
* uninstall

Separar conceptualmente las acciones de mantenimiento de sistema (kernel, actualizaciones) de los instaladores de aplicaciones.

### Criterios de aceptación

Comportamiento consistente entre instaladores.

### Decisión relacionada

[ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md) — separar mantenimiento de sistema de instaladores de aplicaciones.

---

# Hito 12

## Framework de validación

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Modernización de instaladores

### Objetivo

Verificar la integridad de la workstation.

### Tareas

Validar:

* PATH
* ejecutables
* dependencias
* symlinks
* versiones de runtime

### Entregables

Módulo de validación.

---

# Hito 13

## Perfiles

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Framework de validación

### Objetivo

Soportar perfiles de instalación.

Ejemplos:

* minimal
* desktop
* developer
* workstation
* full

---

# Hito 14

## Arquitectura de plugins

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Perfiles

### Objetivo

Convertir los instaladores en plugins descubribles.

Ejemplo:

```
docker/

metadata.yaml

install.sh

update.sh

repair.sh

status.sh
```

### Decisión relacionada

[ADR 0009](adr/0009-postergar-arquitectura-de-plugins.md) — postergada hasta este punto del roadmap.

---

# Hito 15

## Documentación

**Prioridad**

Continua

### Tareas

Mantener la documentación sincronizada.

Una vez aceptada la nueva arquitectura, acortar el `README.md` raíz a propósito, inicio rápido, seguridad y enlaces a `docs/`; mover los detalles de implementación a `docs/`; asegurar que los ejemplos no prometan idempotencia hasta que esté implementada.

Documentos requeridos:

* AGENT.md
* ARCHITECTURE.md
* ROADMAP.md
* CONTRIBUTING.md
* TOOLS.md
* docs/adr/ (decisiones de arquitectura, una por archivo)
* MIGRATIONS.md
* RELEASES.md

---

# Preguntas resueltas por el dueño del proyecto (2026-07-15)

Migradas desde la evaluación inicial del repositorio (2026-07-13) y resueltas en una revisión de inventario de herramientas. Las decisiones de arquitectura resultantes están en `docs/adr/` (0016–0021) y el inventario actualizado en `docs/TOOLS.md`.

1. **Versiones de Node vía Mise:** última estable + últimas 2 LTS. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
2. **Archivo de versión por proyecto:** se soportan `.nvmrc` y `.node-version`, además de `mise.toml`. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
3. **Yarn/pnpm:** los instala Mise directamente, no Corepack. Ver [ADR 0017](adr/0017-mise-instala-yarn-pnpm-directo.md).
4. **Terminal:** se mantiene Terminator.
5. **Oh My Zsh y Powerlevel10k:** se mantienen ambos; al reutilizar `/home` se respalda/reutiliza la personalización existente en vez de sobrescribirla. Ver [ADR 0021](adr/0021-reutilizar-personalizacion-shell-en-home.md).
6. **Postman, Insomnia, GitKraken:** se mantienen los tres.
7. **Bruno:** no se agrega; se mantienen Postman e Insomnia.
8. **MongoDB Compass:** se mantiene.
9. **kubectl:** se gestiona vía Mise, no vía Snap. Ver [ADR 0018](adr/0018-kubectl-via-mise.md).
10. **Obligatorias vs. opcionales:** el dueño del proyecto prefiere revisar la clasificación `required | optional | retired | candidate` caso por caso en una sesión posterior — sigue pendiente, ver `docs/TOOLS.md`.
11. **Soporte de Ubuntu:** solo 24.04 y 26.04.
12. **NVIDIA/CUDA:** fuera de alcance del repositorio; se documentan como fase manual separada. Ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md).
13. **Ajustes de escritorio y atajos de teclado:** fuera de alcance, salvo el atajo de `PrintScreen` para lanzar Flameshot. Ver [ADR 0019](adr/0019-flameshot-atajo-printscreen.md).
14. **Symlinks `.agents`, `.claude`, `.cursor`:** no se gestionan por ahora. Ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md).

También se confirmó, fuera de la lista original: mantener ULauncher (salvo alternativa mejor), cmatrix y ranger (salvo alternativa más amigable para este último).

---

# Deuda técnica

Los siguientes puntos requieren revisión periódica:

* funciones de shell duplicadas
* repositorios obsoletos
* instaladores deprecados
* gestores de paquetes deprecados
* dependencias innecesarias

---

# Ideas futuras

Estas quedan intencionalmente fuera de alcance por ahora.

* Dashboard de instalación
* Reportes HTML
* Reportes JSON
* TUI interactiva
* Marketplace de plugins
* Actualizaciones automáticas
* Sincronización entre workstations
* Inventario de máquinas
* Aprovisionamiento remoto
* Múltiples perfiles de workstation

---

# Criterios de éxito

El proyecto se considerará maduro cuando:

* Una instalación limpia de Ubuntu pueda aprovisionarse con mínima intervención manual.
* Los directorios `/home` existentes puedan reutilizarse de forma segura.
* Las instalaciones sean deterministas e idempotentes.
* Todas las herramientas gestionadas puedan diagnosticarse, actualizarse, repararse y eliminarse de forma consistente.
* El repositorio sirva como fuente única de verdad para la configuración de la workstation.
