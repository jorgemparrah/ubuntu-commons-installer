# ACCEPTANCE_2_7.md

## Aceptación de los Hitos 2 al 7 — cierre de la fase de estabilización

Este documento registra la evidencia concreta (prueba automatizada, revisión de código o verificación manual documentada) que respalda cada criterio de aceptación de los Hitos 2 a 7 de `docs/ROADMAP.md`, al cierre de la fase de estabilización iniciada tras la auditoría del 2026-07-16.

Una casilla marcada `[x]` en el roadmap **no se considera evidencia por sí sola**. Cada fila de este documento enlaza el criterio con la prueba o revisión concreta que lo respalda.

### Metadatos de esta evaluación

| Campo | Valor |
|---|---|
| Fecha | 2026-07-16 |
| Commit evaluado | `0f4dc5bd2424b7d7b5be8bff7e1f3f73d0946cbb` (rama `cierre-estabilizacion-hitos-2-7`, sobre `main`), que incluye íntegramente las correcciones de la auditoría de estabilización (commits `e0d3104`, `bf6456f`, `ba6dda9`, `a4d0b3a`, `556d6ca`, `cbe0b97` en `main`) |
| Sistema host | Ubuntu 24.04.4 LTS, kernel 6.17.0-29-generic |
| Docker | 29.6.1 (build 8900f1d) |
| Bash | 5.2.21(1)-release |
| Node.js (host, no usado para ejecutar código del proyecto) | v26.1.0 |
| Imágenes Ubuntu probadas | 24.04 y 26.04 — ambas exitosas, **sin limitaciones** (no fue necesario invocar la salvedad de imagen no disponible) |
| Ubicación de los logs | `/tmp/ubuntu-workstation-tests/build-and-test-all-20260716T185143.log` (corrida completa) y `/tmp/ubuntu-workstation-tests/build-and-test-all-latest.log` (symlink estable a la corrida más reciente) |
| Fallos conocidos | Ninguno en esta corrida. Limitaciones de cobertura pendientes: ver Hito 7 más abajo (M06, M07, ruta legada de `install_nodejs.sh`) |

### Batería ejecutada

**Nivel 1** (dentro de un contenedor `ubuntu-workstation-test:24.04`, jamás en el host — ver `docs/TESTING.md`):

```
bash -n setup.sh
find scripts tests -type f -name '*.sh' -exec bash -n {} \;
node --check setup.js
node --check scripts/lib/status_contract.js
bash tests/test_router.sh
bash tests/test_doctor.sh
bash tests/test_backup.sh
bash tests/test_backup_move_dir.sh
bash tests/test_migrations.sh
node tests/test_status_mapping.js
```

Resultado: **123 pruebas, 0 fallos** (45 router + 7 doctor + 13 backup + 17 backup_move_dir + 12 migraciones + 29 mapeo de estado).

**Nivel 2 — batería Docker completa** (`bash tests/docker/build-and-test-all.sh`, único punto de entrada):

| Caso | Escenario | Ubuntu 24.04 | Ubuntu 26.04 |
|---|---|---|---|
| U01-U08 | Batería general (imagen base) | OK | OK |
| BOOT01 | Bootstrap interactivo vía Mise, sin NVM | OK | OK |
| M01,M02,M05,M08 | Migración NVM→Mise instalando NVM en tiempo de ejecución | OK | OK |
| M03,M05,M08 | Migración con NVM + 1 versión preinstalada | OK | OK |
| M04,M05,M08 | Migración con NVM + 2 versiones (alias `default` ≠ versión más alta) | OK | OK |

`RESULTADO: TODO PASÓ`. 10/10 combinaciones en verde, código de salida `0`.

ShellCheck no está disponible en este entorno de evaluación; no se instaló (regla del proyecto: nunca instalar herramientas de validación automáticamente). Su ausencia no bloquea el cierre porque `bash -n` (sintaxis) y las 123 pruebas de Nivel 1 ya cubren el comportamiento funcional.

---

## Hito 2 — Bootstrap

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| El bootstrap se completa exitosamente sin modificar la configuración del usuario | `scripts/bootstrap/preflight.sh` es de solo lectura (`preflight_core`/`preflight_interactive`); no escribe en `$HOME` | `tests/test_router.sh` (incluye casos de preflight) | OK | — |
| `setup.sh` funciona como router de comandos (`interactive`, `help`, `--help`, `version`) | Revisión de código: `setup.sh` despacha por `case` sobre `$1` | `tests/test_router.sh` (45 casos) | OK | — |
| El bootstrap interactivo no instala NVM (corrección de la auditoría) | Revisión de código: `ensure_node_via_mise()` reemplaza `check_and_install_nodejs()`; `install_nodejs.sh` requiere `UCI_ALLOW_LEGACY_NVM=1` explícito | `BOOT01` (Docker, imagen base, ambas versiones de Ubuntu) | OK | Corregido en la auditoría de estabilización, ver `docs/ROADMAP.md` Hito 2 |

**Pendiente documentado, no bloqueante:** "Verificación de conexión a internet" quedó fuera del alcance mínimo solicitado para este hito (ver roadmap); no es una falla, es alcance diferido explícito.

**Determinación:** todos los criterios exigibles están demostrados por prueba o revisión de código concreta, sin brechas abiertas. → **Done**.

---

## Hito 3 — Idempotencia del menú y modelo de estado enriquecido

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| Una herramienta ya instalada y sana no dispara `uninstall`/`install` | Revisión de código: mapeo estado→acción en `setup.js` (`normalizeStatus` + tabla de acciones) | `tests/test_status_mapping.js` | OK (29 casos) | — |
| `reinstall` sigue disponible, solo como acción explícita | Revisión de código: `confirmForcedReinstalls` en `setup.js` pide confirmación antes de forzar | `tests/test_status_mapping.js` | OK | — |
| Al menos un instalador expone el contrato de estado enriquecido de punta a punta | Revisión de código: `scripts/editors/install_vim.sh` implementa `status`/`update`/`repair` | `tests/test_router.sh` (invoca el instalador de referencia) | OK | — |
| Un error real de ejecución de `status` no se confunde con `NOT_INSTALLED` (hallazgo de la auditoría) | Revisión de código: `resolveStatusFromExecResult`/`resolveStatusFromExecError` en `scripts/lib/status_contract.js` distinguen ENOENT/permiso denegado/crash sin salida reconocible → `UNKNOWN` | `tests/test_status_mapping.js` (8 de los 29 casos cubren específicamente este hallazgo) | OK | Corregido en la auditoría; antes se reportaba `NOT_INSTALLED` incorrectamente |

**Determinación:** todos los criterios están demostrados, incluida la corrección de la auditoría. → **Done**.

---

## Hito 4 — Doctor

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| Doctor nunca modifica el sistema | Revisión de código: `scripts/diagnostics/doctor.sh` solo lee (no hay `mkdir`/`rm`/escritura fuera de logs) | `tests/test_doctor.sh` (incluye verificación explícita de que `doctor` no modifica `$HOME`) | OK (7 casos) | — |
| Produce un reporte legible | Revisión manual: salida de `setup.sh doctor` verificada en corridas de Nivel 1/Docker | `tests/test_doctor.sh` | OK | — |
| Soporta modo verbose (`--verbose`/`-v`) | Revisión de código: flag parseado en `setup.sh doctor` | `tests/test_doctor.sh` | OK | — |
| Usa el contrato de estado enriquecido del Hito 3 | Nota de diseño ya registrada en el roadmap: Doctor inspecciona herramientas de sistema (Git, Docker, Node, Mise, AWS CLI, kubectl, Helm) con información más rica que instalado/no-instalado (origen de Node, estado del demonio Docker), no reusa literalmente el contrato de `scripts/*/install_*.sh` | `tests/test_doctor.sh` | OK | Ajuste incremental (conectar Doctor al `status` de cada instalador) queda para el futuro, no bloqueante — ya documentado en el roadmap |

**Determinación:** todos los criterios exigidos están demostrados; la nota de diseño sobre el alcance del contrato de estado es una aclaración de alcance, no una brecha. → **Done**.

---

## Hito 5 — Gestor de Backups

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| Backups con timestamp único por sesión | Revisión de código: `backup_init_session` genera `<timestamp>-<pid>` | `tests/test_backup.sh` | OK (13 casos) | — |
| Sin sobrescritura de sesión ni de archivo ya respaldado | Revisión de código: `backup_init_session`/`backup_copy_file` verifican existencia antes de escribir | `tests/test_backup.sh` | OK | — |
| Sin comportamiento destructivo — `backup_move_dir` solo borra el origen si el manifiesto completo coincide | Revisión de código: `backup_dir_manifest` compara rutas, tipos, permisos, tamaños, symlinks y hashes SHA-256 (corregido en la auditoría; antes solo contaba archivos) | `tests/test_backup_move_dir.sh` (17 casos, incluidos 5 negativos deliberados: archivo alterado con mismo conteo, symlink retargeteado, etc.) | OK | Corrección crítica de la auditoría de estabilización 2026-07-16 |
| Soporta `--dry-run` (no crea nada, solo reporta) | Revisión de código: rama `--dry-run` en `setup.sh backup` no invoca `backup_copy_*`/`backup_move_dir` | `tests/test_backup.sh` | OK | — |

**Pendiente documentado, no bloqueante:** "archivos modificados por instaladores" está explícitamente diferido al Hito 11 (modernización de instaladores) en el roadmap — no es un criterio de aceptación de este hito, es alcance futuro ya declarado.

**Determinación:** todos los criterios de aceptación del hito, incluida la corrección crítica de integridad de `backup_move_dir`, están demostrados por prueba automatizada. → **Done**.

---

## Hito 6 — Framework de migraciones

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| Ejecución repetible (una migración hecha nunca se reaplica) | Revisión de código: marca `.done` verificada antes de ejecutar en `migrations_apply` | `tests/test_migrations.sh` (corre `migrate` dos veces) | OK (12 casos) | — |
| Ejecución segura (`--dry-run` no toca el filesystem; una migración fallida no se marca como hecha y detiene la cadena) | Revisión de código: `migrations.sh` solo escribe la marca `.done` tras un `apply` exitoso; `--dry-run` no invoca `apply` | `tests/test_migrations.sh` | OK | — |
| Historial de migraciones registrado | Revisión de código: `setup.sh migrate --list` lee las marcas `.done` existentes | `tests/test_migrations.sh` | OK | — |

**Determinación:** todos los criterios están demostrados por prueba automatizada, sin brechas. → **Done**.

---

## Hito 7 — Migración NVM → Mise

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| Node ya no depende de NVM (ni en migración, ni en workstation nueva) | Revisión de código: `ensure_node_via_mise()` en el bootstrap interactivo + `001_nvm_to_mise.sh` en la migración | `BOOT01` + `M01-M08` (Docker, ambas versiones de Ubuntu) | OK | Corrección de la auditoría: antes solo era cierto para quien migraba |
| La migración es repetible | Revisión de código: marca `.done` de `migrations.sh` (Hito 6) aplicada a `001_nvm_to_mise` | `M01-M04` (corridas dobles de `migrate`) | OK | — |
| Detección de versiones de Node y paquetes globales de NVM | Revisión de código: `reports/nvm-versions.tsv`, `reports/nvm-global-packages.tsv` generados dentro de la sesión de backup | `M03, M04` (imágenes con NVM preinstalado) | OK | Persistencia agregada en la auditoría; antes solo se imprimía por log |
| `.nvm` movido con verificación de integridad completa, nunca borrado directo | Ver Hito 5 (`backup_move_dir`) | `tests/test_backup_move_dir.sh` + `M01-M04` | OK | — |
| Limpieza de líneas de shell de NVM, solo patrones exactos reconocidos | Revisión de código: `nvm_cleanup_shell_file`/`nvm_is_known_shell_line` en `001_nvm_to_mise.sh` | `M01-M04` + `reports/shell-changes.tsv` | OK | Corrección crítica de la auditoría; antes no existía limpieza, o se hacía con `sed` amplio |
| PATH/ejecutables validados tras migrar (Mise resuelve un `node` ejecutable) | Revisión de código: `migration_validate` en `001_nvm_to_mise.sh` corre `mise which node` | `M01-M04, M08` | OK | — |
| Ningún archivo de shell sigue cargando `$NVM_DIR/nvm.sh` tras la migración | Revisión de código: `migration_validate` falla explícitamente si detecta esta condición | `M05` | OK | — |
| Instalación de Mise: mecanismo documentado y verificado | Revisión de decisión: [ADR 0025](adr/0025-metodo-instalacion-oficial-de-mise.md) registra `curl -fsSL https://mise.run \| sh` como único método soportado, con las 4 verificaciones posteriores obligatorias ya implementadas en código (código de salida, binario presente/ejecutable, versión registrada en log, `mise which node` resuelto) | `M01-M04, BOOT01` (todas ejecutan e implícitamente verifican la instalación de Mise) | OK | Ninguna implementación distinta introducida; la ADR documenta el mecanismo ya existente, sin cambiarlo |

**Brechas explícitamente pendientes, no demostradas por prueba:**

* **M06 — Mise ya instalado antes de migrar:** no existe imagen Docker dedicada a este escenario. El código de `001_nvm_to_mise.sh` tiene una rama para detectar Mise preexistente, pero no hay un caso de prueba automatizado que la ejercite de punta a punta.
* **M07 — `apply` falla a mitad de camino** (por ejemplo, sin red al instalar Mise): no hay imagen ni caso Docker que fuerce esta condición y verifique que la migración no queda a medio marcar como hecha.
* **Ruta legada `install_nodejs.sh uninstall`/`reinstall` con `UCI_ALLOW_LEGACY_NVM=1`:** sigue usando `sed` de patrón amplio, no la limpieza por línea exacta introducida en la auditoría. No se corrigió a propósito (el camino recomendado es `./setup.sh migrate`), pero sigue siendo una ruta destructiva no cubierta por prueba si alguien la fuerza deliberadamente.

**Determinación:** la mayoría de los criterios están demostrados con solidez (10/10 combinaciones Docker en verde, en ambas versiones de Ubuntu), pero quedan tres escenarios explícitamente sin prueba automatizada, uno de ellos (`apply` fallido a mitad de camino) relevante para la robustez del propio framework de migraciones. Por regla del cierre ("mantén en Review cualquier hito con pruebas fallidas o pendientes"), este hito **permanece en Review**, no se marca `Done`.

---

## Resumen de determinación

| Hito | Determinación | Razón |
|---|---|---|
| 2 — Bootstrap | **Done** | Todos los criterios demostrados por prueba/revisión; corrección de la auditoría verificada en Docker |
| 3 — Idempotencia y estado enriquecido | **Done** | Todos los criterios demostrados, incluida la corrección de `UNKNOWN` vs `NOT_INSTALLED` |
| 4 — Doctor | **Done** | Todos los criterios demostrados; nota de diseño sobre alcance del contrato de estado no es una brecha |
| 5 — Gestor de Backups | **Done** | Todos los criterios demostrados, incluida la corrección crítica de `backup_move_dir` |
| 6 — Framework de migraciones | **Done** | Todos los criterios demostrados por prueba automatizada |
| 7 — Migración NVM → Mise | **Review** | M06, M07 y la ruta legada forzada quedan sin prueba automatizada; no se fuerza el cierre pese a que el resto del hito está sólidamente probado |

Ninguna limitación de Ubuntu 26.04 fue encontrada: las 5 combinaciones Docker corrieron exitosamente en ambas versiones soportadas (24.04 y 26.04), sin necesidad de invocar ninguna salvedad de imagen no disponible.
