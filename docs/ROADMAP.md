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

Done

Depende de:

Gestor de runtimes

**Corrección administrativa (2026-07-17):** este hito estaba marcado `Blocked` pese a que su dependencia (Gestor de runtimes, Hito 8) ya está `Done`. Pasa a `In Progress` al iniciar la Fase A (auditoría e inventario, ver `docs/UBUNTU_COMPATIBILITY.md`).

**Avance de la Fase B (2026-07-17):** 9 de los 13 puntos de la prioridad de intervención ya están corregidos y probados, con evidencia real en CI (`system_utils`, `development_tools`, `multimedia`, `kubectl`→Mise, `Yarn`→Mise, Oh My Zsh/Powerlevel10k, ULauncher, `system_update`/`final_update`, Cursor→repo APT oficial, MongoDB Compass). Validar contra CI real (no solo revisión de código) encontró y corrigió 6 bugs adicionales que ninguna revisión estática hubiera detectado: `software-properties-common` ausente en la imagen (rompía el PPA de ULauncher), `gnupg` ausente (rompía la clave de Cursor en silencio), un conflicto de `Signed-By` entre la entrada manual y la que el propio paquete de Cursor gestiona, y `dpkg -s`/`dpkg -l` reportando estado incorrecto tras `apt remove` en dos scripts. Además se dividió el job `base` del CI (antes 11 scripts en serie, ~15-18 min) en 5 grupos paralelos, bajando el tiempo total a ~11 min. Quedan pendientes: Snap-dependientes (8 instaladores, no verificables sin `snapd` en Docker), Docker/VS Code (esperan evidencia real contra Ubuntu 26.04; VS Code además comparte el riesgo latente de `gnupg` ausente encontrado en Cursor, sin corregir todavía), `install_kernel.sh` (bug de fallback de nombres, alto riesgo, no probar en Docker), y la decisión de alcance sobre `install_chrome.sh` (arquitectura `amd64`). Este hito permanece en `In Progress`, no se marca `Done` mientras estos puntos sigan abiertos. Ver `docs/UBUNTU_COMPATIBILITY.md` para la matriz completa y evidencia por instalador. CI verde: [PR #3](https://github.com/jorgemparrah/ubuntu-commons-installer/pull/3).

**Cierre de brechas (2026-07-17):** resueltos los 4 puntos restantes de la Fase B. VS Code recibió los mismos fixes que Cursor (`gnupg` on-demand, keyring no vacío, `dpkg -l`, `apt purge`) y pasó su prueba funcional Docker (`tests/docker/test_vscode_apt_repo.sh`, V01) en ambas versiones de Ubuntu. Docker obtuvo evidencia real contra Ubuntu 26.04 real (`tests/docker/test_docker_apt_repo.sh`, D01): Docker Inc. publica `docker-ce` tanto para `noble` (24.04, candidato `5:29.6.2-1~ubuntu.24.04~noble`) como para `resolute` (26.04, candidato `5:29.6.2-1~ubuntu.26.04~resolute`), ambos instalados con éxito. `install_kernel.sh` corrigió el bug de fallback de nombres (`lsb_release -rs` en vez de `-cs`), cubierto por prueba unitaria de la función pura (`tests/test_kernel_hwe_fallback.sh`, I08) — la instalación real de un kernel sigue sin poder probarse automáticamente y requiere validación manual en VM. `install_chrome.sh` formalizó el alcance de arquitectura en una ADR nueva ([ADR 0028](adr/0028-arquitectura-soportada-amd64.md), `amd64` oficial, `arm64` alcance futuro) y ahora rechaza explícitamente con `UNSUPPORTED` en arquitecturas no soportadas en vez de arriesgar una descarga silenciosa incorrecta. Los 8 instaladores Snap recibieron una corrección de contrato (`check_status()` distingue `INSTALLED`/`NOT_INSTALLED`/`UNKNOWN` cuando `snapd` está ausente) con prueba simulada (`tests/test_snap_installers_contract.sh`, I10), más una pauta de validación manual para Ubuntu 26.04 Desktop documentada en `docs/TEST_CASES.md` y en `docs/UBUNTU_COMPATIBILITY.md` — **todavía sin ejecutar**. `docs/UBUNTU_COMPATIBILITY.md` ahora exige evidencia separada por versión de Ubuntu y por tipo de prueba para declarar `compatible`, con una tabla nueva ("Evidencia por versión de Ubuntu") de las 30 filas. CI verde 19/19 en el PR de cierre (`hito-9-cierre-brechas`). Este hito pasó a `Review` en este punto (no a `Done`): quedaban como validación manual pendiente la pauta de los 8 instaladores Snap en Ubuntu 26.04 Desktop real y la instalación real de un kernel HWE en VM; ninguna de las dos podía ejecutarse en CI ni en esta máquina de desarrollo.

**Cierre administrativo (2026-07-19):** se revisó toda la evidencia registrada (`docs/UBUNTU_COMPATIBILITY.md`, `docs/TEST_CASES.md`) y se confirmó que las **únicas** validaciones que siguen pendientes son las dos ya identificadas en el corte anterior — ninguna adicional apareció. Este hito pasa de `Review` a **`Done`**, dejando documentado explícitamente que:

* la pauta de validación manual de los 8 instaladores Snap (DBeaver, GitKraken, Insomnia, Postman, GIMP, OBS Studio, Spotify, Zoom) en un Ubuntu 26.04 Desktop real (VM o máquina física, con systemd y `snapd` reales) **sigue sin ejecutarse** — ver la pauta de 7 pasos en `docs/TEST_CASES.md` ("Validación manual pendiente: instaladores Snap en Ubuntu 26.04 Desktop") y en `docs/UBUNTU_COMPATIBILITY.md`;
* la instalación real de un kernel HWE (`install_kernel.sh`) en una VM o máquina de prueba dedicada **sigue sin ejecutarse** — solo existe evidencia de prueba unitaria de la función pura de resolución de nombres (`tests/test_kernel_hwe_fallback.sh`, I08), nunca una instalación real, ni un reinicio, ni verificación de que el sistema arranca con el kernel HWE resultante;
* ninguna de las dos debe interpretarse como una prueba ya ejecutada, ni la evidencia simulada/unitaria que sí existe hoy debe confundirse con evidencia funcional real — marcar este hito `Done` es un cierre administrativo de alcance (todo lo que puede probarse de forma automatizada ya se probó, en ambas versiones de Ubuntu, con evidencia real registrada), no una declaración de que el proyecto ya es una versión estable;
* ambas validaciones **deben realizarse antes de declarar una primera versión estable del proyecto** (ver `docs/RELEASES.md` y el criterio de éxito de `docs/ROADMAP.md`);
* si cualquiera de las dos validaciones manuales encuentra un fallo real, corresponde **reabrir este mismo hito** (volver a `In Progress` o `Review` según el alcance del hallazgo) y corregir el instalador o la matriz de compatibilidad correspondiente antes de continuar — no se documenta como una excepción aislada ni se difiere indefinidamente.

No se eliminó ninguna pauta manual ni se convirtió evidencia simulada en evidencia funcional: las tablas de `docs/UBUNTU_COMPATIBILITY.md` mantienen intactas sus clasificaciones `no verificable automáticamente` para Kernel & Headers y los 8 instaladores Snap. Con este cierre, el Hito 11 (Modernización de instaladores) pasa de `Blocked` a `In Progress`, iniciando su Fase 1 (infraestructura compartida) — ver la sección de ese hito más abajo.

### Objetivo

Auditar todos los instaladores y operaciones de mantenimiento existentes para determinar y asegurar su compatibilidad con Ubuntu 24.04 y Ubuntu 26.04. La modernización en volumen de las interfaces de los instaladores corresponde al Hito 11, no a este.

### Tareas

Revisar:

* repositorios
* nombres de paquetes
* comandos deprecados
* métodos de instalación

### Criterios de aceptación

Todos los instaladores soportados funcionan correctamente en Ubuntu 26, con evidencia individual por instalador (ver `docs/UBUNTU_COMPATIBILITY.md`). Cumplido con evidencia automatizada para 30/30 instaladores clasificados; las dos validaciones manuales pendientes (Snap en Ubuntu 26.04 Desktop, kernel HWE en VM) quedan documentadas explícitamente como condición previa a una primera versión estable (ver "Cierre administrativo" arriba), no como trabajo de este hito sin terminar.

**Cobertura experimental nueva para Snap (2026-07-20, [ADR 0039](adr/0039-snapd-en-docker-para-ci-experimental.md)):** se agregó un mecanismo experimental para correr `snapd` real dentro de Docker (`tests/docker/Dockerfile.snapd` + `tests/docker/run_snap_functional.sh`, systemd como PID 1 vía `--privileged --cgroupns=host`), con un job de CI separado (`snap-functional-experimental`, `continue-on-error: true`, I29). Es un patrón de la comunidad, no soportado oficialmente por Canonical/Snapcraft — **no reemplaza** la pauta de validación manual en Ubuntu 26.04 Desktop real de este hito, que sigue siendo la única fuente de verdad para marcar los 8 instaladores Snap como `compatible` hasta que ese job demuestre estabilidad sostenida en CI.

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

Done

Depende de:

Gate de calidad automatizado (CI), Compatibilidad con Ubuntu 26

**Cierre administrativo (2026-07-21, Hito 20):** funcionalmente completo desde hace varias sesiones (28 de 30 instaladores migrados al contrato de 6 verbos; los 2 restantes quedan fuera a propósito, ver "Estado de la modernización tras esta ronda" más abajo), pero nunca se había propuesto su cierre formal como `Done`. El dueño del proyecto confirmó cerrarlo al planificar el camino hacia la primera versión estable.

**Corrección administrativa (2026-07-17):** se agrega Compatibilidad con Ubuntu 26 (Hito 9) como dependencia adicional — no tiene sentido estandarizar interfaces de instaladores antes de saber cuáles ya son compatibles con Ubuntu 26 y cuáles necesitan cambios reales primero.

**Corrección administrativa (2026-07-18):** una revisión técnica integral (`docs/TECHNICAL_REVIEW.md`, hallazgo Crítico C1) encontró que este objetivo citaba una lista de verbos ambigua, sin `uninstall`/`reinstall` con la misma prioridad que `update`/`repair`, mientras que 29 de 30 instaladores reales ya convergieron a `status/install/uninstall/reinstall` y solo `install_vim.sh` implementa el contrato completo. Se resolvió con [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md): `install_vim.sh` queda designado como instalador de referencia, y el objetivo de este hito se reformula abajo para citarlo explícitamente en vez de una lista de verbos suelta.

**Inicio de la Fase 1 (2026-07-19):** con el Hito 9 cerrado administrativamente (`Done`, ver su propia sección arriba), este hito pasa de `Blocked` a `In Progress`. Se define un plan de fases pequeñas en vez de migrar los ~29 instaladores restantes de una sola vez (ver AGENT.md, "Cambios pequeños"). **Fase 1 — infraestructura compartida y un único piloto** (esta fase, cerrada en el mismo movimiento):

* `scripts/lib/installer_cli.sh` — dispatcher compartido de 6 verbos (`installer_run_cli`), reemplaza el bloque `main()`/`case` duplicado en ~29 instaladores. Funciones obligatorias (`check_status`/`install_tool`/`uninstall_tool`) verificadas con `declare -F` (sin `eval`); `reinstall_tool` opcional con fallback mecánico; `update_tool`/`repair_tool` opcionales sin fallback — si faltan, se rechazan explícitamente (código 3), nunca se redirigen en silencio a `reinstall`.
* `scripts/lib/apt.sh` — helpers APT compartidos (`apt_package_installed`, `apt_all_packages_installed`, `apt_install_packages`, `apt_purge_packages`), centralizando la detección `dpkg -l` por paquete puntual (nunca `dpkg -s` ni un `grep` sin anclar sobre la lista completa).
* `scripts/system/install_cmatrix.sh` — único instalador piloto migrado en esta fase, implementando los 6 verbos completos sobre la infraestructura compartida.
* Pruebas nuevas: `tests/test_installer_cli.sh` (I11), `tests/test_apt_helpers.sh` (I12), `tests/test_cmatrix_installer.sh` (I13) — validadas en CI en Ubuntu 24.04 y 26.04.

**No se migró ningún otro instalador en esta fase**, ni siquiera los otros 3 instaladores apt-simples (`install_ranger.sh`, `install_terminator.sh`, `install_flameshot.sh`) que comparten estructura casi idéntica con el piloto — eso corresponde a las fases siguientes (ver propuesta de agrupación en `docs/TECHNICAL_REVIEW.md`, hallazgo M6). Tampoco se tocaron `install_kernel.sh`, `install_system_update.sh` ni `install_final_update.sh`: son acciones de mantenimiento de sistema, no instaladores de aplicaciones (ver [ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md)), y se migran en un momento separado.

**Fase 2 — instaladores apt-simples (2026-07-19):** migrados los 3 instaladores identificados en la Fase 1 como el siguiente grupo natural: `install_ranger.sh`, `install_terminator.sh` e `install_flameshot.sh`. Los tres reutilizan la infraestructura de la Fase 1 sin modificarla (`scripts/lib/installer_cli.sh`, `scripts/lib/apt.sh`) e implementan los 6 verbos completos, con dos refinamientos nuevos que también aplicarán a las fases siguientes: `install` rechaza explícitamente sobre un estado `BROKEN` (pide `repair` en vez de reinstalar encima de una instalación corrupta), y `repair` rechaza explícitamente sobre `NOT_INSTALLED` (pide `install`). `reinstall` usa `apt-get install --reinstall` directo en vez del fallback mecánico del dispatcher (uninstall+install), para evitar el ciclo completo de purge+autoremove en paquetes con estado de sistema propio (por ejemplo, perfiles de Terminator bajo `/etc`). Flameshot: la migración cubrió únicamente la gestión del paquete — el atajo `PrintScreen` de [ADR 0019](adr/0019-flameshot-atajo-printscreen.md) nunca se implementó (confirmado ya en el Hito 9) y sigue quedando registrado como trabajo posterior claramente delimitado, no como parte de esta fase. Pruebas nuevas: `tests/test_ranger_installer.sh` (I14), `tests/test_terminator_installer.sh` (I15), `tests/test_flameshot_installer.sh` (I16), validadas en CI en Ubuntu 24.04 y 26.04. No se extendieron `installer_cli.sh` ni `apt.sh`: la infraestructura de la Fase 1 cubrió los tres instaladores sin cambios. No se migró ningún instalador adicional; no se avanzó al Hito 12.

**Infraestructura de registro central, previa a la Fase 3 (2026-07-19):** antes de seguir migrando instaladores en volumen, una auditoría de los 30 instaladores existentes (modernizados y heredados) encontró que los mismos hechos sobre cada herramienta (categoría, mecanismo de instalación, arquitecturas soportadas, validación manual, entorno gráfico, estado de migración) vivían dispersos y divergiendo en 5 lugares distintos (`docs/TOOLS.md`, `docs/UBUNTU_COMPATIBILITY.md`, `docs/TEST_CASES.md`, la prosa de este roadmap, y el array `tools` de `setup.js`), sin que ningún instalador declarara esa metadata de forma estructurada. Se resolvió con [ADR 0030](adr/0030-registro-central-de-metadata-de-instaladores.md): un catálogo en Bash puro (sin YAML/JSON ni dependencias externas), modelado sobre el patrón ya aceptado de `UCI_RUNTIME_CATALOG` (`scripts/lib/runtime.sh`, Hito 8). Se agregaron `scripts/lib/tools_registry.sh` (el mecanismo: `tools_registry_register`/`tools_registry_has`/`tools_registry_ids`/`tools_registry_field`) y `scripts/lib/tools_catalog.sh` (los datos, registrando inicialmente únicamente `cmatrix` y `ranger` como validación mínima del diseño). Prueba nueva: `tests/test_tools_registry.sh` (I17), que valida el mecanismo con fixtures y cruza cada entrada del catálogo contra el archivo real (el script declarado existe; si `manager=apt`, el script sourcea `scripts/lib/apt.sh`; si `migration_status=migrated`, usa `installer_run_cli`), validada en CI en Ubuntu 24.04 y 26.04. Puramente aditivo: no se sourcea desde `setup.sh`/`setup.js`, no reemplaza el array `tools` existente, no cambia el comportamiento de ningún instalador ni del dispatcher/helpers compartidos. No se avanzó al Hito 12.

**Separación de instaladores multi-paquete + primer consumidor del catálogo (2026-07-19):** los 3 instaladores que bandeaban varios paquetes no relacionados (`install_development_tools.sh`, `install_multimedia.sh`, `install_system_utils.sh`, hallazgo M6 de `docs/TECHNICAL_REVIEW.md`) se separaron en 14 instaladores individuales migrados directamente al contrato completo de 6 verbos, manteniendo los 3 archivos originales como agrupadores delgados que delegan `status`/`install`/`uninstall` en sus miembros y rechazan explícitamente `update`/`repair` a nivel de grupo (ver [ADR 0031](adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md)). Los 14 instaladores y los 3 agrupadores se registraron en `tools_catalog.sh` (agrupadores distinguidos con `kind=group`/`members`). Pruebas nuevas: `tests/test_split_installers_contract.sh` (I18, ciclo de vida completo de los 14 instaladores individuales) y una reescritura de `tests/test_system_utils_contract.sh` (I01-I04, ahora prueba la delegación de los 3 agrupadores hacia sus miembros). Con el catálogo ya cubriendo 19 herramientas, se construyó su primer consumidor real: `tests/test_tools_catalog_docs_consistency.sh` (I19) confirma que `docs/TOOLS.md` no diverge de lo registrado en `tools_catalog.sh` — si un instalador se registra sin documentarse, esta prueba falla. `docs/TOOLS.md` se actualizó con las 3 filas de agrupadores y las nuevas filas de instaladores individuales; `setup.js` no cambió (las 3 opciones de menú siguen existiendo, delegando internamente). No se migró ningún instalador adicional fuera de este grupo; no se avanzó al Hito 12.

**Registro de instaladores ya migrados + siguiente grupo apt-simple (2026-07-19):** `vim`, `terminator` y `flameshot` ya implementaban el contrato objetivo pero nunca se habían registrado en el catálogo — se agregaron sin tocar su código (`vim` queda con `migration_status=legacy`, distinguiendo "implementa los 6 verbos" de "usa `installer_cli.sh`/`apt.sh`", ver ADR 0030). Luego se migró `install_ulauncher.sh` (el único instalador apt-simple restante fuera de las categorías Snap/Mise/vendor-repo/deb-directo/git-clone ya cubiertas) al contrato completo, con una diferencia real respecto a los apt-simples anteriores: agrega/quita su propio PPA (`ppa:agornostal/ulauncher`) en `install`/`uninstall`, registrado con `manager=apt-vendor-repo`. Prueba nueva: `tests/test_ulauncher_installer.sh` (I20, mocks del contrato de 6 verbos, incluyendo el PPA) — complementa, sin reemplazar, la prueba funcional real ya existente (`tests/docker/test_ulauncher_ppa.sh`, L01). No quedan más instaladores apt-simples de un solo paquete sin migrar; los candidatos restantes (Snap, Mise, vendor-repo, deb-directo, git-clone) requieren su propio criterio de migración, no el de este grupo.

Con el catálogo cubriendo ya las herramientas migradas de mayor visibilidad (menú de `setup.js`), se construyó su segundo consumidor real: `tests/test_tools_catalog_setup_js_consistency.sh` (I21) confirma que cada herramienta registrada que el menú debería ofrecer (agrupadores y herramientas independientes, excluyendo miembros internos de un agrupador) tiene una entrada real en `setup.js` — si se registra una herramienta en el catálogo sin ofrecerla en el menú (o viceversa), esta prueba falla. No se avanzó al Hito 12.

**Grupo Snap (2026-07-19):** migrados al contrato completo de 6 verbos los 8 instaladores basados en Snap (DBeaver, GitKraken, Insomnia, Postman, GIMP, OBS Studio, Spotify, Zoom), usando `scripts/lib/installer_cli.sh` más una biblioteca nueva, `scripts/lib/snap.sh` (hermana de `apt.sh` para este mecanismo: `snap_available`, `snap_package_installed`, `snap_install_package`, `snap_remove_package`). `status` sigue distinguiendo snapd ausente (`UNKNOWN`) de "no instalado" (`NOT_INSTALLED`), como ya lo hacía cada instalador antes de esta migración — pero no distingue `OUTDATED`, porque eso requeriría consultar la store de Snap por red (`snap refresh --list`), violando que `status` debe ser liviano; `update` sigue existiendo como verbo explícito (`snap refresh`). `repair` no se implementa: un snap es una imagen autocontenida, sin el concepto de instalación parcial que justifica `repair` en APT — el dispatcher lo rechaza explícitamente. Los 8 se registraron en `tools_catalog.sh` (`manager=snap`, `requires_manual_validation=yes`, ya que snapd no corre sin systemd en los contenedores Docker de este proyecto). Prueba nueva: `tests/test_snap_installers_full_contract.sh` (I22, ciclo de vida completo con mocks), que complementa sin reemplazar a `tests/test_snap_installers_contract.sh` (I10, ya cubría `status`). No se avanzó al Hito 12.

**Corrección (2026-07-20, [ADR 0038](adr/0038-obs-studio-migra-de-snap-a-ppa-oficial.md)):** revisando la nota pendiente "verificar fuente deseada" que GIMP y OBS Studio arrastraban desde el Hito 9 en `docs/TOOLS.md`, se confirmó GIMP (Snap ya sigue la versión más nueva en ambas LTS) y se migró OBS Studio de Snap a su PPA oficial (`ppa:obsproject/obs-studio`) — el snap está etiquetado "unofficial" por el propio OBS Project. `install_obs_studio.sh` pasa a `manager=apt-vendor-repo` (mismo patrón que `install_ulauncher.sh`, vía `add-apt-repository`), `requires_manual_validation` pasa de `yes` a `no` (ya no depende de `snapd`), y se retira de `tests/test_snap_installers_contract.sh`/`tests/test_snap_installers_full_contract.sh` (grupo Snap: 9 → 8) con un contrato mockeado propio nuevo (`tests/test_obs_studio_installer.sh`, I28).

**Grupo vendor-repo (2026-07-19):** migrados al contrato completo de 6 verbos los 3 instaladores que agregan su propio repositorio APT oficial de proveedor (Docker, VS Code, Cursor), usando `scripts/lib/installer_cli.sh` + `scripts/lib/apt.sh` más una biblioteca nueva, `scripts/lib/apt_vendor_repo.sh` (hermana de `apt.sh`/`snap.sh` para este mecanismo: descarga/verificación de la clave GPG en sus dos variantes —`gpg --dearmor` para VS Code/Cursor, clave ya lista para Docker— y escritura del archivo `.list`). No se cambió ningún paquete, flag, URL de clave ni ruta de keyring/repo respecto a la versión previa — cero cambio de comportamiento funcional, solo se agregaron `update`/`repair` (antes solo tenían `status/install/uninstall/reinstall`) y `status` ahora distingue `BROKEN` además de `NOT_INSTALLED`/`INSTALLED`/`OUTDATED`. Los 3 se registraron en `tools_catalog.sh` (`manager=apt-vendor-repo`, `requires_manual_validation=no`: a diferencia del grupo Snap, ya tenían prueba funcional real en CI). Las 3 pruebas funcionales reales existentes (`tests/docker/test_docker_apt_repo.sh`/`test_vscode_apt_repo.sh`/`test_cursor_apt_repo.sh`, casos D01/V01/C01) se extendieron con escenarios de `update`/`reinstall`/`repair`, sin reemplazar su cobertura previa. Con esto, los 3 grupos acordados (Snap → vendor-repo → Mise) tienen a Mise (kubectl, Yarn) como último pendiente. No se avanzó al Hito 12.

**Grupo Mise (2026-07-20):** migrados `install_kubectl.sh` e `install_yarn.sh` al dispatcher compartido (`scripts/lib/installer_cli.sh`), sin tocar `scripts/lib/runtime.sh` (Hito 8) — ya usaban Mise para instalar/desinstalar, solo faltaba adoptar el dispatcher común en vez de su propio `main()`/`case`. `reinstall` dejó de tener función propia (el fallback mecánico del dispatcher ya era lo que ambos hacían a mano); se agregó `update` (vuelve a pedir `latest` vía Mise); `repair` no se implementa (Mise no tiene el concepto de instalación parcial que lo justifique). Registrados en `tools_catalog.sh` (`manager=mise`). Las pruebas funcionales reales ya existentes (`tests/docker/test_kubectl_via_mise.sh`/`test_yarn_via_mise.sh`, K01/Y01) se extendieron con escenarios de `update`/`reinstall`/`repair`. **Con este grupo se completan los 3 acordados con el dueño del proyecto (Snap → vendor-repo → Mise) para esta ronda de migraciones del Hito 11.** No se avanzó al Hito 12.

**Grupo deb-directo (2026-07-20):** migrados `install_chrome.sh` e `install_mongodb_compass.sh` (los 2 instaladores que descargan un `.deb` directo en vez de agregar un repositorio APT) al contrato completo, usando `scripts/lib/installer_cli.sh` + `scripts/lib/apt.sh` más una biblioteca nueva, `scripts/lib/deb_direct.sh` (hermana de `apt.sh`/`snap.sh`/`apt_vendor_repo.sh`: descarga con verificación explícita de que el `.deb` no quedó vacío; la instalación reutiliza `apt_install_packages` de `apt.sh` sin necesitar un helper propio). Se agregaron `update`/`repair`; `status` ahora distingue `BROKEN`/`OUTDATED`; `reinstall` usa el fallback mecánico del dispatcher (igual que antes, descargar de nuevo). Chrome conserva su verificación de arquitectura (ADR 0028) sin cambios. Registrados en `tools_catalog.sh` (`manager=deb-direct`). Prueba nueva: `tests/test_deb_direct_full_contract.sh` (I23, ciclo de vida completo con mocks), que complementa a `tests/test_chrome_arch_check.sh` (I09) y `tests/test_mongodb_compass_download.sh` (I07) — ambos ajustados para mockear `apt-get` además de `apt`. No se avanzó al Hito 12.

**Grupo git-clone (2026-07-20):** migrados `install_oh_my_zsh.sh` e `install_powerlevel10k.sh` al contrato completo, usando `scripts/lib/installer_cli.sh` + `scripts/lib/apt.sh` más una biblioteca nueva, `scripts/lib/git_clone.sh`. Antes de migrar se leyó el código de ambos para confirmar su mecanismo real (pedido explícito del dueño del proyecto): al contrario de lo que "Oh My Zsh" podría sugerir, ninguno de los dos corre el script oficial `curl | sh` — ambos ya clonaban su repositorio directamente con `git clone --depth=1` desde el Hito 9, precisamente para no tocar `.zshrc`/el shell por defecto al reutilizar `/home` (ADR 0021). Tampoco requirieron separación previa (a diferencia de ADR 0031): cada uno instala un único paquete compartido (`zsh`) más un solo directorio clonado, no varios paquetes no relacionados bandeados. `status` ahora distingue `BROKEN` (directorio presente pero sin `.git`, un clon interrumpido); `update` corre `git pull --ff-only`; `repair` reclona sobre un directorio corrupto; `reinstall` usa el fallback mecánico del dispatcher. Único cambio de comportamiento real: `uninstall` pasó de `apt remove` a `apt purge` (vía `apt.sh`), alineándose con el resto del proyecto — riesgo bajo, `zsh` no tiene configuración de usuario gestionada por este proyecto. Registrados en `tools_catalog.sh` (`manager=git-clone`). La prueba funcional real ya existente (`tests/docker/test_zsh_personalization.sh`, Z01) se extendió con `update`/`reinstall`/`repair`. No se avanzó al Hito 12.

**Grupo mantenimiento (2026-07-20):** último grupo acordado en esta ronda. Antes de migrar, se detectó una ambigüedad real y se resolvió con el dueño del proyecto en vez de asumir (ver ADR 0013): `install_system_update.sh`/`install_final_update.sh` son acciones de mantenimiento de una sola vía (actualizar/limpiar el sistema) sin un "desinstalar" con sentido, y ambos ya tenían un bug real donde `uninstall` salía con código 0 sin hacer nada. Decisión: migrar solo `status`/`install` al dispatcher compartido, rechazando `uninstall`/`reinstall`/`update`/`repair` explícitamente (código distinto de cero) en vez de forzar el contrato completo de ADR 0029 donde no aplica, o mantener el bug de éxito silencioso. `install_kernel.sh`, en cambio, sí tiene un `install`/`uninstall` con sentido real y mantiene los 6 verbos; aprovechando la migración se corrigió que `install` upgradeaba automáticamente sobre un kernel ya instalado (contradecía ADR 0004) — esa lógica se separó a `update_tool`. Los 3 se registraron en `tools_catalog.sh` con `kind=maintenance`. Prueba existente extendida: `tests/test_system_update_contract.sh` (I05) confirma el rechazo explícito de los 4 verbos no soportados; `tests/test_kernel_hwe_fallback.sh` (I08) mantiene su restricción histórica de nunca invocar funciones de instalación real, ni con mocks — la nueva separación install/update del kernel queda sin cobertura automatizada a propósito, mismo criterio de alto riesgo. **Con este grupo se completan los 6 acordados en esta ronda de migraciones del Hito 11** (Snap, vendor-repo, Mise, deb-directo, git-clone, mantenimiento). No se avanzó al Hito 12.

**Estado de la modernización tras esta ronda (2026-07-20):** de los 30 instaladores clasificados, 28 ya usan `scripts/lib/installer_cli.sh` (con excepciones documentadas donde `update`/`repair`/`uninstall` no aplican, siempre rechazadas explícitamente en vez de en silencio). Quedan exactamente 2 fuera, ambos intencionalmente: `scripts/editors/install_vim.sh` (instalador de referencia del contrato, ver ADR 0029 — el objetivo de este hito lo excluye explícitamente) e `install_nodejs.sh` (legado congelado a propósito desde el Hito 7, sin entrada en el menú, todas sus acciones rechazan permanentemente). No se propone cerrar el Hito 11 como `Done` todavía en este movimiento — queda para una decisión explícita posterior.

**Tercer consumidor del catálogo (2026-07-20):** con 43 herramientas ya registradas en `tools_catalog.sh`, se construyó un tercer consumidor real: `tests/test_tools_catalog_ubuntu_compatibility_consistency.sh` (I24) valida que `docs/UBUNTU_COMPATIBILITY.md` no contradiga el campo `requires_manual_validation` del catálogo (si el catálogo dice que ya hay evidencia automatizada suficiente pero la matriz sigue diciendo "no verificable automáticamente", o viceversa, la prueba falla). No exige fila propia para toda entrada del catálogo todavía — varios de los 14 instaladores individuales de ADR 0031 no tienen fila en esa matriz; expandirla fila por fila queda como deuda de documentación separada, no como parte de esta prueba (que sí valida sin contradicción las entradas que ya tienen fila, y hoy pasa sin ninguna).

**Corrección administrativa (2026-07-20, [ADR 0035](adr/0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md)):** al revisar el catálogo completo (49 entradas) para mejorar su categorización, se detectó que `category=system` había crecido de forma ad-hoc hasta concentrar más de la mitad de las herramientas (utilidades CLI, terminales, personalización de shell, apps GUI, mantenimiento y los 3 agrupadores mezclados sin estructura). El dueño del proyecto pidió eliminar los 3 agrupadores delgados de ADR 0031 (`install_development_tools.sh`/`install_multimedia.sh`/`install_system_utils.sh`, junto con sus registros en el catálogo, su prueba `tests/test_system_utils_contract.sh` y sus 3 entradas de menú) y exponer directamente los 14 instaladores individuales que ya existían, reclasificándolos con un campo nuevo `subcategory` (`cli-utils`/`terminals`/`shell-personalization`/`gui-utils`/`misc`) sin agregar un comando ni cambiar la estructura de menú de `setup.js` (que sigue usando solo `category`). De paso se corrigió que `install_system_update.sh`/`install_kernel.sh` tenían `category=system` pese a ser `kind=maintenance`, inconsistente con `install_final_update.sh`; los 3 quedan en `category=maintenance`. También se había reservado `category=ai-tools` (subcategorías `ai-cli`/`ai-desktop`) para cuando se implementen las candidatas de IA del Hito 16 — corregido el mismo día por [ADR 0036](adr/0036-candidatas-de-ia-en-categorias-existentes.md): en vez de una categoría nueva, las 7 candidatas se distribuyen entre `editors`/`development`/`productivity` según su función real (ver Hito 16 más abajo), sin registrar nada todavía. Esta reversión no afecta la decisión de fondo de ADR 0031 (separar en instaladores individuales); solo revierte la parte de "agrupador delgado para no romper el menú", que dejó de tener sentido una vez confirmado que ningún flujo dependía de mantener exactamente 3 opciones de menú.

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

## Ampliación del catálogo: terminales y gestores de archivos nuevos (2026-07-20)

Fuera del alcance de este hito (no es una migración, son 5 herramientas nuevas pedidas explícitamente por el dueño del proyecto): `nnn`, `lf`, Yazi, WezTerm y Ghostty, todas terminales/gestores de archivos de terminal. Se investigó el mecanismo oficial de cada una antes de escribir código (ver `docs/adr/0032-mecanismo-condicional-por-version-de-ubuntu.md`).

- `nnn`/`lf`: apt-simple directo, ya están en los repositorios oficiales de Ubuntu (universe).
- Yazi: snap oficial del proyecto (`--classic`); se agregó a los tests existentes del grupo Snap (I10/I22, que pasaron de 8 a 9 instaladores) en vez de duplicar un test nuevo.
- WezTerm: repositorio APT propio en Fury.io (`apt.fury.io/wez`, signed-by), un repo "flat" sin codename — primera vez que este proyecto usa esa variante de repo de proveedor. Prueba funcional real nueva (`tests/docker/test_wezterm_apt_repo.sh`, W01), mismo criterio que Docker/VS Code/Cursor.
- Ghostty: su mecanismo depende de la versión de Ubuntu (repositorio oficial en 26.04+, PPA `mkasberg/ghostty-ubuntu` en 24.04) — primer instalador de este proyecto que decide su mecanismo según la versión detectada en tiempo de ejecución, documentado en [ADR 0032](adr/0032-mecanismo-condicional-por-version-de-ubuntu.md). No se generalizó un helper compartido para esto: es un caso aislado, esperar un segundo caso real antes de abstraerlo.

Los 5 se registraron en `tools_catalog.sh` desde el primer commit (no hubo un "instalador legacy" previo que migrar). No se avanzó al Hito 12.

---

# Hito 12

## Framework de validación

**Prioridad**

Media

**Estado**

Done

Depende de:

Modernización de instaladores (Hito 11)

**Cierre administrativo (2026-07-21, Hito 20):** los 5 chequeos del framework de validación ya están implementados dentro de `doctor` desde 2026-07-20 (ver "Implementación" más abajo); el dueño del proyecto confirmó cerrarlo como `Done` al planificar el camino hacia la primera versión estable.

**Corrección administrativa (2026-07-20):** el Hito 11 sigue formalmente en `In Progress` (decisión explícita del dueño del proyecto: no se propuso su cierre como `Done`, ver su propia sección), pero la dependencia real de este hito — que los instaladores estén modernizados — ya está cumplida en la práctica: 28 de 30 están migrados al contrato de 6 verbos, y los 2 restantes quedan fuera a propósito (`install_vim.sh` es el instalador de referencia del contrato, `install_nodejs.sh` es legado congelado sin acciones activas), no por trabajo pendiente. El dueño del proyecto confirmó reinterpretar la dependencia como cumplida y pasar este hito de `Blocked` a `In Progress`.

### Objetivo

Verificar la integridad de la workstation.

### Tareas

Validar:

* PATH
* ejecutables
* dependencias
* symlinks
* versiones de runtime

**Implementación (2026-07-20):** confirmado con el dueño del proyecto que este framework es una **extensión de `doctor`** (`scripts/diagnostics/doctor.sh`), no un comando nuevo — los 5 chequeos se agregan a la salida estándar de `setup.sh doctor`, siempre visibles (sin flag propia), bajo un encabezado `-- Framework de validación (Hito 12) --`:

* **PATH** (`doctor_check_path`): cuenta entradas vacías/duplicadas y confirma si `~/.local/bin` (bin de Mise) está en el PATH.
* **Ejecutables** (`doctor_check_executables`): recorre `tools_catalog.sh` (`tools_registry_ids`/`tools_registry_field`) y confirma que cada script registrado exista y tenga el bit `+x` — el mismo tipo de bug real detectado durante la migración de terminales nuevas (5 instaladores quedaron sin `+x`, rompiendo `setup.js` porque invoca los scripts directamente sin `bash`). `--verbose` detalla cuáles fallan.
* **Dependencias compartidas** (`doctor_check_shared_dependencies`): confirma presencia de `curl`/`gpg`/`add-apt-repository`, que varios `scripts/lib/*.sh` (vendor-repo, deb-direct) dan por sentadas sin chequearlas ellos mismos.
* **Symlinks rotos** (`doctor_check_broken_symlinks`): detecta symlinks colgantes (`find -xtype l`) en `$HOME`, relevante al reutilizar un `/home` existente (ADR 0021). Limitado a profundidad 4 y excluye `.cache`/`.npm`/`node_modules` para seguir siendo liviano en un `$HOME` real. `--verbose` detalla las rutas.
* **Versiones de runtime**: reutiliza `runtime_status_all` (`scripts/lib/runtime.sh`, ya existente desde el Hito 8) sin duplicar lógica — no se escribió un chequeo nuevo para esto.

No se agregó ninguna flag nueva ni comando nuevo: `doctor` sigue siendo un único reporte completo, solo lectura, nunca modifica el sistema (mismo criterio que el resto de `doctor.sh`).

### Entregables

Módulo de validación — implementado como 5 chequeos nuevos dentro de `scripts/diagnostics/doctor.sh`, sin comando nuevo. Prueba extendida: `tests/test_doctor.sh` (U05, ver `docs/TEST_CASES.md`).

---

# Hito 13

## Perfiles

**Prioridad**

Media

**Estado**

Done

Depende de:

Framework de validación (Hito 12)

**Cierre administrativo (2026-07-21, Hito 20):** los 11 perfiles y los comandos `install --profile`/`list`/`info` ya están implementados y probados desde 2026-07-20/21 (ver "Implementación" y "Comandos de consulta del catálogo" más abajo); el dueño del proyecto confirmó cerrarlo como `Done` al planificar el camino hacia la primera versión estable. El único ítem que quedaba en "Pendiente" era trabajo futuro opcional (perfiles adicionales si surge la necesidad), no un requisito de cierre.

**Corrección administrativa (2026-07-20):** el Hito 12 sigue formalmente en `In Progress` (no se propuso su cierre como `Done`), pero la dependencia real (framework de validación funcionando) ya está cumplida en la práctica — los 5 chequeos ya están implementados en `doctor`. El dueño del proyecto confirmó reinterpretar la dependencia como cumplida y pasar este hito de `Blocked` a `In Progress`, mismo criterio ya usado entre los Hitos 11→12.

### Objetivo

Soportar perfiles de instalación.

### Clasificación `required`/`optional` completada (2026-07-20)

Antes de definir `minimal` (que depende de qué es indispensable), se completó la clasificación `required`/`optional` de las 53 herramientas del catálogo — solo 7 tenían una etiqueta explícita hasta ahora. Confirmado con el dueño del proyecto:

* **`required` (10):** wget, curl, Git, build-essential, software-properties-common, apt-transport-https, Google Chrome, System Updates, Kernel & Headers, Final System Update.
* **`optional` (43):** el resto del catálogo — incluye una reclasificación explícita: GitKraken, ULauncher, cmatrix y Ranger habían quedado `required` en una clasificación anterior (2026-07-20, sesión previa); el dueño del proyecto confirmó pasarlos a `optional` en esta revisión completa. GnuPG queda `optional` a propósito (no forma parte del grupo `required` pese a compartir subcategoría `cli-utils` con el resto).
* Campo nuevo en el catálogo: `classification=required|optional` (`scripts/lib/tools_catalog.sh`), mismo mecanismo sin esquema forzado que `kind`/`subcategory` (ADR 0030).

### Implementación (2026-07-20)

* Campo nuevo `profiles=<lista separada por coma>` en `tools_catalog.sh`: cada herramienta declara a qué perfiles pertenece. **No** se calcula en tiempo de ejecución — se computó una vez por regla y se guardó como dato, igual que el resto de los campos del catálogo.
* **11 perfiles**, iterados con el dueño del proyecto hasta esta versión final:
  * **minimal** — las 10 `classification=required` (sin filtrar por `requires_gui`: Chrome es `required` y tiene GUI, así que "sin GUI" no podía ser parte de la regla de `minimal`).
  * **cli** — todo el catálogo con `requires_gui=no` (más amplio que `minimal`: incluye `optional` también). Pedido explícito del dueño del proyecto ("un perfil para solo línea de comandos").
  * **desktop** — minimal + `category` productivity/multimedia/editors.
  * **developer** — minimal + `category` development/editors.
  * **workstation** — unión de desktop y developer.
  * **full** — las 53 herramientas.
  * **creator** — minimal + `category=multimedia`.
  * **productivity** — minimal + `category=productivity`.
  * **coding** — minimal + `category=development` (sin editores, a diferencia de `developer`).
  * **editor** — minimal + `category=editors`.
  * **ai-cli** — solo `subcategory=ai-cli` (Claude Code, Codex CLI, OpenCode, Antigravity CLI) — **sin** los agentes de escritorio (`ai-agent`), pedido explícito del dueño del proyecto para distinguir asistentes de terminal de agentes de propósito general.
* Comando nuevo, Bash puro (consistente con [ADR 0001](adr/0001-bootstrap-bash-sin-node.md)): `setup.sh install --profile <nombre>`. Recorre el catálogo, instala cada herramienta cuyo campo `profiles` incluya el perfil pedido, respetando la idempotencia de [ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md) (corre `status` antes de cada `install`, omite lo ya instalado).
* **`--profile custom`** (o sin `--profile`): delega en el flujo interactivo existente (`main_setup`/`setup.js`), que ya permite elegir herramienta por herramienta con checkboxes — no hizo falta un modo nuevo, el checklist ya existía.
* Prueba nueva: `tests/test_install_profile.sh` (I30), mocks de `curl` sobre el perfil `ai-cli` (las 4 únicas herramientas que comparten el mismo mecanismo `curl-script`, ver ADR 0037) — perfil desconocido, instalación de las 4, e idempotencia en una segunda corrida.

### Comandos de consulta del catálogo (2026-07-21)

Pedido explícito del dueño del proyecto: exponer la metadata del catálogo directamente, sin tener que abrir `tools_catalog.sh`.

* `setup.sh list [--profile <nombre>]` — tabla con ID/nombre/categoría-subcategoría/clasificación/mecanismo/perfiles de cada herramienta. Puramente lectura de datos: no ejecuta ningún script.
* `setup.sh info [--profile <nombre>]` — igual que `list`, agregando una columna `ESTADO` con el resultado real de `status` de cada herramienta filtrada. Más lento (invoca un proceso por herramienta), consistente con que `doctor`/`install --profile` ya asumen ese costo cuando corresponde.
* Ambos aceptan el mismo filtro `--profile` que `install`, reutilizando el campo `profiles` del catálogo — sin filtro, muestran las 54 herramientas.
* Prueba nueva: `tests/test_list_info_commands.sh` (I31) — `list` se prueba directo contra el catálogo real (sin mocks, no ejecuta nada); `info --profile ai-cli` reutiliza el mock de `curl` de I30.

### Pendiente

* Ninguno funcional. Posible trabajo futuro: perfiles adicionales si surge la necesidad (por ejemplo, uno específico para utilidades GUI de sistema o para terminales/shell, descartados en esta ronda a favor de combinaciones con `minimal`).

---

# Hito 14

## Arquitectura de plugins

**Prioridad**

Media

**Estado**

Done

Depende de:

Perfiles (Hito 13)

### Objetivo

Convertir los instaladores en plugins descubribles.

Ejemplo original considerado (no implementado, ver "Cierre" abajo):

```
docker/

metadata.yaml

install.sh

update.sh

repair.sh

status.sh
```

### Cierre (2026-07-21, [ADR 0040](adr/0040-cerrar-hito-14-via-tools-catalog.md))

El objetivo de fondo de este hito — metadata centralizada y descubrible para los instaladores, sin duplicación entre `setup.js` y cada script — ya se cumplió desde el Hito 11 vía `scripts/lib/tools_catalog.sh` ([ADR 0030](adr/0030-registro-central-de-metadata-de-instaladores.md)), con 3 consumidores automatizados (I19/I21/I24) que impiden que `docs/TOOLS.md`/`setup.js`/`docs/UBUNTU_COMPATIBILITY.md` diverjan del catálogo. "Descubrible" también se cumple hoy sin directorios separados: `tools_registry_ids()`/`tools_registry_field()` ya permiten recorrer/consultar cualquier herramienta mecánicamente (usado por `doctor_check_executables` del Hito 12 y `profile_installer_run` del Hito 13).

Se cierra el hito **sin** reescribir los 53 instaladores existentes a la estructura de directorios del ejemplo original: esa reescritura no resolvería nada que el catálogo no resuelva ya, y contradice el principio de "cambios pequeños, evitar reescrituras grandes" (`AGENT.md`, sección 2). Ver ADR 0040 para el análisis completo.

### Decisión relacionada

[ADR 0009](adr/0009-postergar-arquitectura-de-plugins.md) — postergada hasta este punto del roadmap (su decisión de postergar en su momento fue correcta, no se reemplaza). [ADR 0040](adr/0040-cerrar-hito-14-via-tools-catalog.md) — cierre de este hito documentando cómo se resolvió el problema de fondo por otra vía.

---

# Hito 15

## Documentación

**Prioridad**

Continua

### Tareas

Mantener la documentación sincronizada.

Una vez aceptada la nueva arquitectura, acortar el `README.md` raíz a propósito, inicio rápido, seguridad y enlaces a `docs/`; mover los detalles de implementación a `docs/`; asegurar que los ejemplos no prometan idempotencia hasta que esté implementada. **Hecho el 2026-07-21, ver Hito 23** — el `README.md` quedó acortado a inicio rápido/seguridad/enlaces, con el detalle de instaladores/perfiles/estructura del repo movido a `docs/ARCHITECTURE.md` y `docs/TOOLS.md` (ya lo tenían).

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

# Hito 16

## GitHub CLI vía Mise y candidatas de IA

**Prioridad**

Media

**Estado**

Done

Depende de:

Modernización de instaladores (Hito 11) — reutiliza `scripts/lib/installer_cli.sh` sin cambiarlo. No depende de los Hitos 12-15 (Framework de validación, Perfiles, Arquitectura de plugins, Documentación): mismo criterio de reordenamiento ya usado para adelantar el Hito 10 (ver [ADR 0026](adr/0026-adelantar-hito-10-ci-antes-que-hito-9.md)).

Nota: los 5 instaladores de terminal (`nnn`, `lf`, Yazi, WezTerm, Ghostty) que originaron esta investigación ya fueron implementados, registrados en `tools_catalog.sh` y mergeados a `main` — ver "Ampliación del catálogo: terminales y gestores de archivos nuevos (2026-07-20)" al cierre del Hito 11. No forman parte del alcance pendiente de este hito.

### Objetivo

Agregar al catálogo el CLI oficial de GitHub, y dejar registrado un inventario investigado (mecanismo oficial de instalación por herramienta) de asistentes/CLIs de IA candidatos, sin implementarlos todavía hasta que se confirme su clasificación `required/optional/candidate`.

### Tareas

**`gh` (GitHub CLI) — implementado:**

* Decisión: se instala vía **Mise** (`manager=mise`, igual que `kubectl` y Yarn), no vía apt, aunque también está en el repositorio oficial de Ubuntu (`universe`, confirmado en 24.04 y 26.04) — decisión explícita del dueño del proyecto que amplía el rol de Mise más allá de runtimes. Ver [ADR 0033](adr/0033-mise-amplia-su-rol-a-clis-via-registry.md) y [ADR 0034](adr/0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md) (corrige el valor de `manager` propuesto originalmente).
* `install_gh.sh` reutiliza `scripts/lib/runtime.sh` sin cambiarlo — mismo patrón exacto que `install_kubectl.sh`/`install_yarn.sh`, no hizo falta una biblioteca nueva.

**Candidatas de IA — implementadas (2026-07-20):**

* Mecanismo nuevo `manager=curl-script` (`scripts/lib/curl_script.sh`, ver [ADR 0037](adr/0037-mecanismo-curl-script-para-clis-de-ia.md)): descarga el script oficial a un archivo temporal y lo ejecuta con `bash`/`sh` (equivalente a `curl \| bash`, pero mockeable en pruebas). `check_status` vía `command -v`; `uninstall` remueve el binario de `~/.local/bin` (única ruta documentada, estos proveedores no publican un `uninstall` oficial); `update`/`repair` se rechazan a propósito; `reinstall` usa el fallback mecánico del dispatcher.
* `install_claude_code.sh`, `install_codex_cli.sh`, `install_opencode.sh` — CLIs de desarrollo `required`, `manager=curl-script`, `category=development`/`subcategory=ai-cli` (ver [ADR 0036](adr/0036-candidatas-de-ia-en-categorias-existentes.md)).
* `install_antigravity.sh` — solo el CLI `agy` (`optional`, `development`/`ai-cli`); su IDE/Desktop queda diferido a propósito, sin mecanismo verificable (ver ADR 0037).
* `install_openclaw.sh`, `install_hermes_agent.sh` — agentes de propósito general `optional`, mismo mecanismo `curl-script`, `category=productivity`/`subcategory=ai-agent`.
* `install_claude_desktop.sh` — `optional`, `manager=apt-vendor-repo` (reutiliza `scripts/lib/apt_vendor_repo.sh` existente, mismo patrón que Docker/VS Code/Cursor), `category=productivity`/`subcategory=ai-agent`.
* Las 7 se registraron en `tools_catalog.sh` y se exponen directamente en el menú de `setup.js`. Prueba nueva: `tests/test_curl_script_contract.sh` (I27, mocks de `curl` para los 6 instaladores `curl-script`); `install_claude_desktop.sh` no tiene prueba automatizada propia en esta ronda (`requires_manual_validation=yes`, mismo criterio que los 6 anteriores: son dominios externos nuevos sin historial de estabilidad verificado en CI).

**Investigación previa a la implementación (mecanismo oficial, clasificación confirmada con el dueño del proyecto el 2026-07-20):**

| Herramienta | Mecanismo oficial investigado | Nivel de oficialidad | Clasificación | Categoría/subcategoría futura |
|---|---|---|---|---|
| Claude Desktop (incluye Cowork) | Repo APT propio de Anthropic (`downloads.claude.ai/claude-desktop/apt/stable`, `signed-by`), paquete `claude-desktop`. Ubuntu 22.04+/Debian 12+, amd64/arm64. Cowork requiere KVM, ~25 GB disco, 8 GB RAM | Alto — mismo patrón que Docker/VS Code/Cursor | `optional` | `productivity`/`ai-agent` |
| Claude Code | Script oficial (`curl -fsSL https://claude.ai/install.sh \| bash`, sin Node), o npm (`@anthropic-ai/claude-code`, Node 22+), o repos apt/dnf/apk propios de Anthropic para sistemas gestionados | Alto — múltiples canales oficiales, incluye apt | `required` | `development`/`ai-cli` |
| Antigravity (Google) | CLI (`agy`): script oficial (`curl -fsSL https://antigravity.google/cli/install.sh \| bash`) a `~/.local/bin`, o npm/`brew`. IDE/Desktop: sin apt/snap oficial, tarball descargado manualmente | Medio — oficial, sin paquete de sistema | `optional` | `editors` (su IDE); el CLI `agy`, si se separa, va a `development`/`ai-cli` |
| OpenCode | Script oficial (`curl -fsSL https://opencode.ai/install \| bash`), o npm (`opencode-ai`) | Medio — oficial, sin paquete de sistema | `required` | `development`/`ai-cli` |
| OpenClaw | Script oficial (`curl -fsSL https://openclaw.ai/install.sh \| bash`), o npm (`openclaw`); requiere Node.js 22.22.3+/24.15+/25.9+ | Medio — oficial, sin paquete de sistema | `optional` | `productivity`/`ai-agent` |
| Codex CLI (OpenAI) | Script oficial (`curl -fsSL https://chatgpt.com/codex/install.sh \| sh`), o npm con scope (`@openai/codex` — el paquete `codex` sin scope es de otro proyecto) | Alto — oficial, terminal, soportado en Linux | `required` | `development`/`ai-cli` |
| Hermes Agent (NousResearch) | Script oficial (`curl -fsSL https://hermes-agent.nousresearch.com/install.sh \| bash`, también disponible en el propio repo de GitHub), o PowerShell en Windows (fuera de alcance). El instalador de terceros bundlea `uv`, Python 3.11, Node.js, ripgrep, ffmpeg y Git portable — no son dependencias que este proyecto gestione por separado, quedan dentro del script oficial. Repo real en GitHub (`NousResearch/hermes-agent`, MIT, ~218k stars, 22 releases; confirmado, no solo sitios de terceros) | Alto — repo oficial verificado, script propio | `optional` | `productivity`/`ai-agent` |

Categoría/subcategoría confirmada con el dueño del proyecto el 2026-07-20 (ver [ADR 0036](adr/0036-candidatas-de-ia-en-categorias-existentes.md)): en vez de una categoría `ai-tools` nueva (que había reservado [ADR 0035](adr/0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md)), cada candidata se distribuye por su función real — Antigravity es la única con un editor de código propio (IDE), Claude Code/Codex CLI/OpenCode son CLIs de desarrollo (mismo criterio que `gh`/`kubectl`), y el resto son agentes/apps de propósito general.

Explícitamente descartado de este inventario: **Codex Desktop** (app Electron de OpenAI) — sin ninguna opción oficial de Linux; los únicos paquetes existentes son repaquetados de terceros sin firma real (`[trusted=yes]` en vez de `signed-by`), lo que no cumple el estándar de seguridad del proyecto (`AGENT.md` §16).

Nota de investigación (Hermes Agent): los primeros resultados de búsqueda incluyeron varios sitios de terceros con contenido tipo "guía 2026" de aspecto genérico (posible SEO/content farm) — se evitó tomarlos como fuente y se verificó directamente el repositorio oficial en GitHub (licencia, releases, script de instalación citado en el propio README) antes de confirmar el mecanismo.

### Entregables

* `install_gh.sh`, registrado en `tools_catalog.sh` (`manager=mise`) y `docs/TOOLS.md`, con prueba funcional real (`tests/docker/test_gh_via_mise.sh`, G01), mismo criterio que K01/Y01.
* [ADR 0033](adr/0033-mise-amplia-su-rol-a-clis-via-registry.md) (Mise amplía su rol a CLIs vía registry, extiende [ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md)) y [ADR 0034](adr/0034-gh-usa-manager-mise-igual-que-kubectl-yarn.md) (corrige el valor de `manager` de 0033 tras confirmar el precedente de `kubectl`/Yarn).
* Los 7 instaladores de candidatas de IA (Claude Code, Codex CLI, OpenCode, Antigravity CLI, OpenClaw, Hermes Agent, Claude Desktop), registrados en `tools_catalog.sh` y `setup.js`, con [ADR 0037](adr/0037-mecanismo-curl-script-para-clis-de-ia.md) documentando el mecanismo `curl-script` nuevo y `tests/test_curl_script_contract.sh` (I27) cubriendo los 6 que lo usan.

### Cierre (2026-07-21)

El pendiente del Antigravity IDE/Desktop quedó resuelto: la investigación original (ADR 0037) solo había encontrado un tarball manual sin checksum/firma, pero una revisión posterior confirmó que Google sí publica un repositorio APT oficial verificable (`us-central1-apt.pkg.dev`, `signed-by` + keyring). Se implementó `scripts/editors/install_antigravity_ide.sh` (`manager=apt-vendor-repo`, `category=editors`), ver [ADR 0041](adr/0041-antigravity-ide-via-repo-apt-oficial.md). Con esto, las 7 candidatas de IA del Hito 16 quedan completamente implementadas (CLI y IDE de Antigravity incluidos) y el hito se marca `Done`.

### Pendiente

Ninguno.

---

# Hito 17

## Configuraciones post-instalación y dependencias entre instaladores

**Prioridad**

Media

**Estado**

Done

Depende de:

Modernización de instaladores (Hito 11) — reutiliza `scripts/lib/installer_cli.sh`/`scripts/lib/tools_catalog.sh` sin cambiarlos.

### Objetivo

Registrado el 2026-07-21 a partir de dos necesidades relacionadas, detectadas al revisar la deuda pendiente de Flameshot (el atajo `PrintScreen` nunca se configuró, solo se instaló el paquete, ver [ADR 0019](adr/0019-flameshot-atajo-printscreen.md)):

1. **Espacio para configuraciones adicionales, revisables después de instalar.** Hoy el único verbo que "hace algo" es `install`; no hay un lugar separado para pasos de configuración (por ejemplo, el atajo de teclado de Flameshot) que:
   - Solo tengan sentido si la herramienta ya está instalada (no se puede configurar el atajo de Flameshot si Flameshot no está instalado — es una dependencia real, no solo de orden de ejecución).
   - Se puedan revisar/re-ejecutar en cualquier momento después de la instalación, no solo una vez durante `install`.
2. **Dependencias entre instaladores del catálogo.** Algunas herramientas necesitan que otra ya esté instalada antes de tener sentido — por ejemplo, Powerlevel10k (tema de Zsh) necesita Oh My Zsh instalado primero. Hoy esto funciona por convención/orden manual, sin que el catálogo lo declare ni lo verifique.

### Tareas (a definir, ninguna implementada todavía)

* Diseñar un mecanismo de dependencias entre entradas del catálogo (por ejemplo, un campo nuevo `depends_on=<id>` en `tools_catalog.sh`, sin esquema forzado, mismo patrón que `kind`/`subcategory`/`classification`/`profiles`).
* Diseñar una capa de configuración post-instalación separada del verbo `install` (por ejemplo, un verbo nuevo `configure`, o un script opcional junto al instalador), que:
  - Se rechace explícitamente si la herramienta no está `INSTALLED` (mismo criterio que el dispatcher ya usa para rechazar `repair` sobre `NOT_INSTALLED`).
  - Sea re-ejecutable en cualquier momento, no solo durante la instalación inicial.
* Aplicar el mecanismo al caso concreto ya identificado: Flameshot + atajo `PrintScreen`.
* Revisar si Powerlevel10k debería declarar formalmente su dependencia de Oh My Zsh en el catálogo.

### Implementación (2026-07-21)

Ver [ADR 0042](adr/0042-configuraciones-post-instalacion-y-dependencias.md) para el detalle completo de la decisión.

* Verbo opcional nuevo `configure` en el contrato de `scripts/lib/installer_cli.sh` (7° verbo, junto a `status/install/uninstall/reinstall/update/repair`): si el instalador no define `configure_tool`, el dispatcher rechaza explícitamente con código 3, mismo patrón que `update`/`repair`. Cada instalador que lo implemente es responsable de rechazar si su propio `check_status` no reporta `INSTALLED`.
* Caso concreto aplicado: `scripts/productivity/install_flameshot.sh` implementa `configure_tool()` para el atajo `PrintScreen` (vía `gsettings`/`org.gnome.settings-daemon.plugins.media-keys`), cerrando la deuda de [ADR 0019](adr/0019-flameshot-atajo-printscreen.md). Rechaza si Flameshot no está instalado o si `gsettings` no está disponible; respalda la lista previa de atajos personalizados antes de tocarla (AGENT.md §17); es idempotente (no duplica el atajo si ya existe). Requiere una sesión GNOME real — no hay prueba automatizada para el paso de `gsettings` en sí (no se puede simular dbus/GNOME en los contenedores Docker de este proyecto), validación manual pendiente.
* Campo nuevo `depends_on=<id>` en `scripts/lib/tools_catalog.sh` (no-esquemático, mismo mecanismo que `kind`/`subcategory`/`classification`/`profiles`). Caso concreto aplicado: `powerlevel10k` → `depends_on=oh_my_zsh`.
* `scripts/lib/dependencies.sh` (nueva biblioteca): `dependency_require_installed <script_path> <etiqueta>` rechaza con un mensaje claro si la dependencia no está instalada — política explícita: nunca la instala por su cuenta. `install_powerlevel10k.sh` la usa al principio de `install_tool()`.
* Cuando la dependencia y la dependiente se piden instalar juntas (mismo perfil de `setup.sh install --profile`), el orden correcto se garantiza confiando en el orden de registro en `tools_catalog.sh` (`oh_my_zsh` ya está registrado antes que `powerlevel10k`) — una simplificación deliberada mientras exista una sola relación de dependencia, documentada explícitamente en ADR 0042 como limitación conocida.
* Cobertura de pruebas: `tests/test_installer_cli.sh` (verbo `configure` genérico), `tests/test_flameshot_installer.sh` (nuevo `configure_tool()`), `tests/test_dependencies_lib.sh` (I32) y `tests/test_powerlevel10k_dependency.sh` (I33) — ver `docs/TEST_CASES.md`.

### Pendiente

Ninguno.

---

# Hito 18

## Scripts de prueba manual para VM

**Prioridad**

Alta

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21 al planificar el camino hacia la primera versión estable: el cierre del Hito 9 (ver `docs/RELEASES.md`) dejó dos validaciones manuales pendientes como condición explícita previa a esa versión estable (Snap en Ubuntu 26.04 Desktop real, kernel HWE en VM), y desde entonces la deuda de `requires_manual_validation=yes` creció con más herramientas del catálogo que ningún contenedor Docker de este proyecto puede probar de verdad (sin systemd/snapd real, sin sesión GNOME/dbus, sin GPU/hardware real para el kernel HWE).

### Implementación (2026-07-21)

Directorio nuevo `tests/manual/` (ver su propio `README.md`), separado de `tests/docker/` (corre en CI) y `tests/lib/` (mocks) — deja explícito que nada de esto se ejecuta automáticamente ni en la máquina de desarrollo de este repositorio:

* `lib_manual.sh` — helpers compartidos (secciones, asserts con log completo, `manual_run_lifecycle` para el ciclo `status→install→status→uninstall→status` genérico).
* `test_manual_snap_apps.sh` — los 8 instaladores `manager=snap`: DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi.
* `test_manual_ai_and_ide.sh` — Antigravity IDE (`manager=apt-vendor-repo`) y los 7 candidatos de IA del Hito 16 (Claude Code, Codex CLI, OpenCode, Antigravity CLI, OpenClaw, Hermes Agent, Claude Desktop).
* `test_manual_flameshot_configure.sh` — el `configure_tool()` de Flameshot (Hito 17): confirma vía `gsettings get` que el atajo `PrintScreen` se agrega, que una segunda corrida es idempotente (no se duplica), y que queda un respaldo de la lista previa; el único paso que no automatiza (apretar la tecla físicamente) se deja como confirmación manual explícita al final del log.
* `test_manual_kernel_hwe.sh` — `install_kernel.sh`, deliberadamente de solo lectura por defecto (solo `status`); instalar de verdad requiere el flag `--install` y una confirmación interactiva escrita, nunca corre `uninstall` automáticamente (alto riesgo de dejar la VM sin arrancar).
* `run_all_manual_tests.sh` — punto de entrada único, mismo patrón de log que `tests/docker/build-and-test-all.sh` (`exec > >(tee ...)`, log con timestamp + symlink `-latest`), corre los 4 scripts en orden sin nunca pasar `--install` al de kernel.

`docs/TESTING.md` documenta esto como su "Nivel 3".

### Entregables

Scripts de prueba + instrucciones de uso (clonar el repo en la VM, ejecutar, guardar el log) — completos, ver `tests/manual/README.md`.

---

# Hito 19

## Ejecución de las pruebas manuales en VM

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Scripts de prueba manual para VM (Hito 18).

### Objetivo

Registrado el 2026-07-21 junto con el Hito 18, del que depende directamente. La persona usuaria ejecuta en su propia VM Ubuntu 26.04 Desktop los scripts del Hito 18 y comparte el log de resultados. A partir de ahí se itera: corregir instaladores reales si algo falla, o corregir los propios scripts de prueba si el problema está en cómo prueban.

**Explícitamente no bloqueante para el resto del roadmap** (confirmado con el dueño del proyecto): mientras este hito espera resultados, el trabajo continúa en los Hitos 20-23.

### Pendiente

Esperando la ejecución en VM y el log de resultados correspondiente.

---

# Hito 20

## Cierre administrativo de Hitos 11/12/13

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno (es una decisión administrativa sobre trabajo ya implementado, no depende de código nuevo).

### Objetivo

Registrado el 2026-07-21 al planificar el camino hacia la primera versión estable. Los Hitos 11 (Modernización de instaladores), 12 (Framework de validación) y 13 (Perfiles) están funcionalmente completos desde hace varias sesiones, pero seguían formalmente `In Progress` en este documento porque nunca se propuso su cierre explícito como `Done`:

* **Hito 11:** 28 de 30 instaladores migrados al contrato completo de 6 verbos; los 2 restantes quedan fuera a propósito (`install_vim.sh` es el instalador de referencia, `install_nodejs.sh` es legado congelado sin acciones activas).
* **Hito 12:** los 5 chequeos del framework de validación ya están implementados dentro de `doctor` (PATH, ejecutables, dependencias compartidas, symlinks rotos, versiones de runtime).
* **Hito 13:** los 11 perfiles y los comandos `install --profile`/`list`/`info` ya están implementados y probados.

### Implementación (2026-07-21)

Los tres se marcaron `Done` en sus propias secciones de este documento, cada uno con una nota "Cierre administrativo (2026-07-21, Hito 20)" que referencia este hito, sin reabrir ni reescribir su historial de implementación ya registrado.

---

# Hito 21

## Actualizar `docs/RELEASES.md`

**Prioridad**

Media

**Estado**

Done

Depende de:

Cierre administrativo de Hitos 11/12/13 (Hito 20) — para poder registrar su cierre real en la bitácora.

### Objetivo

Registrado el 2026-07-21. `docs/RELEASES.md` quedó desactualizado desde el cierre de la Fase 1 del Hito 11 (2026-07-19): no reflejaba nada de lo ocurrido desde entonces (resto de fases del Hito 11, Hitos 12 a 20). Completada la bitácora de hitos entregados hasta el estado actual del roadmap (Hitos 11 a 20), como paso previo a poder llamar a este estado "primera versión estable".

---

# Hito 22

## Revisión de `docs/TECHNICAL_REVIEW.md`

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21. `docs/TECHNICAL_REVIEW.md` (revisión técnica integral del 2026-07-18) dejó hallazgos `Medio`/`Bajo` como backlog documentado, sin fecha comprometida. Auditar cada uno de esos hallazgos pendientes: confirmar cuáles ya se resolvieron de hecho como efecto colateral de hitos posteriores (sin que nadie lo haya marcado ahí explícitamente) y cuáles siguen abiertos de verdad, actualizando el documento en consecuencia.

### Implementación (2026-07-21)

De los 6 hallazgos que seguían sin `✅ Corregido` (M5, M6, B2, B5, B8, B9):

* **M6 se cerró** (pasó de `En progreso` a `✅ Corregido`): verificado por grep directo que 53 de los 55 `install_*.sh` sourcean `scripts/lib/installer_cli.sh` hoy, con los mismos 2 excluidos a propósito que ya documentaba el roadmap (`install_vim.sh`, `install_nodejs.sh`); los 3 agrupadores delgados que M6 citaba ya no existen (ADR 0035).
* **M5, B2, B5, B8, B9 siguen abiertos de verdad**, confirmado contra el código/CI actual (no solo asumido): quedan como backlog documentado, sin fecha comprometida, no bloqueantes para la primera versión estable.

Ver la nota "Actualización 2026-07-21 (Hito 22)" en el propio `docs/TECHNICAL_REVIEW.md` para el detalle completo.

---

# Hito 23

## Actualizar `README.md`

**Prioridad**

Media

**Estado**

Done

Depende de:

Revisión de `docs/TECHNICAL_REVIEW.md` (Hito 22) — último paso antes de considerar cerrado el camino hacia la primera versión estable.

### Objetivo

Acortar el `README.md` raíz a inicio rápido, seguridad y enlaces a `docs/`, moviendo el detalle de implementación a `docs/` (ver Hito 15, tarea pospuesta explícitamente por el dueño del proyecto hasta este punto: "Todavía no, dejarla como borrador").

### Implementación (2026-07-21)

`README.md` reescrito: inicio rápido (`git clone` + comandos más usados, incluyendo `list`/`info`/`install --profile` del Hito 13 y `doctor`/`backup`/`migrate`), una sección de Seguridad nueva (backups, `doctor` de solo lectura, `/home` reutilizado, migración NVM sin borrado, `sudo`/secretos), y la lista de documentación de referencia ampliada con `CONTRIBUTING.md`/`MIGRATIONS.md`/`RELEASES.md` (ya existían, pero el README todavía no los enlazaba). Se retiró todo el detalle que había quedado desactualizado y duplicado con `docs/ARCHITECTURE.md`/`docs/TOOLS.md`: la lista completa de instaladores por categoría (incluía los 3 agrupadores delgados eliminados en el Hito 11, ADR 0035) y la descripción del contrato de verbos como si la migración siguiera "incremental, en fases" (el Hito 11 ya cerró, Hito 20).

**Con este hito se completa la lista de los 6 hitos (18, 19, 20, 21, 22, 23) definida para el camino hacia la primera versión estable**, salvo el Hito 19 (ejecución de las pruebas manuales en VM), que sigue esperando el log de resultados de la persona usuaria — explícitamente no bloqueante para llamar `Done` al resto.

---

# Hito 24

## Ampliación del catálogo: virtualización

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar VMware Workstation y VirtualBox al catálogo. Mismo patrón que toda ampliación anterior (Hito 11 "terminales nuevos", Hito 16): investigar el mecanismo oficial de instalación de cada una, categorizar (`category`/`subcategory`/`classification`/`profiles`), detectar dependencias reales (módulos de kernel, licenciamiento), y recién ahí preparar los instaladores — nada se implementa sin esa investigación previa.

* **VMware Workstation** — software propietario con licencia; instalador `.bundle` oficial (no repositorio APT). Investigar si Workstation Pro sigue siendo gratuito para uso personal (cambio de política de Broadcom/VMware post-adquisición) antes de asumir el mecanismo de instalación.
* **VirtualBox** — Oracle publica un repositorio APT oficial (`download.virtualbox.org`); requiere `dkms`/módulos de kernel para el driver de virtualización (`vboxdrv`), a diferencia del resto del catálogo — primer caso real de un instalador que depende de compilar/cargar un módulo de kernel.

### Investigación y decisión: VMware Workstation (2026-07-21)

Investigado antes de escribir código, como pide el objetivo. Dos bloqueantes reales para un instalador automatizado limpio:

1. **Descarga sin URL pública.** Desde el 11/nov/2024, Broadcom liberó VMware Workstation Pro gratis para uso personal/comercial/educativo sin clave de licencia ([Broadcom KB](https://knowledge.broadcom.com/external/article/368667/download-and-license-vmware-desktop-hype.html)) — la licencia ya no es un bloqueante. Pero la descarga del `.bundle` requiere iniciar sesión en el portal `support.broadcom.com`; no existe una URL pública descargable con `curl`/`wget` sin autenticación.
2. **Módulos de kernel (vmmon/vmnet) sin soporte oficial en kernels recientes.** VMware no mantiene compatibilidad oficial con Ubuntu 24.04+ (kernel 6.8+); los módulos no compilan sin parches de terceros (repos comunitarios no oficiales de la comunidad). Cae en la categoría "fuente comunitaria, requiere justificación explícita" de [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md), no "instalador oficial" limpio.

**Decisión (2026-07-21):** el dueño del proyecto confirmó descartar VMware Workstation del catálogo — no se implementa ningún instalador, ni se documenta como "instalación manual". Motivo: los dos bloqueantes de arriba (descarga sin URL pública, módulos de kernel sin soporte oficial dependientes de un parche comunitario no oficial) no justifican el esfuerzo/riesgo frente al beneficio, mismo criterio de "requiere justificación explícita" de [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md) que no se cumplió. Fuera de alcance de este proyecto, igual que NVIDIA/CUDA ([ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md)).

### Implementación: VirtualBox (2026-07-21)

Sin bloqueantes reales — implementado. `scripts/development/install_virtualbox.sh` (`manager=apt-vendor-repo`, `category=development`, `subcategory=virtualization` nueva): agrega el repositorio oficial de Oracle (nunca el paquete `virtualbox` de Ubuntu, que suele quedar desactualizado); el nombre del paquete (`virtualbox-X.Y`) se resuelve dinámicamente tras agregar el repo, sin hardcodear una versión que quedaría obsoleta (mismo criterio que `install_kernel.sh::get_latest_hwe_kernel`). Primer instalador que depende de un módulo de kernel (`vboxdrv` vía DKMS): `status` distingue `BROKEN` (paquete instalado, módulo no cargado) de `INSTALLED`; el "VirtualBox Extension Pack" (licencia PUEL) queda deliberadamente fuera. `requires_manual_validation=yes` (ningún contenedor Docker de este proyecto puede cargar un módulo de kernel real — se valida en `tests/manual/`, Hito 19). Prueba nueva: `tests/test_virtualbox_installer.sh` (I34), mocks completos incluyendo un dispositivo `/dev/vboxdrv` simulable (`UCI_VIRTUALBOX_VBOXDRV_PATH`, mismo criterio que `UCI_HOME_DIR` de [ADR 0023](adr/0023-variable-uci-home-dir-para-pruebas.md), extendido por primera vez a un dispositivo).

### Pendiente

Ninguno. VMware Workstation queda descartado (ver decisión arriba); VirtualBox implementado.

---

# Hito 25

## Ampliación del catálogo: mensajería/comunicación

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar Telegram Desktop, Slack y Discord al catálogo. Mismo criterio de investigación previa que el Hito 24.

* **Telegram Desktop** — evaluar entre el repositorio oficial vs. Snap vs. tarball oficial.
* **Slack** — Slack Technologies publica un `.deb` oficial y también un snap; evaluar cuál conviene como mecanismo gestionado (ver orden de fuentes por categoría, [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md)).
* **Discord** — no publica repositorio APT oficial; típicamente `.deb` de descarga directa (mismo mecanismo `deb-direct` ya usado por Chrome/MongoDB Compass) o Snap.

### Investigación (2026-07-21)

* **Telegram Desktop**: Telegram FZ-LLC no publica repositorio APT propio. El snap `telegram-desktop` (publicado por la cuenta verificada de Telegram FZ-LLC en Snap Store) es la única fuente mantenida directamente por el fabricante; no requiere `--classic` (confinamiento estricto normal).
* **Slack**: publica repositorio APT propio hosteado en Packagecloud (`packagecloud.io/slacktechnologies/slack`), preferido sobre el `.deb` suelto por permitir `apt upgrade` (mismo criterio de priorizar la fuente más "nativa" para actualizaciones). La línea del repo usa `ubuntu trusty` como distro/codename fijo, tal como documentan las instrucciones oficiales — no depende de la versión real de Ubuntu.
* **Discord**: confirmado que no publica repositorio APT oficial, pero sí un endpoint estable (`discord.com/api/download?platform=linux&format=deb`) que siempre resuelve a la última versión, sin necesidad de fijar ni scrapear un número de versión (mecanismo `deb-direct`, mejor que el de MongoDB Compass en ese sentido).

### Implementación (2026-07-21)

* `scripts/productivity/install_telegram_desktop.sh` (`manager=snap`) — reutiliza `scripts/lib/snap.sh` sin cambios.
* `scripts/productivity/install_slack.sh` (`manager=apt-vendor-repo`) — reutiliza `scripts/lib/apt_vendor_repo.sh` sin cambios.
* `scripts/productivity/install_discord.sh` (`manager=deb-direct`) — reutiliza `scripts/lib/deb_direct.sh` sin cambios.
* `subcategory=communication` nueva en `tools_catalog.sh` para los 3.
* Cobertura de pruebas: Telegram Desktop se agregó a los tests parametrizados ya existentes del grupo Snap (`tests/test_snap_installers_contract.sh`/I10, `tests/test_snap_installers_full_contract.sh`/I22); Discord se agregó al parametrizado del grupo deb-directo (`tests/test_deb_direct_full_contract.sh`/I23); Slack (primer caso `apt-vendor-repo` con una prueba mockeada dedicada, ya que Docker/VS Code/Cursor solo tenían pruebas funcionales reales) tiene `tests/test_slack_installer.sh` (I35) nuevo — este último expuso y corrigió un bug real: el mock de `sudo` de passthrough directo dejaba que `sudo install`/`sudo tee` (usados por `apt_vendor_repo_fetch_key_dearmored`/`apt_vendor_repo_write_list`) invocaran los binarios reales del sistema, fallando por permisos en CI; se corrigió mockeando también `install`/`tee` (mismo fix aplicado retroactivamente a `tests/test_virtualbox_installer.sh`, donde se encontró primero).
* `requires_manual_validation=yes` en los 3: ninguno tiene todavía una prueba funcional real (solo mocks); Telegram Desktop además hereda la limitación estructural del grupo Snap (sin systemd en los contenedores de este proyecto).

### Pendiente

Ninguno.

---

# Hito 26

## Ampliación del catálogo: productividad de escritorio

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar LibreOffice, OnlyOffice, Obsidian y KeePassXC al catálogo. Mismo criterio de investigación previa que el Hito 24.

* **LibreOffice** — ya está en los repositorios oficiales de Ubuntu (viene preinstalado en la mayoría de las imágenes Desktop); confirmar si corresponde un instalador `apt-simple` igual (para máquinas donde se haya retirado, o instalaciones Server) o si se documenta como ya cubierto.
* **OnlyOffice** — publica repositorio APT propio oficial.
* **Obsidian** — distribuye AppImage y también publica en Snap Store (`obsidian`, oficial); evaluar cuál conviene.
* **KeePassXC** — tiene PPA oficial del proyecto además de estar en los repositorios de Ubuntu; confirmar si la versión de repos oficiales es lo bastante reciente o si conviene el PPA.

### Investigación (2026-07-21)

* **LibreOffice**: el paquete de los repos oficiales de Ubuntu queda desactualizado frente a la última versión de TDF, pero el único PPA propio de TDF ("Fresh PPA") se documenta a sí mismo como testing/bleeding-edge, "no recomendado para el usuario promedio" — excepción consciente al criterio de priorizar la fuente más fresca: acá fresco significa menos estable, por diseño del propio mantenedor. Para una suite ofimática, la estabilidad de formatos pesa más. Se usa `apt-simple` con el paquete oficial de Ubuntu.
* **OnlyOffice**: confirmado repo APT propio (`download.onlyoffice.com`), clave GPG en URL HTTPS directa, paquete `onlyoffice-desktopeditors`.
* **Obsidian**: el snap `obsidian` está publicado por la cuenta verificada `obsidianmd` (el propio equipo) — fuente oficial. Requiere `--classic`.
* **KeePassXC**: el PPA `ppa:phoerious/keepassxc`, mantenido por el propio equipo de KeePassXC, sigue activo y actualizado.

### Implementación (2026-07-21)

* `scripts/productivity/install_libreoffice.sh` (`manager=apt`, apt-simple) — mismo patrón que `install_ranger.sh`.
* `scripts/productivity/install_onlyoffice.sh` (`manager=apt-vendor-repo`) — reutiliza `scripts/lib/apt_vendor_repo.sh` sin cambios; la línea del repo usa `debian squeeze` como distro/codename fijo, mismo patrón que Slack con `ubuntu trusty`.
* `scripts/productivity/install_obsidian.sh` (`manager=snap`, `--classic`) — reutiliza `scripts/lib/snap.sh` sin cambios.
* `scripts/productivity/install_keepassxc.sh` (`manager=apt-vendor-repo` vía PPA) — mismo patrón que `install_ulauncher.sh`.
* `subcategory=office`/`notes`/`security` nuevas en `tools_catalog.sh`.
* Cobertura de pruebas: Obsidian se agregó a los tests parametrizados existentes del grupo Snap (I10/I22, igual que Telegram Desktop en el Hito 25); LibreOffice (I36), KeePassXC (I37) y OnlyOffice (I38) tienen pruebas mockeadas dedicadas nuevas, siguiendo el mismo criterio de mockear `install`/`tee` explícitamente para los dos mecanismos `apt-vendor-repo` (KeePassXC vía PPA no lo necesita, igual que ULauncher).
* Los 4 quedan `requires_manual_validation=yes` (solo mocks en esta ronda, sin prueba funcional real), mismo criterio aplicado a los 3 del Hito 25.

### Pendiente

Ninguno.

---

# Hito 27

## Ampliación del catálogo: navegadores

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar Brave y Chromium al catálogo. Mismo criterio de investigación previa que el Hito 24.

* **Brave** — repositorio APT oficial documentado (`brave-browser-apt-release.s3.brave.com`), mismo patrón `apt-vendor-repo` ya usado por VS Code/Cursor/Docker.
* **Chromium** — en Ubuntu moderno el paquete `chromium-browser` del repositorio oficial es en realidad un wrapper que instala el snap (`chromium`, mantenido por Canonical) — confirmar este detalle antes de asumir que es un `apt-simple` tradicional como Chrome no lo es.

### Investigación (2026-07-21)

* **Brave**: confirmado en `brave.com/linux/` (fuente oficial). A diferencia de Docker/VS Code/Cursor/VirtualBox/Slack/OnlyOffice, Brave publica su clave GPG YA lista para `signed-by` (sin `gpg --dearmor`) y, en vez de una línea `deb [...]` para construir a mano, un archivo `.sources` completo en formato DEB822 — ambos se descargan tal cual.
* **Chromium**: confirmado (Launchpad + fuentes técnicas): en Ubuntu 24.04+ `chromium-browser` de los repos oficiales es un paquete transicional vacío que en la práctica instala el snap `chromium`, publicado por Canonical (cuenta verificada), sin `--classic`.

### Implementación (2026-07-21)

* **`scripts/lib/apt_vendor_repo.sh` ampliado**: nuevo helper genérico `apt_vendor_repo_fetch_file_plain <url> <dest_path>` para archivos que un proveedor publica ya listos para usar (sin `gpg --dearmor` ni una línea `deb [...]` a construir) — primer caso real, Brave, para su clave y su archivo `.sources`. `apt_vendor_repo_fetch_key_plain` (ya usado por Docker) pasa a ser un alias de este nuevo helper, sin cambiar su comportamiento.
* **Hallazgo real durante la implementación**: la primera versión de `apt_vendor_repo_fetch_file_plain` escribía directo al destino final vía `curl -o <dest_path>` (como el propio Docker ya hacía con `fetch_key_plain`) — funcionaba en la práctica (Docker solo tiene prueba funcional real, con root de verdad), pero al escribir la primera prueba MOCKEADA de este mecanismo (Brave) quedó expuesto que ese patrón deja un archivo parcial en el destino si la descarga se corta a mitad de camino, y que no es testeable sin permisos reales. Se corrigió para descargar siempre a un temporal primero y recién instalar de forma atómica con `sudo install -D` — mismo patrón en dos pasos que `apt_vendor_repo_fetch_key_dearmored`, ahora consistente en toda la biblioteca. No cambia el comportamiento observable de Docker.
* `scripts/productivity/install_brave.sh` (`manager=apt-vendor-repo`) y `scripts/productivity/install_chromium.sh` (`manager=snap`, sin `--classic`).
* `subcategory=browsers` nueva. Chromium se agregó a los tests parametrizados existentes del grupo Snap (I10/I22); Brave tiene una prueba mockeada dedicada nueva (I39), con el mismo cuidado de mockear `install` explícitamente (lección de VirtualBox/Slack/OnlyOffice).
* Ambos quedan `requires_manual_validation=yes` (solo mocks en esta ronda).

### Pendiente

Ninguno.

---

# Hito 28

## Ampliación del catálogo: herramientas CLI

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar fzf, thefuck, jq, yq, ngrok y Ollama al catálogo. Mismo criterio de investigación previa que el Hito 24.

* **fzf**, **jq** — en los repositorios oficiales de Ubuntu, candidatos directos a `apt-simple` (mismo patrón que `install_ranger.sh`).
* **thefuck** — en los repositorios oficiales de Ubuntu (paquete `thefuck`, requiere Python); confirmar dependencias de runtime.
* **yq** — el `yq` de Mike Farah (Go, el más usado hoy para YAML/JSON tipo `jq`) generalmente NO está en los repositorios oficiales de Ubuntu con esa identidad (existe un paquete `yq` distinto, basado en Python/`jq`, con opciones incompatibles) — investigar con cuidado cuál es el que se espera antes de instalar el equivocado.
* **ngrok** — publica repositorio APT propio oficial.
* **Ollama** — se instala vía script oficial `curl | sh` (mismo mecanismo `curl-script` ya usado por Claude Code/Codex CLI/OpenCode, ver [ADR 0037](adr/0037-mecanismo-curl-script-para-clis-de-ia.md)); confirmar si corresponde `subcategory=ai-cli` o si merece su propia subcategoría al no ser un asistente de código.

### Investigación (2026-07-21)

* **fzf**: confirmado en repos oficiales de Ubuntu, pero crónicamente desactualizado frente a GitHub (problema documentado activamente por el propio proyecto, junegunn/fzf#2599). Sin repo/snap oficial alternativo — se usa `apt-simple` de todas formas, con la limitación documentada explícitamente (mismo criterio que LibreOffice).
* **thefuck**: confirmado en repos oficiales; el proyecto (nvbn/thefuck) sigue con actividad real.
* **jq**: confirmado en repos oficiales, sin complicaciones.
* **yq**: **ambigüedad real confirmada**. El paquete `yq` de Ubuntu es el de Kislyuk en Python (wrapper de jq para YAML) — NO es el de Mike Farah (Go, el esperado). El PPA histórico de terceros que empaquetaba el de Mike Farah está descontinuado; publica en cambio un snap oficial verificado (cuenta `mikefarah`).
* **ngrok**: confirmado repo APT oficial, clave ya lista (sin `gpg --dearmor`, mismo patrón que Brave), codename fijo `bookworm` (Debian, mismo patrón que Slack/OnlyOffice).
* **Ollama**: confirmado `curl -fsSL https://ollama.com/install.sh | sh`, binario `ollama`. Funciona en modo CPU-only sin dependencias especiales.

### Implementación (2026-07-21)

* `scripts/system/install_{fzf,thefuck,jq}.sh` (`manager=apt`, apt-simple) — agregados al test parametrizado existente `tests/test_terminal_apps_apt_simple_contract.sh` (I25).
* `scripts/system/install_yq.sh` (`manager=snap`, snap de Mike Farah, sin `--classic`) — agregado a los tests parametrizados existentes del grupo Snap (I10/I22). El paquete `yq` de Ubuntu nunca se usa para esta herramienta.
* `scripts/development/install_ngrok.sh` (`manager=apt-vendor-repo`, mismo mecanismo `apt_vendor_repo_fetch_file_plain` que Brave) — prueba mockeada dedicada nueva (I40).
* `scripts/development/install_ollama.sh` (`manager=curl-script`) — `uninstall_tool()` propio, no reutiliza la convención `~/.local/bin/<binario>` del resto del grupo (Ollama instala en una ruta del sistema vía systemd); sigue los pasos de desinstalación documentados oficialmente. Prueba mockeada dedicada nueva (I41), ya que no encaja en el test parametrizado genérico de curl-script.
* `subcategory=ai-runtime` nueva para Ollama (distinta de `ai-cli`/`ai-agent`: es un runtime local de LLM, no un asistente de código).
* Todos quedan `requires_manual_validation=yes` salvo fzf/thefuck/jq (apt-simple estándar, mismo criterio que nnn/lf).

### Pendiente

Ninguno.

---

# Hito 29

## Ampliación del catálogo: misceláneos

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: agregar SoapUI, LocalSend, Steam y Okular al catálogo. Mismo criterio de investigación previa que el Hito 24.

* **SoapUI** — SmartBear distribuye un instalador `.sh` (bundle), no un repositorio APT.
* **LocalSend** — publica AppImage/`.deb`/Flatpak/Snap en su repositorio de GitHub releases; evaluar cuál conviene.
* **Steam** — Valve publica un `.deb` oficial (también está en el repositorio `multiverse` de Ubuntu); confirmar cuál de los dos conviene como mecanismo gestionado.
* **Okular** — visor/editor de PDF de KDE; está en los repositorios oficiales de Ubuntu, candidato directo a `apt-simple`.

### Investigación (2026-07-22)

* **SoapUI**: confirmado instalador `.sh` tipo IzPack (`SoapUI-x64-<version>.sh`) publicado en GitHub Releases (`SmartBear/soapui`), sin alias estable de "última versión" — se resuelve dinámicamente vía la API de GitHub Releases. Flag `-q` confirmado en foros de la comunidad SmartBear como modo silencioso, pero NO está confirmado el directorio final de instalación ni si `-q` basta por sí solo en todos los casos — alto grado de incertidumbre, documentado explícitamente en el propio script.
* **LocalSend**: publica `.deb`/AppImage en GitHub Releases (`localsend/localsend`), sin repositorio APT propio ni snap oficial confirmado. Se eligió `.deb` vía `deb-direct` con URL resuelta dinámicamente (mismo criterio de "preferir la fuente más actualizada" que VirtualBox). El nombre del paquete resultante (`localsend_app`) se infiere del app id (`org.localsend.localsend_app`), sin confirmación directa — a verificar en la validación manual (Hito 19).
* **Steam**: confirmado que Valve recomienda el paquete `steam-installer` de los repositorios oficiales de Ubuntu (`multiverse`) sobre el `.deb` suelto (mismo resultado final, pero con actualizaciones vía `apt`). Confirmado (Ubuntu Discourse + reportes de GitHub) que instalar sin antes habilitar la arquitectura `i386` deja `steam-libs-i386` con dependencias no satisfechas.
* **Okular**: confirmado en los repositorios oficiales de Ubuntu, sin complicaciones — candidato directo a `apt-simple`.

### Implementación (2026-07-22)

* `scripts/lib/github_release.sh` (nuevo, `github_release_asset_url`): resuelve dinámicamente la URL de un asset de GitHub Releases vía su API pública, sin depender de `jq`. Justificado como "segundo caso real" (SoapUI y LocalSend lo necesitan simultáneamente), cruzando el umbral que [ADR 0032](adr/0032-mecanismo-condicional-por-version-de-ubuntu.md) exige antes de abstraer un patrón en vez de duplicarlo.
* `scripts/development/install_soapui.sh` (`manager=izpack-installer`, nuevo y único caso en el catálogo) — busca el binario resultante en ubicaciones plausibles (`$HOME/SoapUI-*/bin/soapui.sh`, `/opt/SoapUI-*/bin/soapui.sh`) en vez de asumir una sola; rechaza explícitamente con un mensaje que apunta a `tests/manual/` si no encuentra un binario resoluble tras correr el instalador. Prueba mockeada dedicada nueva (I44).
* `scripts/productivity/install_localsend.sh` (`manager=deb-direct` + resolución dinámica vía `github_release.sh`) — sin `reinstall_tool` propio: el fallback mecánico del dispatcher (desinstalar + instalar) ya vuelve a resolver la última URL en cada corrida, que es exactamente el comportamiento deseado. Prueba mockeada dedicada nueva (I42).
* `scripts/productivity/install_steam.sh` (`manager=apt`, apt-simple) — `install_tool()` habilita la arquitectura `i386` de forma idempotente (solo si no estaba ya habilitada) antes de instalar `steam-installer`. Prueba mockeada dedicada nueva (I43).
* `scripts/productivity/install_okular.sh` (`manager=apt`, apt-simple estándar) — agregado al test parametrizado existente `tests/test_terminal_apps_apt_simple_contract.sh` (I25), sin sumar un ID nuevo.
* `subcategory=file-sharing` (LocalSend) y `subcategory=gaming` (Steam) nuevas; Okular reutiliza `subcategory=office`.
* Todos `requires_manual_validation=yes` salvo Okular (apt-simple estándar, mismo criterio que nnn/lf/fzf/thefuck/jq).

### Pendiente

Ninguno.

---

# Hito 30

## Extensiones de GNOME (extensions.gnome.org)

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno. **No ejecutar sin aprobación explícita adicional del dueño del proyecto** — a diferencia de los Hitos 24-29, este necesita revisión antes de empezar a trabajarlo.

### Objetivo

Registrado el 2026-07-21, pedido explícito del dueño del proyecto: soporte para instalar/gestionar extensiones de GNOME Shell (`extensions.gnome.org`). Conceptualmente distinto al resto de los Hitos 24-29: no es "una app con un instalador", sino habilitar el ecosistema de extensiones — probablemente derive en instalar el gestor de extensiones (`gnome-shell-extension-manager`) y/o el conector de navegador (`gnome-browser-connector`, antes `chrome-gnome-shell`) que permite instalar extensiones directamente desde el sitio oficial. Necesita una investigación previa más abierta que el resto (qué significa exactamente "registrar" una extensión en este catálogo: ¿el gestor en sí, un puñado de extensiones específicas pedidas por el dueño del proyecto, o el mecanismo de instalación en general) antes de poder definir tareas concretas.

### Pendiente

Todo — bloqueado hasta que el dueño del proyecto revise el alcance y dé luz verde para empezar.

---

# Hito 31

## Ampliación del catálogo: clientes API open source

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto a partir de una investigación de alternativas FOSS por subcategoría (`category=development`/`subcategory=api-clients`, mismo grupo que Postman/Insomnia/SoapUI):

* **Bruno** — cliente API git-native, local-first (sin sincronización a la nube por defecto). **Nota:** el ítem 7 de "Preguntas resueltas por el dueño del proyecto (2026-07-15)" registra una decisión previa de NO agregarlo ("se mantienen Postman e Insomnia") — esta instrucción del 2026-07-22 la reemplaza explícitamente. Licencia: núcleo MIT, con una edición "Bruno Cloud" de pago que NO es necesaria para el uso local — confirmar en la investigación que ninguna función esencial quede detrás de esa edición antes de implementar.
* **Hoppscotch** — cliente API 100% FOSS (MIT), self-hosteable; existe tanto como app de escritorio (Electron/Tauri) como versión web.

### Investigación (2026-07-22)

* **Bruno**: confirmado snap oficial (`bruno`) publicado por el propio creador del proyecto (`helloanoop`), sincronizado con el último release de GitHub — preferido sobre `deb-direct` por simplicidad. Licencia MIT en el núcleo confirmada; "Bruno Cloud" es un servicio opcional de pago que no bloquea ninguna función esencial del uso local.
* **Hoppscotch**: confirmado que SÍ existe una app de escritorio oficial real, basada en **Tauri** (no Electron), en un repo de releases separado (`hoppscotch/releases`). **Hallazgo real durante la implementación**: ni la API JSON de `releases/latest` ni el endpoint fijo de descarga documentado oficialmente (`.../releases/latest/download/Hoppscotch_linux_x64.deb`) son confiables — se confirmó en vivo que el release "latest" en ese momento (v26.6.1-0) es un hotfix que solo publica el asset "SelfHost" (para autohospedar el backend, un producto distinto), sin el `.deb` de escritorio; el endpoint fijo devolvía 404. Se implementó una resolución que recorre la lista de releases recientes (`/releases`, no `/releases/latest`) hasta encontrar uno que sí publique `Hoppscotch_linux_x64.deb`. También se confirmó (inspeccionando el `.deb` real) que el paquete se llama `hoppscotch` pero el binario que instala es `hoppscotch-desktop`, no `hoppscotch`.

### Implementación (2026-07-22)

* `scripts/development/install_bruno.sh` (`manager=snap`, `--classic` — mismo criterio que Obsidian, necesita acceso amplio al filesystem para abrir colecciones git-native en cualquier ubicación del home) — agregado a los tests parametrizados existentes del grupo Snap (I10/I22).
* `scripts/development/install_hoppscotch.sh` (`manager=deb-direct` con resolución propia sobre la lista de releases, sin usar `scripts/lib/github_release.sh` por el hallazgo real documentado arriba — caso único hasta ahora, no se abstrae por ahora, ver criterio de ADR 0032) — prueba mockeada dedicada nueva (I45), que simula exactamente el escenario "release más reciente solo trae SelfHost".
* Ambos quedan `requires_manual_validation=yes`.

### Pendiente

Ninguno.

---

# Hito 32

## Ampliación del catálogo: clientes de bases de datos open source

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=development`/`subcategory=db-clients`, mismo grupo que DBeaver/MongoDB Compass):

* **Beekeeper Studio** — cliente SQL multi-motor, GPL-3.0.
* **DbGate** — cliente SQL/NoSQL multi-motor, FOSS.

### Investigación (2026-07-22)

* **Beekeeper Studio**: confirmado en vivo que el release "latest" de GitHub (v5.9.2) publica `beekeeper-studio_5.9.2_amd64.deb`. Inspeccionando el `.deb` real (`dpkg-deb`): el `postinst` crea el symlink `/usr/bin/beekeeper-studio` automáticamente y sugiere fuertemente la existencia de un repositorio APT oficial propio (migra `sources.list.d/beekeeper-studio.list` a `beekeeper-studio-app.list`, embebe una clave GPG), pero no se pudo confirmar la URL/línea de repo exacta por una restricción de red del entorno de desarrollo — se implementó con `deb-direct` (confirmado funcionando) en vez de arriesgar una configuración de `apt-vendor-repo` no verificada; queda como candidato a migrar en una ronda futura. Licencia GPL-3.0 confirmada, la edición "Ultimate" de pago no bloquea el uso básico.
* **DbGate**: confirmado en vivo que el release "latest" (v7.2.3) publica `dbgate-7.2.3-linux_amd64.deb`, junto a varios assets de la edición "premium" de pago (sin `.deb` para Linux, solo AppImage) y un alias `dbgate-latest.deb` en el mismo release — el patrón de resolución exige un dígito justo después de `dbgate-` para excluir ambos, verificado. Inspeccionando el `.deb` real: el `postinst` crea `/usr/bin/dbgate` automáticamente. Licencia MIT confirmada para la edición community.

### Implementación (2026-07-22)

* `scripts/development/install_beekeeper_studio.sh` y `scripts/development/install_dbgate.sh` (`manager=deb-direct` vía `scripts/lib/github_release.sh`, mismo mecanismo que LocalSend/Hoppscotch) — pruebas mockeadas dedicadas nuevas (I46, I47).
* Ambos quedan `requires_manual_validation=yes`.

### Pendiente

Ninguno.

---

# Hito 33

## Ampliación del catálogo: contenedores, Git TUI y virtualización libre

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Podman** (`subcategory=containers`, mismo grupo que Docker/kubectl) — motor de contenedores daemonless/rootless, Apache-2.0, ya está en el repositorio `universe` oficial de Ubuntu (instalación más simple que Docker, que necesita `apt-vendor-repo`). Evaluar si conviven ambos en el catálogo o si amerita alguna nota de "elegir uno u otro" (no son mutuamente excluyentes a nivel de paquete, pero sí a nivel de mensaje al usuario).
* **Lazygit** (`subcategory=git-tools`, mismo grupo que GitHub CLI/GitKraken) — TUI de Git, MIT, ya tiene un PPA propio activo (`ppa:lazygit-team/daily`).
* **virt-manager** (`subcategory=virtualization`, mismo grupo que VirtualBox) — front-end GTK para QEMU/KVM, GPL, sin el Extension Pack propietario que restringe a VirtualBox; paquete en el repositorio oficial de Ubuntu. Investigar si además hace falta gestionar `qemu-kvm`/`libvirt` como dependencia (posible primer caso real de `depends_on` fuera del grupo shell-personalization, ver ADR 0042).

### Investigación (2026-07-22)

* **Podman**: confirmado en `universe` de Ubuntu 24.04 (v4.9) y 26.04 (v5.7). Confirmado que el paquete `podman-docker` (wrapper que crea `/usr/bin/docker`) declara `Conflicts: docker` — no se instala, para que conviva sin problema con Docker (ya en este catálogo). `podman-compose` queda fuera también, a propósito (alcance mínimo).
* **Lazygit**: confirmado que el PPA histórico (`ppa:lazygit-team/daily`) está descontinuado (404 en Launchpad, con un issue del propio repo confirmándolo). Único mecanismo viable: el paquete oficial de `universe`, desactualizado frente a GitHub (`0.57.0` vs `v0.63.1` al momento de la investigación) — mismo riesgo aceptado y documentado que fzf.
* **virt-manager**: confirmado en los repositorios oficiales de Ubuntu, junto con `qemu-kvm`/`libvirt-daemon-system`/`libvirt-clients`/`bridge-utils` (necesarios para funcionar completo, no gestionados como `depends_on` separado sino como parte del mismo `packages=` del instalador — más simple que un caso real de `depends_on`, ya que se instalan siempre juntos). Requiere agregar el usuario a **dos** grupos (`libvirt` y `kvm`, no uno). `cpu-checker` (paquete pequeño, provee `kvm-ok`) se agrega para advertir si el hardware no soporta virtualización — advertencia informativa, no bloquea la instalación.

### Implementación (2026-07-22)

* `scripts/development/install_podman.sh` y `scripts/development/install_lazygit.sh` (`manager=apt`, apt-simple estándar) — agregados al test parametrizado existente `tests/test_terminal_apps_apt_simple_contract.sh` (I25), sin sumar IDs nuevos.
* `scripts/development/install_virt_manager.sh` (`manager=apt`, apt-simple con 6 paquetes) — `install_tool()` agrega los grupos `libvirt`/`kvm`, habilita `libvirtd` vía `systemctl` (guardado con `command -v`, no aplica sin systemd real) y advierte (sin bloquear) si `kvm-ok` reporta falta de soporte. Prueba mockeada dedicada nueva (I48).
* Podman/Lazygit quedan `requires_manual_validation=no` (apt-simple estándar); virt-manager queda `requires_manual_validation=yes` (requiere hardware/kernel real para validar KVM de verdad).

### Pendiente

Ninguno.

---

# Hito 34

## Ampliación del catálogo: editores libres

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=editors`):

* **VSCodium** (`subcategory=gui-editors`, mismo grupo que Visual Studio Code) — mismo binario de VS Code sin telemetría de Microsoft ni marca registrada; tiene su propio repositorio APT documentado.
* **Neovim** (`subcategory=terminal-editors`, mismo grupo que Vim) — se agrega como complemento, no reemplazo de Vim (LSP nativo, desarrollo más activo). Confirmar si conviene distinguir "Vim clásico" de "Neovim" como dos herramientas separadas y coexistentes en el catálogo (mismo criterio que Ghostty/Terminator/WezTerm conviviendo en `terminals`).

### Investigación (2026-07-22)

* **VSCodium**: confirmado en vivo el repo APT oficial moderno (`repo.vscodium.dev/vscodium.sources`, DEB822 completo + `repo.vscodium.dev/vscodium.gpg`, ya lista para `signed-by`) — mismo patrón que Brave/ngrok (`apt_vendor_repo_fetch_file_plain`, sin construir línea `deb [...]` a mano). Paquete y binario: `codium` (no `vscodium`).
* **Neovim**: confirmado que Ubuntu 24.04 trae 0.9.5 en `universe` vs v0.12.x en GitHub Releases — brecha real de 3 versiones mayores, mayor que fzf/lazygit. Existe `ppa:neovim-ppa/stable` activo, pero el propio Launchpad advierte explícitamente que "the Neovim team does not maintain the PPA packages" — se prefiere el paquete oficial de Ubuntu (apt-simple) antes que un PPA de terceros no verificado como oficial. Se confirma que conviene distinguirlo de Vim como dos herramientas separadas y coexistentes (mismo criterio que Ghostty/Terminator/WezTerm).

### Implementación (2026-07-22)

* `scripts/editors/install_vscodium.sh` (`manager=apt-vendor-repo` vía `apt_vendor_repo_fetch_file_plain`) — prueba mockeada dedicada nueva (I49), mismo patrón que Brave.
* `scripts/editors/install_neovim.sh` (`manager=apt`, apt-simple) — agregado al test parametrizado existente `tests/test_terminal_apps_apt_simple_contract.sh` (I25), sin sumar un ID nuevo.
* VSCodium queda `requires_manual_validation=yes`; Neovim queda `requires_manual_validation=no` (apt-simple estándar).

### Pendiente

Ninguno.

---

# Hito 35

## Ampliación del catálogo: gráficos

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=multimedia`/`subcategory=graphics`, mismo grupo que GIMP):

* **Inkscape** — editor de gráficos vectoriales, GPL-3.0, complementario a GIMP (que es solo raster).
* **Krita** — pintura digital, GPL-3.0, complementario a GIMP.

### Investigación (2026-07-22)

* **Inkscape**: confirmado que el paquete de Ubuntu 24.04 (1.2.2) queda 2 versiones mayores atrás de la estable actual (1.4.4). Confirmado en vivo (Launchpad) el PPA oficial `ppa:inkscape.dev/stable`, mantenido por el propio equipo "Inkscape Developers" — mismo criterio de priorizar la fuente más actualizada ya aplicado a GIMP.
* **Krita**: confirmado snap oficial `krita`, publicado por la cuenta verificada de la Krita Foundation (`validation: verified` vía la API de Snapcraft), con una versión más actualizada (5.2.11) que el paquete de Ubuntu (5.2.2). Confirmado que, a diferencia de GIMP, no requiere `--classic`.
* Al implementar, se detectó y corrigió una inconsistencia preexistente en `setup.js`: GIMP y OBS Studio habían quedado con `category: 'SYSTEM'` en el menú interactivo pese a que la recategorización del catálogo (mismo día, ver ADR relacionado a `category=multimedia`) ya los movió a `category=multimedia` en `tools_catalog.sh` — corregido junto con el agregado de Inkscape/Krita al mismo bloque del menú.

### Implementación (2026-07-22)

* `scripts/system/install_inkscape.sh` (`manager=apt-vendor-repo` vía PPA, mismo patrón que KeePassXC/ULauncher) — prueba mockeada dedicada nueva (I50).
* `scripts/system/install_krita.sh` (`manager=snap`, sin `--classic`) — agregado a los tests parametrizados existentes del grupo Snap (I10/I22).
* Ambos quedan `requires_manual_validation=yes`.

### Pendiente

Ninguno.

---

# Hito 36

## Ampliación del catálogo: comunicación y notas open source

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=productivity`):

* **Element** (`subcategory=communication`, mismo grupo que Slack/Discord/Telegram Desktop/Zoom) — cliente oficial del protocolo Matrix, Apache-2.0, repo APT oficial.
* **Signal Desktop** (`subcategory=communication`) — cliente de Signal Messenger, AGPL-3.0, repo APT oficial de signal.org.
* **Joplin** (`subcategory=notes`, mismo grupo que Obsidian) — alternativa 100% FOSS a Obsidian (que es gratis pero de código cerrado), AGPL-3.0, repo APT oficial.

### Investigación (2026-07-22)

* **Element**: confirmado en vivo el repo APT oficial (`packages.element.io/debian`), con clave ya lista para `signed-by` (sin `gpg --dearmor`). A diferencia de Brave/VSCodium, NO publican un archivo `.sources` completo — la línea de repo se construye a mano, con distro fija `default` (no depende de la versión real de Ubuntu, mismo patrón que Slack/ngrok). Paquete y binario: `element-desktop`.
* **Signal Desktop**: confirmado en vivo que combina ambos sub-mecanismos de `apt_vendor_repo.sh` en un mismo instalador (primer caso real de este proyecto): la clave requiere `gpg --dearmor`, pero el `.sources` SÍ viene completo y listo. El propio `.sources` oficial fija la ruta del keyring en `/usr/share/keyrings/signal-desktop-keyring.gpg` — el instalador debe dejar la clave exactamente ahí para que coincidan.
* **Joplin**: confirmado que no publica repositorio APT ni snap oficial como principal — el mecanismo recomendado es el script `Joplin_install_and_update.sh` (`curl | bash`). **Hallazgo real inspeccionando el script**: instala el AppImage en `~/.joplin/Joplin.AppImage` (con un archivo `~/.joplin/VERSION` junto al lanzador `.desktop`), sin crear ningún symlink en el PATH — incompatible con la convención genérica `~/.local/bin/<binario>` del resto del grupo `curl-script`. Se reutiliza `curl_script_run` (scripts/lib/curl_script.sh) solo para el paso de descarga/ejecución, con `check_status`/`uninstall_tool` propios (mismo criterio de adaptación que Ollama).

### Implementación (2026-07-22)

* `scripts/productivity/install_element.sh` (`manager=apt-vendor-repo`, `fetch_file_plain` + `write_list`, mismo mecanismo que ngrok) — prueba mockeada dedicada nueva (I51).
* `scripts/productivity/install_signal_desktop.sh` (`manager=apt-vendor-repo`, combina `fetch_key_dearmored` + `fetch_file_plain`) — prueba mockeada dedicada nueva (I52).
* `scripts/productivity/install_joplin.sh` (`manager=curl-script`, `check_status`/`uninstall_tool` propios) — prueba mockeada dedicada nueva (I53).
* Los 3 quedan `requires_manual_validation=yes`.

### Pendiente

Ninguno.

---

# Hito 37

## Ampliación del catálogo: gaming open source

**Prioridad**

Media

**Estado**

Done

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=productivity`/`subcategory=gaming`, mismo grupo que Steam):

* **Lutris** — gestor de bibliotecas de juegos multi-plataforma (Wine/Proton/emuladores/nativos), GPL-3.0, en apt/repo propio.
* **Heroic Games Launcher** — launcher FOSS para Epic Games Store/GOG/Amazon Games (usa Legendary como backend), publica `.deb`/AppImage en GitHub Releases.

### Investigación (2026-07-22)

* **Lutris**: confirmado que el paquete oficial de Ubuntu vive en `multiverse` (no `universe`), desactualizado (0.5.14-2 en 24.04 vs v0.5.22 en GitHub). Existe un PPA oficial del propio equipo (`ppa:lutris-team/lutris`, mantenido por el lead del proyecto), pero la propia documentación de lutris.net recomienda en su lugar el `.deb` de GitHub Releases — se prefiere esa fuente por consistencia con el resto del catálogo (mismo mecanismo `deb-direct` ya usado para casos similares). Binario confirmado en `/usr/games/lutris` (ruta ya en el PATH por defecto de Ubuntu).
* **Heroic Games Launcher**: confirmado que publica un único asset `.deb` sin ambigüedad (`Heroic-<version>-linux-amd64.deb`) en los últimos 3 releases, sin el problema de releases mixtos "solo-hotfix" ya visto con Hoppscotch/DbGate. Paquete y binario: `heroic` (el `postinst` crea el symlink en `/usr/bin` automáticamente, verificado inspeccionando el `.deb` real).

### Implementación (2026-07-22)

* `scripts/productivity/install_lutris.sh` y `scripts/productivity/install_heroic.sh` (`manager=deb-direct` vía `scripts/lib/github_release.sh`, mismo mecanismo que LocalSend/Hoppscotch/Beekeeper Studio/DbGate) — pruebas mockeadas dedicadas nuevas (I54, I55).
* Ambos quedan `requires_manual_validation=yes`.

### Pendiente

Ninguno.

---

# Hito 38

## Ampliación del catálogo: CLI moderna — clientes HTTP

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=system`/`subcategory=cli-utils`, mismo grupo que fzf/thefuck/jq/yq):

* **HTTPie** — cliente HTTP de línea de comandos con salida legible, BSD-3-Clause.
* **xh** — reimplementación de HTTPie en Rust, mucho más rápida, MIT/Apache-2.0.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 39

## Ampliación del catálogo: CLI moderna — utilidades de sistema y navegación

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=system`/`subcategory=cli-utils`):

* **dust** — reemplazo de `du` con salida en árbol, Apache-2.0.
* **duf** — reemplazo de `df` con salida más legible, MIT.
* **procs** — reemplazo de `ps`, MIT.
* **zoxide** — reemplazo inteligente de `cd` (aprende rutas frecuentes), MIT.
* **btop** — monitor de recursos en TUI, Apache-2.0.
* **tldr** — páginas de ayuda simplificadas (alternativa a `man`), varias licencias FOSS según el cliente elegido — confirmar cuál (hay varios clientes de `tldr-pages`, p. ej. el oficial en Node o `tealdeer` en Rust).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 40

## Ampliación del catálogo: terminales adicionales

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=system`/`subcategory=terminals`, mismo grupo que Ghostty/Terminator/WezTerm):

* **Kitty** — terminal acelerada por GPU, GPL-3.0, ya está en el repositorio oficial de Ubuntu.
* **Alacritty** — terminal acelerada por GPU, Apache-2.0, con PPA propio activo (`ppa:mmstick76/alacritty`).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 41

## Campo `description` retroactivo para las 74 herramientas existentes

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto, ver [ADR 0044](adr/0044-campo-description-en-el-catalogo.md): agregar `description=<texto corto>` a las 74 entradas ya existentes en `scripts/lib/tools_catalog.sh` (trabajo de una sola pasada, no incremental — separado de cualquier otro Hito para no mezclar una migración retroactiva grande con cambios funcionales). Incluye investigar y decidir el mecanismo concreto para mostrarla en `setup.js` (checklist interactivo de `inquirer`) además de `setup.sh list`/`info`.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 42

## Ampliación del catálogo: CLIs de nube e infraestructura como código

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Terraform** (`category=development`, subcategoría nueva a definir en la investigación — p. ej. `iac`) — HashiCorp dejó de publicar Terraform bajo licencia FOSS (BUSL desde 2023); investigar si conviene igual incluirlo (uso gratuito permitido salvo competir con HashiCorp) o solo ofrecer OpenTofu.
* **OpenTofu** — fork FOSS (MPL-2.0) de Terraform tras el cambio de licencia, mantenido por la Linux Foundation; candidato preferido si se prioriza estrictamente FOSS.
* **AWS CLI**, **Azure CLI**, **Google Cloud CLI** (mismo grupo, subcategoría `iac` o una dedicada `cloud-cli`) — clientes CLI oficiales de cada proveedor; cada uno con su propio mecanismo de instalación oficial (investigar: AWS CLI vía instalador `.zip` oficial, Azure CLI vía repo APT/Microsoft, Google Cloud CLI vía repo APT propio de Google).
* **pnpm** (`category=development`, `subcategory=package-managers`, mismo grupo que Yarn) — gestor de paquetes Node.js, mismo mecanismo `manager=mise` que Yarn (ver [ADR 0017](adr/0017-mise-instala-yarn-pnpm-directo.md), que ya contempla pnpm vía Mise sin haberlo implementado hasta ahora).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 43

## Ampliación del catálogo: herramientas multimedia de línea de comandos

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=multimedia`, subcategoría nueva a definir en la investigación — p. ej. `conversion`, distinta de `capture`/`codecs`/`graphics`/`playback` ya existentes):

* **ImageMagick** — suite de manipulación de imágenes por línea de comandos, en los repositorios oficiales de Ubuntu.
* **FFmpeg** — conversión/procesamiento de audio y video por línea de comandos, en los repositorios oficiales de Ubuntu.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 44

## Ampliación del catálogo: seguridad, sincronización y transferencia de archivos

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Bitwarden** (`category=productivity`, `subcategory=security`, mismo grupo que KeePassXC) — gestor de contraseñas, cliente de escritorio FOSS (AGPL-3.0); confirmar mecanismo (snap oficial vs. `.deb` de GitHub Releases).
* **Syncthing** (`category=productivity`, `subcategory=file-sharing`, mismo grupo que LocalSend) — sincronización de archivos P2P sin nube, MPL-2.0; probablemente ya está en los repositorios oficiales de Ubuntu.
* **FileZilla** (`category=productivity`, `subcategory=file-sharing`) — cliente FTP/SFTP, GPL-2.0, en los repositorios oficiales de Ubuntu.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 45

## Ampliación del catálogo: CLI moderna — archivos y compresión

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=system`/`subcategory=cli-utils`):

* **ripgrep** (`rg`) — búsqueda de texto recursiva, mucho más rápida que `grep`, MIT/Unlicense, en los repositorios oficiales de Ubuntu.
* **fd** (`fd-find`/`fdfind` en Ubuntu) — reemplazo de `find`, MIT/Apache-2.0, en los repositorios oficiales de Ubuntu.
* **bat** (`batcat` en Ubuntu) — reemplazo de `cat` con resaltado de sintaxis, MIT/Apache-2.0, en los repositorios oficiales de Ubuntu.
* **eza** — reemplazo de `ls` (fork mantenido de `exa`), MIT, con repositorio APT propio (`deb.gierens.de`).
* **tree** — listado de directorios en árbol, GPL-2.0, en los repositorios oficiales de Ubuntu.
* **unzip**, **zip** — utilidades de compresión estándar, en los repositorios oficiales de Ubuntu.
* **rsync** — sincronización/transferencia de archivos, GPL-3.0, en los repositorios oficiales de Ubuntu.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 46

## Ampliación del catálogo: redes y túneles

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto. **Renombra el alcance de la subcategoría `networking`** (hoy solo ngrok, dentro de `category=development`) a un ámbito más amplio de redes y túneles — investigar si conviene mantenerla en `development` o moverla a `system`, dado que estas herramientas son más de infraestructura de red que de desarrollo puro:

* **WireGuard** — VPN moderna integrada en el kernel de Linux, GPL-2.0, en los repositorios oficiales de Ubuntu.
* **OpenVPN** — VPN tradicional, GPL-2.0, en los repositorios oficiales de Ubuntu.
* **Tailscale** — mesh VPN basada en WireGuard, cliente open-source (BSD-3-Clause) aunque el servicio de coordinación es propietario (con capa gratuita); repositorio APT oficial propio.
* **Cloudflare Tunnel** (`cloudflared`) — túneles salientes sin abrir puertos; el cliente es open-source (Apache-2.0/BSD según el componente), aunque depende del servicio de Cloudflare; repositorio APT oficial propio.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 47

## Ampliación del catálogo: extras de terminal (visuales y decorativos)

**Prioridad**

Baja

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=system`/`subcategory=extras`, mismo grupo que cmatrix):

* **pipes.sh** — salvapantallas de terminal de tuberías animadas, script Bash sin paquete propio (instalación probable vía `git-clone` o descarga directa del script).
* **fortune** (`fortune-mod`) — frases aleatorias, en los repositorios oficiales de Ubuntu.
* **cowsay** — arte ASCII con frases, en los repositorios oficiales de Ubuntu.
* **lolcat** — colorea la salida de terminal, en los repositorios oficiales de Ubuntu (gem de Ruby empaquetado) o vía gem directo.
* **figlet** — arte ASCII de texto grande, en los repositorios oficiales de Ubuntu.
* **toilet** — similar a figlet con más efectos, en los repositorios oficiales de Ubuntu.
* **xeyes** (paquete `x11-apps`) — ojos que siguen el cursor, en los repositorios oficiales de Ubuntu.
* **fastfetch** — reemplazo moderno de neofetch (info del sistema con arte ASCII), MIT, con PPA propio o binario de GitHub Releases (neofetch está discontinuado, fastfetch es el sucesor activo recomendado por la comunidad).
* **pokemon-colorscripts** — arte ASCII de Pokémon coloreado en terminal, sin paquete oficial de Ubuntu, instalación vía clon de repositorio GitHub.
* **cbonsai** — árbol bonsai ASCII animado, en los repositorios oficiales de Ubuntu (24.04+) o compilación desde fuente en versiones más viejas.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 48

## Ampliación del catálogo: virtualización de entornos de desarrollo y acceso remoto

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Vagrant** (`category=development`, `subcategory=virtualization`, mismo grupo que VirtualBox/virt-manager, Hito 33) — orquestación de máquinas virtuales de desarrollo reproducibles, licencia BUSL desde 2023 (igual que Terraform, ver Hito 42) — investigar si el uso gratuito sigue siendo viable o si conviene evaluar alternativas FOSS (p. ej. Vagrant sigue siendo de código fuente disponible, pero no OSI-approved desde el cambio de licencia).
* **Remmina** (`category=productivity`, subcategoría nueva — p. ej. `remote-access`) — cliente de acceso remoto (RDP/VNC/SSH/SPICE), GPL-2.0, en los repositorios oficiales de Ubuntu.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 49

## Ampliación del catálogo: editor de terminal y prompt de shell

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Helix** (`category=editors`, `subcategory=terminal-editors`, mismo grupo que Vim/Neovim, Hito 34) — editor modal con LSP integrado por defecto (sin plugins adicionales), MPL-2.0, con PPA propio o snap oficial.
* **Starship** (`category=system`, `subcategory=shell-personalization`, mismo grupo que Oh My Zsh/Powerlevel10k) — prompt de shell multi-shell (bash/zsh/fish/nu), ISC License, instalador oficial `curl \| sh` (mismo mecanismo `curl-script` ya usado por las CLIs de IA, ver ADR 0037) o binario de GitHub Releases.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 50

## Ampliación del catálogo: multimedia adicional

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=multimedia`):

* **Kooha** (`subcategory=capture`, mismo grupo que OBS Studio/Cheese) — grabador de pantalla simple para GNOME/Wayland, GPL-3.0, Flatpak (sin paquete apt/snap oficial confirmado — investigar si este proyecto ya soporta Flatpak como mecanismo o si sería el primer caso).
* **MPV** (`subcategory=playback`, mismo grupo que VLC) — reproductor multimedia minimalista basado en mplayer/mplayer2, GPL-2.0/LGPL-2.1, en los repositorios oficiales de Ubuntu.
* **Papers** (`category=productivity`, `subcategory=office`, mismo grupo que LibreOffice/OnlyOffice/Okular) — visor/editor de documentos y PDF de GNOME (sucesor de Evince), GPL-3.0; investigar disponibilidad en Ubuntu 24.04/26.04 (proyecto relativamente nuevo dentro del ecosistema GNOME).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 51

## Ampliación del catálogo: notas y lanzadores de aplicaciones

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Logseq** (`category=productivity`, `subcategory=notes`, mismo grupo que Obsidian/Joplin, Hito 36) — notas en Markdown local con vista de grafo, AGPL-3.0, solo AppImage/Flatpak (sin paquete apt/snap oficial confirmado, mismo patrón de incertidumbre que LocalSend/SoapUI).
* **Albert** (`category=productivity`, mismo grupo que ULauncher — evaluar si comparten subcategoría nueva `launchers`) — lanzador de aplicaciones extensible, GPL-3.0, con PPA propio (`ppa:nilarimogard/webupd8` está descontinuado — verificar el PPA activo actual del proyecto antes de implementar).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 52

## Ampliación del catálogo: análisis de red

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto:

* **Wireshark** (subcategoría a definir — evaluar si encaja en el ámbito ampliado de "redes y túneles" del Hito 46 o merece la suya propia, ya que es análisis/diagnóstico, no VPN/túnel) — analizador de protocolos de red, GPL-2.0, en los repositorios oficiales de Ubuntu. Requiere el grupo `wireshark`/capacidades de captura de paquetes sin root — investigar si el instalador debe gestionar ese paso de configuración (similar en espíritu al grupo `vboxusers` de VirtualBox, Hito 24).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 53

## Ampliación del catálogo: interfaces locales de IA

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto (`category=ai`, `subcategory=local-models`, mismo grupo que Ollama, ver [ADR 0043](adr/0043-consolidar-herramientas-de-ia-en-category-ai.md)) — interfaces/frontends para correr modelos de lenguaje localmente, complementarias a Ollama (que es solo el runtime, sin interfaz gráfica propia):

* **Open WebUI** — interfaz web self-hosteada para Ollama/OpenAI-compatible, MIT (con una cláusula de marca registrada adicional desde 2025 — confirmar en la investigación que no restringe el uso local antes de implementar), se instala vía Docker o `pip`, no como paquete del sistema — investigar el mecanismo más apropiado para este catálogo.
* **AnythingLLM** — interfaz de escritorio + RAG local, MIT (aplicación núcleo), `.deb`/AppImage vía GitHub Releases.
* **LM Studio** — interfaz de escritorio para correr modelos locales, **gratuito pero de código cerrado** (a diferencia de Open WebUI/AnythingLLM) — confirmar con el dueño del proyecto si se incluye pese a no ser FOSS (mismo criterio ya aceptado para Obsidian/Discord/Slack/etc., que tampoco son FOSS) antes de implementar.

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Hito 54

## Instalar Nerd Font como configuración post-instalación de Powerlevel10k (y Starship)

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Ninguno.

### Objetivo

Registrado el 2026-07-22, pedido explícito del dueño del proyecto: Powerlevel10k (ya en el catálogo) requiere una Nerd Font instalada y habilitada en la terminal para renderizar sus íconos correctamente (prerrequisito documentado oficialmente por el propio proyecto) — hoy ese requisito no está gestionado por este instalador. Starship (Hito 49) tiene el mismo requisito para sus símbolos/íconos por defecto.

**Corrección de enfoque (2026-07-22):** no se trata de un instalador separado con `depends_on` (ese mecanismo rechaza en vez de resolver, ver ADR 0042 §"Dependencias entre instaladores" — apropiado quizás para otro caso, pero no para este). El dueño del proyecto pidió específicamente el patrón ya usado por **Flameshot** (Hito 17, `configure_tool()`, el 7° verbo de ADR 0042, `configure`): la instalación de la fuente se ejecuta como **configuración post-instalación** de `install_powerlevel10k.sh` (y `install_starship.sh` cuando exista, Hito 49), no como un instalador ni una dependencia separada que el usuario deba resolver a mano.

* Implementar `configure_tool()` en `install_powerlevel10k.sh`: descarga e instala la Nerd Font recomendada oficialmente por el propio proyecto (**MesloLGS NF**) a `~/.local/share/fonts` (o la ruta estándar equivalente), corre `fc-cache` para refrescar el cache de fuentes. Mismo criterio de rechazo que Flameshot: si Powerlevel10k no está instalado, `configure` rechaza explícitamente en vez de instalar la fuente igual.
* Idempotente (mismo criterio que `configure_tool()` de Flameshot): si la fuente ya está instalada, no la vuelve a descargar.
* Investigar si además hace falta (o es siquiera automatizable) configurar el emulador de terminal para que use la fuente instalada — Flameshot, en su propia configuración, se limitó a lo automatizable vía `gsettings` (el atajo de teclado) sin tocar configuración de apps de terceros; aquí el equivalente sería tocar la configuración de Terminator/Ghostty/WezTerm/etc., que varía por terminal — probablemente quede fuera de alcance igual que quedó fuera de Flameshot, documentándolo explícitamente en vez de intentar cubrir todos los emuladores de terminal del catálogo.
* Extender el mismo `configure_tool()` (o uno propio) a `install_starship.sh` una vez implementado en el Hito 49, reutilizando la misma lógica de instalación de fuente en vez de duplicarla (posible candidato a extraer a una función compartida si ambos casos terminan siendo prácticamente idénticos).

### Pendiente

Todo — investigación e implementación no comenzadas.

---

# Preguntas resueltas por el dueño del proyecto (2026-07-15)

Migradas desde la evaluación inicial del repositorio (2026-07-13) y resueltas en una revisión de inventario de herramientas. Las decisiones de arquitectura resultantes están en `docs/adr/` (0016–0021) y el inventario actualizado en `docs/TOOLS.md`.

1. **Versiones de Node vía Mise:** última estable + últimas 2 LTS. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
2. **Archivo de versión por proyecto:** se soportan `.nvmrc` y `.node-version`, además de `mise.toml`. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
3. **Yarn/pnpm:** los instala Mise directamente, no Corepack. Ver [ADR 0017](adr/0017-mise-instala-yarn-pnpm-directo.md).
4. **Terminal:** se mantiene Terminator.
5. **Oh My Zsh y Powerlevel10k:** se mantienen ambos; al reutilizar `/home` se respalda/reutiliza la personalización existente en vez de sobrescribirla. Ver [ADR 0021](adr/0021-reutilizar-personalizacion-shell-en-home.md).
6. **Postman, Insomnia, GitKraken:** se mantienen los tres.
7. **Bruno:** no se agrega; se mantienen Postman e Insomnia. **Revertido el 2026-07-22:** el dueño del proyecto pidió explícitamente agregarlo (ver Hito 31) — Postman/Insomnia se mantienen también, Bruno se suma como tercera opción, no como reemplazo.
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
