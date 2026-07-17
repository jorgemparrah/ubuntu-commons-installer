# ACCEPTANCE_2_7.md

## Aceptación de los Hitos 2 al 7 — cierre de la fase de estabilización

Este documento registra la evidencia concreta (prueba automatizada, revisión de código o verificación manual documentada) que respalda cada criterio de aceptación de los Hitos 2 a 7 de `docs/ROADMAP.md`. Se actualiza en dos momentos: el cierre inicial de la fase de estabilización de los Hitos 2-6 (2026-07-16, sección de metadatos original más abajo) y el cierre posterior de las brechas del Hito 7 — M06, M07 y la ruta legada de `install_nodejs.sh` (2026-07-16/17, ver "Cierre del Hito 7" más abajo).

Una casilla marcada `[x]` en el roadmap **no se considera evidencia por sí sola**. Cada fila de este documento enlaza el criterio con la prueba o revisión concreta que lo respalda.

### Metadatos de la evaluación inicial (Hitos 2-6, cierre 2026-07-16)

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
| Fallos conocidos | Ninguno en esta corrida. Limitaciones de cobertura pendientes en ese momento: M06, M07, ruta legada de `install_nodejs.sh` — cerradas en la sección siguiente |

### Metadatos del cierre del Hito 7 (M06, M07, instalador legado)

| Campo | Valor |
|---|---|
| Fecha | 2026-07-17 |
| Commit evaluado | `3f5e8c5` (rama `cierre-hito7-brechas`, sobre `main`) + los cambios de M07/instalador legado/documentación de este cierre |
| Sistema host | Ubuntu 24.04.4 LTS, kernel 6.17.0-29-generic |
| Docker | 29.6.1 (build 8900f1d) |
| Bash | 5.2.21(1)-release |
| Node.js (host, no usado para ejecutar código del proyecto) | v26.1.0 |
| Imágenes Ubuntu probadas | 24.04 y 26.04, **8 combinaciones de imagen** (base, `nvm-single`, `nvm-multi`, `nvm-mise-preexisting` × 2 versiones) — todas exitosas, sin limitaciones |
| Total de pruebas de Nivel 1 (por versión de Ubuntu) | 150 (29 mapeo de estado + 45 router + 7 doctor + 13 backup + 17 backup_move_dir + 12 migraciones + 27 instalador legado de Node) — 300 en total entre 24.04 y 26.04 |
| Ubicación de los logs | Primera corrida (con 1 fallo, ver más abajo): `/tmp/docker_battery_hito7.log` → `/tmp/ubuntu-workstation-tests/build-and-test-all-20260716T201049.log`. Corrida final (todo en verde): `/tmp/docker_battery_hito7_v2.log` → `/tmp/ubuntu-workstation-tests/build-and-test-all-20260716T215020.log` (también disponible en `-latest.log`) |
| Fallos encontrados y corregidos durante esta validación | La primera corrida de `tests/test_install_nodejs_legacy.sh` reportó 1 fallo falso positivo: su propio `grep 'rm -rf.*\.nvm'` detectaba esa cadena dentro del comentario del encabezado de `install_nodejs.sh` (que documenta en prosa qué patrón destructivo tenía el script antes), no código real. Corregido excluyendo líneas de comentario antes de buscar los patrones. Segunda corrida completa: 0 fallos |
| Evidencia de segunda ejecución (idempotencia) | Cada uno de los scripts M02/M03/M04/M06 corre `migrate` dos veces y verifica que no se cree una segunda sesión de backup; `test_nvm_to_mise_fault_injection.sh` (M07) reintenta explícitamente tras cada fallo inyectado y verifica que la segunda corrida sí completa y marca `.done` |
| Limitaciones conocidas | Ninguna. Los tres puntos pendientes al cierre de la fase anterior (M06, M07, ruta legada) quedan resueltos y probados en esta sección |

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
| Backups con timestamp único por sesión | Revisión de código: `backup_init_session` genera un `session-id` con el formato `TIMESTAMP-PID` | `tests/test_backup.sh` | OK (13 casos) | — |
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
| Instalación de Mise: mecanismo documentado y verificado | Revisión de decisión: [ADR 0025](adr/0025-metodo-instalacion-oficial-de-mise.md) registra `curl -fsSL https://mise.run \| sh` como único método soportado, con las 4 verificaciones posteriores obligatorias ya implementadas en código (código de salida, binario presente/ejecutable, versión registrada en log, `mise which node` resuelto) | `M01-M04, BOOT01, M06` (todas ejecutan e implícitamente verifican la instalación de Mise) | OK | Ninguna implementación distinta introducida; la ADR documenta el mecanismo ya existente, sin cambiarlo |

### Cierre del Hito 7 — M06, M07 e instalador legado (2026-07-17)

| Criterio | Evidencia | Prueba | Resultado | Observaciones |
|---|---|---|---|---|
| M06 — Mise ya instalado antes de migrar: no se reinstala, versión sin cambios | Revisión de código: `[[ ! -x "${UCI_MISE_BIN}" ]]` en `migration_apply()` ya evitaba reinstalar Mise; era una brecha de prueba, no de código | `tests/docker/test_nvm_to_mise_mise_preexisting.sh` sobre `Dockerfile.nvm-mise-preexisting` (Mise instalado en tiempo de build) — compara `mise --version` antes/después de migrar y tras una segunda corrida | OK (24.04 y 26.04) | Nuevo Dockerfile + script de prueba; sin cambios de código en la migración |
| M06 — Node de NVM se instala vía Mise; alias global resuelto; `.nvm` movido; shell limpiado | Igual que M02-M04 (Hito 7 original), aplicado sobre el estado "Mise ya presente" | Mismo script que la fila anterior | OK | — |
| M06 — segunda corrida no repite la migración ni crea otro backup | `backup_init_session` + marca `.done` (Hito 6) | Mismo script, paso 6 | OK | — |
| M07 — inyección de fallos sin depender de cortar Internet | Nueva variable `UCI_TEST_FAIL_MIGRATION_AT` en `001_nvm_to_mise.sh` (vacía por defecto, sin efecto en ejecución normal; `log_warn` explícito si se define) | `tests/docker/test_nvm_to_mise_fault_injection.sh` | OK (24.04 y 26.04) | 5 checkpoints: `after_shell_backup`, `before_mise_install`, `after_mise_before_node`, `after_node_before_move`, `before_done_marker` |
| M07 — cada checkpoint: código de salida ≠ 0, no se crea `.done`, `.nvm` no se pierde | `migration_test_fail_at()` aborta `apply`/`validate` en el punto exacto; `backup_move_dir` solo mueve `.nvm` en el paso 7, después de los primeros 4 checkpoints | `test_nvm_to_mise_fault_injection.sh`, todos los checkpoints | OK | En `before_done_marker`, `.nvm` ya fue movido con éxito por `apply()` antes de que `validate()` falle — no está perdido, queda recuperable dentro de la sesión de backup |
| M07 — sesión de backup del intento fallido se conserva; archivos de shell recuperables | `backup_init_session` nunca sobreescribe; `backup_copy_file` respalda `.bashrc`/`.zshrc`/`.profile` antes de cualquier limpieza (paso 1, anterior a todos los checkpoints) | `test_nvm_to_mise_fault_injection.sh` | OK | — |
| M07 — una corrida posterior sin fallo inyectado completa la migración y marca `.done` | Ver "Hallazgo y corrección" más abajo: sentinel propio `.001_nvm_to_mise.apply-completado` + `migration_check()` extendido | `test_nvm_to_mise_fault_injection.sh` (paso 2 de cada checkpoint) | OK | Sin este cambio, el checkpoint `before_done_marker` dejaba la migración huérfana para siempre (ver detalle abajo) |
| M07 — no se duplica el bloque gestionado de Mise en el reintento | `mise_shell_block_upsert` ya era un upsert (reemplaza, nunca duplica) | `test_nvm_to_mise_fault_injection.sh` (`grep -c` del marcador == 1 tras el reintento) | OK | — |
| M07 — no se crean backups inconsistentes silenciosamente | Cada intento de `apply` (fallido o exitoso) crea su propia sesión con timestamp, nunca sobreescribe ni borra otra; todo queda logueado | `test_nvm_to_mise_fault_injection.sh` (verifica ≥2 sesiones tras cada checkpoint, ninguna perdida) | OK | Ver "Modelo de recuperación" abajo |
| Instalador legado (`install_nodejs.sh`): `install`/`uninstall`/`reinstall` se niegan a operar siempre | `refuse_legacy_action()` reemplaza `require_legacy_confirmation()`; ya no existe ninguna variable de entorno que reactive las acciones | `tests/test_install_nodejs_legacy.sh` (27 casos, corre en Nivel 1 sin Docker) | OK | Se eliminó `UCI_ALLOW_LEGACY_NVM` por completo, no solo se mantuvo detrás de una confirmación |
| Instalador legado: ningún camino ejecuta `rm -rf ~/.nvm` ni edita `.bashrc`/`.zshrc`/`.profile` | El código destructivo (`rm -rf "$HOME/.nvm"`, `sed -i` sobre los 3 archivos) se eliminó físicamente del script, no solo se deshabilitó | `tests/test_install_nodejs_legacy.sh` (hash del HOME de prueba antes/después idéntico en los 6 escenarios: 3 acciones × con/sin `UCI_ALLOW_LEGACY_NVM=1`) | OK | — |
| Instalador legado: `status` se mantiene, mensaje claro apuntando a `migrate`/flujo interactivo | `refuse_legacy_action()` imprime el mensaje; `check_status()` sin cambios | `tests/test_install_nodejs_legacy.sh` | OK | — |

**Hallazgo y corrección durante el diseño de M07 (checkpoint `before_done_marker`):** si `apply()` mueve `.nvm` con éxito pero `validate()` falla justo después, `migration_check()` original (`[[ -d "${UCI_NVM_DIR}" ]]`) deja de ser cierto en el reintento — la migración quedaría huérfana para siempre (nunca marcada `.done`, pero tampoco vuelta a intentar), aunque el sistema ya esté correctamente migrado. Se agregó un sentinel propio de esta migración (`${home}/.local/state/ubuntu-workstation/migrations/.001_nvm_to_mise.apply-completado`, distinto de la marca oficial `.done`), escrito al final de `migration_apply()` justo después de mover `.nvm`. `migration_check()` ahora también devuelve verdadero si ese sentinel existe y la marca `.done` todavía no — permitiendo que `apply`/`validate` se reintenten (son idempotentes). Se verificó que esto no afecta M01/BOOT01: el sentinel solo se crea si esta migración específica llegó a mover `.nvm` de verdad.

**Modelo de recuperación:** reanudación idempotente, no rollback automático. Cada intento de `apply` fallido deja su propia sesión de backup con lo que llegó a respaldar antes de fallar — nunca se sobreescribe ni se borra. Quien prefiera revertir en vez de reintentar sigue teniendo `rollback-notes` disponible. Ver `docs/TESTING.md` para el detalle completo.

**Determinación:** M06 y M07 pasan en ambas versiones de Ubuntu (24.04 y 26.04); la recuperación tras fallo parcial queda demostrada en los 5 checkpoints acordados, incluida la reanudación tras el hallazgo del sentinel; el instalador legado deja de ser destructivo bajo cualquier variable de entorno; toda la batería anterior (Hitos 2-6, más Nivel 1 y Nivel 2 de Hito 7 ya existentes) sigue pasando sin regresiones. Las tres brechas que mantenían este hito en `Review` quedan cerradas. → **Done**.

---

## Resumen de determinación

| Hito | Determinación | Razón |
|---|---|---|
| 2 — Bootstrap | **Done** | Todos los criterios demostrados por prueba/revisión; corrección de la auditoría verificada en Docker |
| 3 — Idempotencia y estado enriquecido | **Done** | Todos los criterios demostrados, incluida la corrección de `UNKNOWN` vs `NOT_INSTALLED` |
| 4 — Doctor | **Done** | Todos los criterios demostrados; nota de diseño sobre alcance del contrato de estado no es una brecha |
| 5 — Gestor de Backups | **Done** | Todos los criterios demostrados, incluida la corrección crítica de `backup_move_dir` |
| 6 — Framework de migraciones | **Done** | Todos los criterios demostrados por prueba automatizada |
| 7 — Migración NVM → Mise | **Done** | M06 y M07 implementados y probados en ambas versiones de Ubuntu; instalador legado desactivado de forma permanente y probado; sin brechas pendientes |

Ninguna limitación de Ubuntu 26.04 fue encontrada, ni en el cierre inicial (Hitos 2-6, 5 combinaciones Docker) ni en el cierre del Hito 7 (8 combinaciones Docker): todas corrieron exitosamente en ambas versiones soportadas (24.04 y 26.04), sin necesidad de invocar ninguna salvedad de imagen no disponible.
