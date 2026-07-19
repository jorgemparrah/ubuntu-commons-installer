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

Done

Depende de:

* Evaluación del repositorio

Cerrado como `Done` en el cierre de la fase de estabilización (2026-07-16). Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#hito-2--bootstrap).

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

**Corrección de la auditoría de estabilización (2026-07-16):** el flujo interactivo (`main_setup`/`ensure_node_via_mise` en `setup.sh`) instalaba Node.js vía NVM (`scripts/development/install_nodejs.sh`), pese a que el Hito 7 ya reemplazaba NVM por Mise para quien migraba. Corregido: ver el detalle en la sección "Auditoría de estabilización" del Hito 7.

### Decisión relacionada

[ADR 0001](adr/0001-bootstrap-bash-sin-node.md) — `setup.sh` como router de comandos Bash, independiente de Node.

---

# Hito 3

## Idempotencia del menú y modelo de estado enriquecido

**Prioridad**

Crítica

**Estado**

Done

Depende de:

* Bootstrap

Cerrado como `Done` en el cierre de la fase de estabilización (2026-07-16). Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#hito-3--idempotencia-del-menú-y-modelo-de-estado-enriquecido).

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
* `scripts/lib/status_contract.js`: `resolveStatusFromExecResult`/`resolveStatusFromExecError` (agregado en la auditoría de estabilización) — distinguen un `NOT_INSTALLED` legítimo (el script lo imprime y sale con código ≠0, convención existente) de una falla real de ejecución (ENOENT, sin permiso, crash sin salida reconocible), que ahora se reporta como `UNKNOWN`, nunca como `NOT_INSTALLED` por defecto

### Criterios de aceptación

* [x] Seleccionar una herramienta ya instalada y sana no dispara `uninstall`/`install` — `tests/test_status_mapping.js`
* [x] `reinstall` sigue disponible como acción explícita — `confirmForcedReinstalls` en `setup.js`
* [x] Al menos un instalador de referencia expone el contrato de estado enriquecido de punta a punta — `scripts/editors/install_vim.sh`
* [x] Un error ejecutando `status` no se confunde con `NOT_INSTALLED` (auditoría 2026-07-16) — `tests/test_status_mapping.js` (8 casos: ENOENT, permiso denegado, crash sin salida reconocible, error sin stdout)

### Decisiones relacionadas

[ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md) — una herramienta instalada se omite por defecto.
[ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) — modelo de estado enriquecido para `status`.

---

# Hito 4

## Doctor

**Prioridad**

Crítica

**Estado**

Done

Depende de:

* Idempotencia del menú y modelo de estado enriquecido

Cerrado como `Done` en el cierre de la fase de estabilización (2026-07-16). Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#hito-4--doctor).

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

Done

Depende de:

* Doctor

Cerrado como `Done` en el cierre de la fase de estabilización (2026-07-16). Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#hito-5--gestor-de-backups).

### Objetivo

Crear un sistema de backups centralizado.

### Tareas

Respaldar:

* [x] configuración del shell (`.bashrc`, `.zshrc`, `.profile`)
* [x] configuración de runtime (`.gitconfig`, `.config/mise/config.toml`)
* [x] carpetas migradas — `backup_move_dir` tiene llamador desde el Hito 7 (`scripts/migrations/001_nvm_to_mise.sh`, mueve `.nvm`); fortalecido en la auditoría de estabilización con verificación de manifiesto completo (ver más abajo)
* [ ] archivos modificados por instaladores — se conectará al modernizar instaladores (Hito 11)

### Entregables

* `scripts/lib/backup.sh` — `backup_init_session`, `backup_copy_file`, `backup_copy_dir`, `backup_move_dir` (mover con verificación de integridad completa), `backup_dir_manifest`, manifiesto TSV
* `setup.sh backup` / `setup.sh backup --dry-run`
* `tests/fixtures/sample_home/` — home de ejemplo para probar backups sin tocar `$HOME` real
* `tests/test_backup.sh`, `tests/test_backup_move_dir.sh` (agregado en la auditoría de estabilización, 17 casos incluyendo 5 negativos deliberados)

### Criterios de aceptación

* [x] Backups con timestamp (`session-id` con el formato `TIMESTAMP-PID`, único por sesión)
* [x] Sin sobrescritura (una sesión existente nunca se reutiliza; un archivo ya respaldado en la sesión no se pisa)
* [x] Sin comportamiento destructivo — `backup_copy_file`/`backup_copy_dir` nunca tocan el origen; `backup_move_dir` solo borra el origen si el manifiesto completo (rutas, tipos, permisos, tamaños, symlinks, hashes) coincide exactamente entre origen y destino, no solo la cantidad de archivos (corregido en la auditoría de estabilización del 2026-07-16, ver `tests/test_backup_move_dir.sh`)
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

Done

Depende de:

* Gestor de Backups

Cerrado como `Done` en el cierre de la fase de estabilización (2026-07-16). Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#hito-6--framework-de-migraciones).

### Objetivo

Proveer un sistema de migraciones reutilizable.

### Tareas

* [x] registro de migraciones (`migrations_discover`, `setup.sh migrate --list`)
* [x] marcas de finalización (`${UCI_HOME_DIR:-$HOME}/.local/state/ubuntu-workstation/migrations/MIGRATION_ID.done`)
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

Done

Depende de:

Framework de migraciones

Cerrado como `Done` (2026-07-17): las tres brechas que lo mantenían en `Review` (M06, M07, ruta legada de `install_nodejs.sh`) quedan resueltas y probadas en ambas versiones de Ubuntu. Ver evidencia detallada en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#cierre-del-hito-7--m06-m07-e-instalador-legado-2026-07-17). Sin limitación de Ubuntu 26.04: las 8 combinaciones Docker de este hito corrieron exitosamente también en 26.04.

### Objetivo

Reemplazar NVM por Mise.

### Tareas

Detectar:

* [x] versiones de Node instaladas (`~/.nvm/versions/node/*`)
* [x] paquetes globales (se inventarían en `reports/nvm-global-packages.tsv` con nombre y versión del propio `package.json`; no se reinstalan automáticamente, ver [ADR 0024](adr/0024-alcance-migracion-nvm-a-mise.md))

Respaldar:

* [x] .nvm (movido, no copiado ni borrado directo — copiar + verificar íntegramente + recién ahí eliminar el origen; ver Hito 5)
* [x] configuración del shell (`.bashrc`, `.zshrc`, `.profile`, respaldados antes de tocarlos, y limpiados de líneas exactas conocidas de NVM — ver auditoría más abajo)

Instalar:

* [x] Mise

Restaurar:

* [x] runtimes de Node (cada versión detectada, reinstalada vía Mise; versión global resuelta correctamente desde el alias `default` de NVM contra las versiones instaladas — no asumida literal)

Validar:

* [x] PATH / ejecutables (Mise resuelve un `node` ejecutable y corre)
* [x] Ningún archivo de shell sigue intentando cargar `$NVM_DIR/nvm.sh` (ruta que ya no existiría tras mover `.nvm`) — `migration_validate` falla si detecta esto

### Entregables

* `scripts/migrations/001_nvm_to_mise.sh` (contrato del Hito 6: `describe|check|dry-run|apply|validate|rollback-notes`; incluye `UCI_TEST_FAIL_MIGRATION_AT` para pruebas de recuperación y el sentinel de reanudación)
* `tests/docker/Dockerfile.nvm-single`, `tests/docker/Dockerfile.nvm-multi`, `tests/docker/Dockerfile.nvm-mise-preexisting` — imágenes con NVM+Node (y, la última, Mise) ya instalados, para probar sobre un "home reutilizado" realista
* `tests/docker/test_nvm_to_mise_apply.sh`, `tests/docker/test_nvm_to_mise_prebaked.sh`, `tests/docker/test_nvm_to_mise_mise_preexisting.sh`, `tests/docker/test_nvm_to_mise_fault_injection.sh`, `tests/docker/test_bootstrap_mise_no_nvm.sh`, `tests/docker/build-and-test-all.sh` (único punto de entrada de toda la batería)
* `tests/test_install_nodejs_legacy.sh` — confirma que el instalador legado no puede borrar `.nvm` ni modificar archivos de shell
* `docs/TEST_CASES.md` — casos de prueba funcionales por comando/escenario

### Criterios de aceptación

* [x] Node ya no depende de NVM — **ahora cierto tanto para la migración como para una workstation nueva**: el bootstrap interactivo (`./setup.sh` sin argumentos) también usa Mise desde la auditoría de estabilización (ver más abajo); antes de eso, solo la migración lo garantizaba, y una workstation nueva seguía instalando NVM
* [x] La migración es repetible (correr `migrate` dos veces no crea una segunda sesión de backup ni reaplica)

Validado de punta a punta en **14 combinaciones** (imagen base + `nvm-single` + `nvm-multi` + `nvm-mise-preexisting`, en Ubuntu 24.04 y 26.04), todas en verde. Ver `docs/TEST_CASES.md` (casos M01-M08, BOOT01, U01-U08).

### Auditoría de estabilización (2026-07-16)

Antes de esta auditoría, el Hito 7 estaba marcado `Review` con estos criterios en `[x]`, pero una revisión línea por línea del código publicado encontró varias diferencias reales entre lo documentado y lo implementado. Todas se corrigieron en la rama `estabilizacion-hitos-2-7`:

| Hallazgo | Estado antes | Corrección |
|---|---|---|
| El bootstrap interactivo (`./setup.sh` sin argumentos) seguía instalando NVM vía `install_nodejs.sh` | El criterio "Node ya no depende de NVM" solo era cierto para quien ya tenía NVM y corría `migrate`; una workstation nueva seguía recibiendo NVM | `ensure_node_via_mise()` reemplaza ese camino; `install_nodejs.sh` marcado legado, requiere `UCI_ALLOW_LEGACY_NVM=1` explícito |
| No existía limpieza de líneas de NVM en `.bashrc`/`.zshrc`/`.profile` | Tras migrar, esos archivos seguían intentando cargar `$NVM_DIR/nvm.sh`, una ruta ya movida al backup | `nvm_cleanup_shell_file` elimina solo patrones exactos reconocidos; líneas ambiguas se reportan, nunca se borran a ciegas |
| El inventario de NVM (versiones, paquetes globales) solo se imprimía por log, no se persistía | Se perdía al cerrar la terminal | `reports/nvm-versions.tsv`, `reports/nvm-global-packages.tsv`, `reports/shell-changes.tsv` dentro de la sesión de backup |
| `backup_move_dir` decidía eliminar el origen solo por cantidad de archivos | Un archivo alterado con el mismo conteo, o un symlink retargeteado, no se detectaba | `backup_dir_manifest` compara rutas, tipos, permisos, tamaños, symlinks y hashes completos antes de cualquier `rm -rf` (ver Hito 5) |
| `getToolStatus()` en `setup.js` convertía cualquier fallo de ejecución en `NOT_INSTALLED` | No se distinguía un error real de un "no instalado" legítimo | `resolveStatusFromExecError` reporta `UNKNOWN` cuando el script no imprimió nada reconocible (ver Hito 3) |

Ver la matriz de cumplimiento completa (Hito | Entregable | Estado real | Prueba | Diferencia encontrada) en el historial de la conversación que originó esta auditoría; los commits `e0d3104`, `bf6456f`, `ba6dda9`, `a4d0b3a`, `556d6ca` documentan cada corrección individualmente.

Al cierre de esta auditoría (2026-07-16) quedaron tres diferencias pendientes, documentadas explícitamente: M06 (Mise ya instalado antes de migrar), M07 (`apply` falla a mitad de camino) y el `uninstall`/`reinstall` legado de `install_nodejs.sh` forzable con `UCI_ALLOW_LEGACY_NVM=1`. Las tres se cierran en la sección siguiente.

### Cierre de brechas de M06/M07/instalador legado (2026-07-17)

* **M06 — Mise ya instalado antes de migrar:** nuevo `tests/docker/Dockerfile.nvm-mise-preexisting` (NVM+1 versión de Node + Mise ya instalado en tiempo de build) y `tests/docker/test_nvm_to_mise_mise_preexisting.sh`. Confirma que la migración no reinstala Mise (misma versión antes/después) y sigue instalando Node vía Mise, resolviendo el alias global y moviendo `.nvm`. No requirió cambios de código en la migración: ya evitaba reinstalar Mise, era una brecha de prueba.
* **M07 — `apply` falla a mitad de camino:** nueva variable `UCI_TEST_FAIL_MIGRATION_AT` en `scripts/migrations/001_nvm_to_mise.sh` (vacía por defecto, sin efecto en ejecución normal) que inyecta un fallo en 5 checkpoints (`after_shell_backup`, `before_mise_install`, `after_mise_before_node`, `after_node_before_move`, `before_done_marker`), probados por `tests/docker/test_nvm_to_mise_fault_injection.sh`. Se encontró y corrigió un gap real durante el diseño: si `apply()` mueve `.nvm` con éxito pero `validate()` falla justo después, la migración quedaba huérfana para siempre en el reintento. Se agregó un sentinel propio (`.001_nvm_to_mise.apply-completado`) para que `migration_check()` permita reintentar en ese caso. Modelo de recuperación: **reanudación idempotente, no rollback automático** (ver `docs/TESTING.md`).
* **Instalador legado `install_nodejs.sh`:** `install`/`uninstall`/`reinstall` ahora se niegan a operar **siempre**, sin ninguna variable de entorno que los reactive (se eliminó `UCI_ALLOW_LEGACY_NVM` por completo). El código destructivo (`rm -rf ~/.nvm`, `sed -i` sobre `.bashrc`/`.zshrc`/`.profile`) se eliminó físicamente del script, no solo se deshabilitó. `status` se mantiene. Probado por el nuevo `tests/test_install_nodejs_legacy.sh` (27 casos, Nivel 1).

Validado en **8 combinaciones de imagen** (base, `nvm-single`, `nvm-multi`, `nvm-mise-preexisting` × Ubuntu 24.04/26.04), todas en verde, más 300 pruebas de Nivel 1 (150 por versión de Ubuntu) sin fallos. Ver la matriz completa en [`docs/ACCEPTANCE_2_7.md`](ACCEPTANCE_2_7.md#cierre-del-hito-7--m06-m07-e-instalador-legado-2026-07-17).

### Decisiones relacionadas

[ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md), [ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md), [ADR 0007](adr/0007-bloques-gestionados-en-archivos-de-shell.md), [ADR 0024](adr/0024-alcance-migracion-nvm-a-mise.md).

---

# Hito 8

## Gestor de runtimes

**Prioridad**

Alta

**Estado**

Done

Depende de:

Migración NVM

Cerrado como `Done` (2026-07-17) tras rebasar este hito sobre el `main` posterior al cierre del Hito 7 (checkpoints de fallo, sentinel de reanudación, instalador legado desactivado) y validar en CI que nada se rompió: 9/9 jobs en verde en ambas versiones de Ubuntu, incluidos los casos R01-R06 de este hito y M01-M08 del Hito 7. Ver [PR #2](https://github.com/jorgemparrah/ubuntu-commons-installer/pull/2).

### Objetivo

Centralizar la gestión de runtimes.

### Tareas

Soportar (catálogo en `scripts/lib/runtime.sh`, ver `docs/ARCHITECTURE.md` sección 10):

* [x] Node — probado de punta a punta (instalación + status)
* [x] Python — probado de punta a punta (instalación + status), confirma que la abstracción es genérica
* [x] Java, Go, Rust — soportados por el mismo catálogo/mecanismo; no se instalaron realmente en las pruebas (nadie los pidió todavía), pero `runtime status` los reporta correctamente como "no gestionado" cuando no están

a través de Mise siempre que sea posible.

### Entregables

* `scripts/lib/runtime.sh` — `runtime_ensure_mise`, `runtime_install`, `runtime_use_global`, `runtime_status_all`, catálogo de runtimes soportados
* `setup.sh runtime status` — reporte de solo lectura de qué runtimes gestiona Mise
* `scripts/migrations/001_nvm_to_mise.sh` refactorizado para usar esta librería en vez de duplicar la instalación de Mise (sin cambios de comportamiento, revalidado)
* `tests/docker/test_runtime_status.sh`

### Criterios de aceptación

* [x] Todos los runtimes soportados se gestionan de forma consistente (mismo catálogo, mismas funciones `runtime_install`/`runtime_use_global`/`runtime_status_all` para cualquiera de los 5)

Validado en Docker instalando y gestionando **dos runtimes distintos (Node y Python)** con el mismo mecanismo, más la revalidación completa de la migración NVM→Mise tras el refactor. Ver `docs/TEST_CASES.md` (casos R01-R06).

### Decisión relacionada

[ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md) — Mise como único gestor de runtimes; este hito construye el mecanismo compartido que aplica esa decisión de forma consistente para Node, Python, Java, Go y Rust.

---

# Hito 9

## Compatibilidad con Ubuntu 26

**Prioridad**

Alta

**Estado**

Review

Depende de:

Gestor de runtimes

**Corrección administrativa (2026-07-17):** este hito estaba marcado `Blocked` pese a que su dependencia (Gestor de runtimes, Hito 8) ya está `Done`. Pasa a `In Progress` al iniciar la Fase A (auditoría e inventario, ver `docs/UBUNTU_COMPATIBILITY.md`).

**Avance de la Fase B (2026-07-17):** 9 de los 13 puntos de la prioridad de intervención ya están corregidos y probados, con evidencia real en CI (`system_utils`, `development_tools`, `multimedia`, `kubectl`→Mise, `Yarn`→Mise, Oh My Zsh/Powerlevel10k, ULauncher, `system_update`/`final_update`, Cursor→repo APT oficial, MongoDB Compass). Validar contra CI real (no solo revisión de código) encontró y corrigió 6 bugs adicionales que ninguna revisión estática hubiera detectado: `software-properties-common` ausente en la imagen (rompía el PPA de ULauncher), `gnupg` ausente (rompía la clave de Cursor en silencio), un conflicto de `Signed-By` entre la entrada manual y la que el propio paquete de Cursor gestiona, y `dpkg -s`/`dpkg -l` reportando estado incorrecto tras `apt remove` en dos scripts. Además se dividió el job `base` del CI (antes 11 scripts en serie, ~15-18 min) en 5 grupos paralelos, bajando el tiempo total a ~11 min. Quedan pendientes: Snap-dependientes (8 instaladores, no verificables sin `snapd` en Docker), Docker/VS Code (esperan evidencia real contra Ubuntu 26.04; VS Code además comparte el riesgo latente de `gnupg` ausente encontrado en Cursor, sin corregir todavía), `install_kernel.sh` (bug de fallback de nombres, alto riesgo, no probar en Docker), y la decisión de alcance sobre `install_chrome.sh` (arquitectura `amd64`). Este hito permanece en `In Progress`, no se marca `Done` mientras estos puntos sigan abiertos. Ver `docs/UBUNTU_COMPATIBILITY.md` para la matriz completa y evidencia por instalador. CI verde: [PR #3](https://github.com/jorgemparrah/ubuntu-commons-installer/pull/3).

**Cierre de brechas (2026-07-17):** resueltos los 4 puntos restantes de la Fase B. VS Code recibió los mismos fixes que Cursor (`gnupg` on-demand, keyring no vacío, `dpkg -l`, `apt purge`) y pasó su prueba funcional Docker (`tests/docker/test_vscode_apt_repo.sh`, V01) en ambas versiones de Ubuntu. Docker obtuvo evidencia real contra Ubuntu 26.04 real (`tests/docker/test_docker_apt_repo.sh`, D01): Docker Inc. publica `docker-ce` tanto para `noble` (24.04, candidato `5:29.6.2-1~ubuntu.24.04~noble`) como para `resolute` (26.04, candidato `5:29.6.2-1~ubuntu.26.04~resolute`), ambos instalados con éxito. `install_kernel.sh` corrigió el bug de fallback de nombres (`lsb_release -rs` en vez de `-cs`), cubierto por prueba unitaria de la función pura (`tests/test_kernel_hwe_fallback.sh`, I08) — la instalación real de un kernel sigue sin poder probarse automáticamente y requiere validación manual en VM. `install_chrome.sh` formalizó el alcance de arquitectura en una ADR nueva ([ADR 0028](adr/0028-arquitectura-soportada-amd64.md), `amd64` oficial, `arm64` alcance futuro) y ahora rechaza explícitamente con `UNSUPPORTED` en arquitecturas no soportadas en vez de arriesgar una descarga silenciosa incorrecta. Los 8 instaladores Snap recibieron una corrección de contrato (`check_status()` distingue `INSTALLED`/`NOT_INSTALLED`/`UNKNOWN` cuando `snapd` está ausente) con prueba simulada (`tests/test_snap_installers_contract.sh`, I10), más una pauta de validación manual para Ubuntu 26.04 Desktop documentada en `docs/TEST_CASES.md` y en `docs/UBUNTU_COMPATIBILITY.md` — **todavía sin ejecutar**. `docs/UBUNTU_COMPATIBILITY.md` ahora exige evidencia separada por versión de Ubuntu y por tipo de prueba para declarar `compatible`, con una tabla nueva ("Evidencia por versión de Ubuntu") de las 30 filas. CI verde 19/19 en el PR de cierre (`hito-9-cierre-brechas`). Este hito pasa a `Review`, no a `Done`: quedan como validación manual pendiente la pauta de los 8 instaladores Snap en Ubuntu 26.04 Desktop real y la instalación real de un kernel HWE en VM; ninguna de las dos puede ejecutarse en CI ni en esta máquina de desarrollo. No se avanza al Hito 11 todavía.

### Objetivo

Auditar todos los instaladores y operaciones de mantenimiento existentes para determinar y asegurar su compatibilidad con Ubuntu 24.04 y Ubuntu 26.04. La modernización en volumen de las interfaces de los instaladores corresponde al Hito 11, no a este.

### Tareas

Revisar:

* repositorios
* nombres de paquetes
* comandos deprecados
* métodos de instalación

### Criterios de aceptación

Todos los instaladores soportados funcionan correctamente en Ubuntu 26, con evidencia individual por instalador (ver `docs/UBUNTU_COMPATIBILITY.md`). No se declara este hito `Done` mientras queden instaladores sin clasificar o sin evidencia explícita de validación.

---

# Hito 10

## Gate de calidad automatizado (CI)

**Prioridad**

Alta

**Estado**

Done

Depende de:

Migración NVM

**Reordenado (2026-07-17):** este hito ya no depende de "Compatibilidad con Ubuntu 26" — ver [ADR 0026](adr/0026-adelantar-hito-10-ci-antes-que-hito-9.md). Se adelantó para poder correr la batería completa del Hito 7 (M06/M07, 8 combinaciones de imagen × Ubuntu 24.04/26.04) en GitHub Actions en vez de en la máquina de desarrollo local, que resultaba lenta y costosa para iterar.

### Objetivo

Agregar un workflow de CI antes de modernizar instaladores en volumen.

### Tareas

* [x] Validar `bash -n` en todos los scripts de shell
* [x] Validar con ShellCheck
* [x] Lint del código Node.js (`node --check`)
* [x] Ejecutar toda la batería de pruebas existente (Nivel 1 y Nivel 2, incluida la matriz Docker completa)

### Entregables

* `.github/workflows/ci.yml` — job `lint` (sintaxis/estilo, corre directo en el runner) + job `docker-matrix` (8 combinaciones: 4 variantes de imagen × Ubuntu 24.04/26.04, reflejando `docs/TEST_CASES.md`)

### Criterios de aceptación

* [x] El CI valida sintaxis y estilo (`bash -n`, ShellCheck, `node --check`) antes de correr nada más costoso
* [x] El CI corre toda la batería funcional (Nivel 1 y Nivel 2) en paralelo, sin intervención manual

### Redefinición de alcance (2026-07-17)

El criterio original ("El CI no ejecuta instaladores reales contra un sistema; solo valida sintaxis y estilo") describía un CI más acotado del que se terminó necesitando. El CI implementado sí instala software real (NVM, Node, Mise) dentro del job `docker-matrix` — pero siempre dentro de contenedores Docker desechables, corriendo dentro de un runner de GitHub Actions igualmente desechable: nunca toca un sistema persistente, en el mismo sentido en que `tests/docker/build-and-test-all.sh` tampoco lo hace en local. Ver [ADR 0026](adr/0026-adelantar-hito-10-ci-antes-que-hito-9.md) para el detalle completo de esta decisión.

### Decisiones relacionadas

[ADR 0014](adr/0014-gate-de-calidad-ci.md), [ADR 0026](adr/0026-adelantar-hito-10-ci-antes-que-hito-9.md).

---

# Hito 11

## Modernización de instaladores

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Gate de calidad automatizado (CI), Compatibilidad con Ubuntu 26

**Corrección administrativa (2026-07-17):** se agrega Compatibilidad con Ubuntu 26 (Hito 9) como dependencia adicional — no tiene sentido estandarizar interfaces de instaladores antes de saber cuáles ya son compatibles con Ubuntu 26 y cuáles necesitan cambios reales primero.

**Corrección administrativa (2026-07-18):** una revisión técnica integral (`docs/TECHNICAL_REVIEW.md`, hallazgo Crítico C1) encontró que este objetivo citaba una lista de verbos ambigua, sin `uninstall`/`reinstall` con la misma prioridad que `update`/`repair`, mientras que 29 de 30 instaladores reales ya convergieron a `status/install/uninstall/reinstall` y solo `install_vim.sh` implementa el contrato completo. Se resolvió con [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md): `install_vim.sh` queda designado como instalador de referencia, y el objetivo de este hito se reformula abajo para citarlo explícitamente en vez de una lista de verbos suelta.

### Objetivo

Migrar los instaladores restantes (todos salvo `scripts/editors/install_vim.sh`, que ya es la referencia) hacia el contrato completo de 6 verbos que [ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md), [ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) y [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md) ya aprobaron:

* status (distinguiendo `INSTALLED`/`NOT_INSTALLED`/`OUTDATED`/`BROKEN`/`UNSUPPORTED`/`UNKNOWN`, no solo instalado/no instalado)
* install
* uninstall
* reinstall (acción avanzada explícita, nunca comportamiento por defecto)
* update (para el caso `OUTDATED`)
* repair (para el caso `BROKEN`)

Separar conceptualmente las acciones de mantenimiento de sistema (kernel, actualizaciones) de los instaladores de aplicaciones.

Cada instalador migrado en este hito debe subir a la vez al modo estricto de Bash exigido por [ADR 0008](adr/0008-bash-estricto-en-scripts-nuevos.md) (`set -Eeuo pipefail`), ya que ambos cambios tocan el mismo archivo.

### Criterios de aceptación

Comportamiento consistente entre instaladores, igualando el contrato de `install_vim.sh`.

### Decisiones relacionadas

[ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md) — separar mantenimiento de sistema de instaladores de aplicaciones.

[ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md) — `install_vim.sh` como instalador de referencia.

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
* hallazgos `warning`/`info` de ShellCheck preexistentes, descubiertos en la primera corrida real en CI (2026-07-17): SC2155/SC2034 en `scripts/lib/backup.sh` y `scripts/lib/logging.sh`, SC1091 (fuentes no resueltas, esperado), SC2016/SC2028/SC2162 en `setup.sh` y `scripts/migrations/001_nvm_to_mise.sh`. El CI (`.github/workflows/ci.yml`) solo gatea por severidad `error` por ahora; limpiarlos es una tarea separada, no bloqueante

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
