# TECHNICAL_REVIEW.md

## Revisión técnica integral del proyecto (2026-07-18)

**Alcance:** revisión de código y documentación de todo el repositorio `ubuntu-commons-installer`, hecha como una incorporación de Staff Engineer al equipo. Cubre `setup.sh`/`setup.js`, `scripts/lib/`, `scripts/bootstrap/`, `scripts/migrations/`, `scripts/diagnostics/`, los ~30 instaladores en `scripts/{development,editors,system,productivity,maintenance}/`, toda la infraestructura de pruebas (`tests/`, `tests/docker/`, `.github/workflows/ci.yml`), y la documentación de gobernanza (`AGENT.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/TOOLS.md`, `docs/adr/*`).

**No incluye implementación.** Este documento es un inventario priorizado de hallazgos con propuestas de solución. No se modificó ningún script ni ADR; las únicas ediciones permitidas por el encargo eran correcciones menores de documentación claramente incorrecta, y no se encontró ninguna lo bastante trivial y no ambigua como para aplicarla sin revisión — todo lo encontrado se documenta abajo para que el dueño del proyecto decida.

**No se avanza al Hito 11.** Varios hallazgos son precondición recomendada para ese hito (ver Crítico #1), pero abordarlos es una decisión del dueño del proyecto, no una consecuencia automática de este documento.

**Actualización 2026-07-18 — Crítico y Alto corregidos.** Tras revisar este documento, se pidió corregir todos los hallazgos Crítico y Alto (rama `correcciones-criticas-altas-revision-tecnica`). Cada hallazgo de esas dos severidades queda marcado `✅ Corregido` abajo, con una nota de qué cambió. Los hallazgos Medio y Bajo siguen sin tocar — quedan como backlog documentado, tal como se entregaron originalmente. El Hito 11 sigue sin iniciarse.

**Actualización 2026-07-19 — Medio y Bajo corregidos (rama `correcciones-medias-bajas-revision-tecnica`, creada a partir de la anterior).** Cada hallazgo Medio y Bajo queda marcado `✅ Corregido` o `⏭️ Diferido intencionalmente` abajo. Se difirió deliberadamente M6 (extracción de dispatcher compartido entre los ~30 instaladores) por ser, en esencia, trabajo de alcance del Hito 11 — hacerlo ahora habría violado "no avanzar al Hito 11". También quedaron sin acción M5 (clase de riesgo, se corrige la próxima vez que se toque ese archivo puntual) y B2/B5/B8/B9, todos ya documentados en su momento como deuda aceptada o no accionable sin información adicional. El Hito 11 sigue sin iniciarse.

**Actualización 2026-07-19 (más tarde el mismo día) — Hito 9 cerrado administrativamente, Hito 11 Fase 1 iniciada.** Se confirmó que las únicas validaciones pendientes del Hito 9 eran las dos ya conocidas (Snap en Ubuntu 26.04 Desktop, kernel HWE en VM); el hito pasa a `Done` con esas dos validaciones documentadas explícitamente como pendientes antes de una primera versión estable (ver `docs/ROADMAP.md`). Esto habilitó el Hito 11, que pasa de `Blocked` a `In Progress`. Se ejecutó únicamente su Fase 1 (infraestructura compartida): M6 pasa de `Diferido intencionalmente` a `En progreso` — ver el hallazgo M6 actualizado abajo. No se migró ningún instalador adicional más allá del piloto (`install_cmatrix.sh`); no se avanzó al Hito 12.

**Actualización 2026-07-21 (Hito 22, ver `docs/ROADMAP.md`) — auditoría de cierre de todo el backlog Medio/Bajo, camino a la primera versión estable.** Con el Hito 11 ya completo y cerrado administrativamente (Hito 20), se revisó cada hallazgo `Medio`/`Bajo` que seguía sin marcarse `✅ Corregido`, para confirmar cuáles se resolvieron de hecho como efecto colateral de hitos posteriores sin que nadie lo haya marcado acá:

* **M6 pasa de `En progreso` a `✅ Corregido`**: confirmado por grep directo que 53 de los 55 scripts `install_*.sh` del repositorio sourcean `scripts/lib/installer_cli.sh`; los 2 restantes (`install_vim.sh`, `install_nodejs.sh`) son exclusiones intencionales ya documentadas. Los 3 agrupadores delgados que M6 citaba como duplicadores de `check_package_installed()`/`check_all_packages_installed()` ya no existen (eliminados en el Hito 11 vía ADR 0035).
* **M5, B2, B5, B8, B9 siguen abiertos de verdad, se confirma su estado sin cambios**: revisados uno por uno contra el código/CI actual — `test_docker_apt_repo.sh` sigue con el mismo patrón de grep frágil citado por M5 (nadie tocó ese test); `scripts/migrations/001_nvm_to_mise.sh` sigue en 629 líneas sin dividir (B2); la advertencia de Node.js 20 deprecado sigue apareciendo en las corridas de CI, ahora también visible en la PR #35 del Hito 17 (B5); `install_ulauncher.sh` sigue ejecutando `add-apt-repository -y universe` sin guardar en cada `install` (B8); `.github/workflows/ci.yml` sigue sin `--pull` explícito en los `docker build` (B9). Los cuatro quedan como estaban: backlog documentado, deliberadamente sin fecha comprometida, no bloqueantes para la primera versión estable.

**Convención de prioridad:**

- **Crítico** — bloquea o desvía trabajo futuro ya planificado; corregirlo debería preceder a ese trabajo.
- **Alto** — bug real activo (rompe idempotencia, contradice una decisión ya aceptada) o deuda que ya causó incidentes de la misma clase en este proyecto.
- **Medio** — deuda técnica o de documentación con impacto acotado; no urge, pero compone si se ignora.
- **Bajo** — cosmético, teórico, o de alcance futuro.

---

## Resumen ejecutivo

El proyecto está en buen estado general: la disciplina de ADRs, la matriz de compatibilidad con evidencia por versión (`docs/UBUNTU_COMPATIBILITY.md`) y la cobertura de CI son notablemente maduras para su tamaño. Los hallazgos de esta revisión no apuntan a un proyecto descuidado, sino a la deuda esperable de una base que creció rápido en varios hitos consecutivos: patrones corregidos en un instalador que no se propagaron a sus gemelos, documentación que describe una versión anterior del CI, y una decisión de interfaz (ADR 0004) que el código ya superó sin que nadie la haya reemplazado formalmente.

El hallazgo más importante (Crítico #1) es que el Hito 11, tal como está descrito hoy en `docs/ROADMAP.md`, apunta a una interfaz (`status/install/update/repair`) que ningún instalador implementa realmente — los ~30 instaladores ya convergieron de forma consistente a `status/install/uninstall/reinstall`. Empezar el Hito 11 sin resolver esto primero arriesga reescribir 30 archivos hacia una interfaz que el propio código ya abandonó.

---

## Hallazgos

### Crítico

#### C1. El contrato de interfaz real de los instaladores contradice la decisión aceptada (ADR 0004) y la especificación vigente del Hito 11  ✅ **Corregido (2026-07-18)**

> ADR 0029 creada; AGENT.md §9, docs/ARCHITECTURE.md §21/§25 y el objetivo del Hito 11 en docs/ROADMAP.md actualizados para citar el contrato completo de 6 verbos e install_vim.sh como referencia.

**Dónde:** `docs/adr/0004-idempotencia-instalado-igual-skip.md` (Aceptada), `AGENT.md` §9, `docs/ARCHITECTURE.md` §21 (contrato aspiracional), `docs/ROADMAP.md` (Hito 11, "Cada instalador debe exponer: status / install / update / repair"), vs. los ~30 archivos reales en `scripts/{development,editors,system,productivity,maintenance}/`.

**Problema:** ADR 0004 decidió `NOT_INSTALLED→install`, `INSTALLED→skip`, `OUTDATED→update`, `BROKEN→repair`, con `reinstall` como acción avanzada no-default — y esa misma interfaz (`status/install/update/repair`) es la que hoy describen tanto `AGENT.md` §9 como el objetivo del Hito 11. Pero el código real, sin excepción, implementa `status/install/uninstall/reinstall`; ninguno de los 30 instaladores tiene `update` ni `repair`. `docs/TOOLS.md` confirma que `install_vim.sh` es el único "instalador de referencia" y ni siquiera él implementa `update`/`repair`. Nadie reemplazó ADR 0004 con una ADR nueva que documente este cambio de rumbo — se violó la propia convención del proyecto ("nunca editar una ADR aceptada, se reemplaza con una nueva").

**Impacto:** el Hito 11 (`Blocked`, próximo hito grande, ya depende de Hito 9 y Hito 10) partiría hoy de una especificación que no describe el código real. El riesgo concreto es planificar — o peor, empezar a implementar — una migración de 30 instaladores hacia `update`/`repair` cuando el patrón ya establecido y probado en CI es `uninstall`/`reinstall`.

**Propuesta:** antes de iniciar el Hito 11, crear una ADR nueva que reemplace explícitamente a la 0004, registrando cuál es el contrato real vigente (`status/install/uninstall/reinstall`) y decidiendo conscientemente si `update`/`repair` se abandona como interfaz o si se retoma con un significado distinto (por ejemplo, `update` como alias de `reinstall` para paquetes versionables). Actualizar `AGENT.md` §9, `docs/ARCHITECTURE.md` §21 y el objetivo del Hito 11 para que citen la interfaz real.

**Roadmap:** precondición recomendada para el Hito 11 ya planificado. No requiere un hito nuevo — es la primera tarea del propio Hito 11, antes de tocar código.

---

### Alto

#### A1. Bug de idempotencia recurrente (misma clase ya corregida en Cursor/VS Code/Chrome) en 4 instaladores más, sin corregir  ✅ **Corregido (2026-07-18)**

> check_package_installed() en los 3 instaladores y check_status() en install_mongodb_compass.sh migrados a 'dpkg -l | grep ^ii'; uninstall_tool() migrado a 'apt purge' en los 4.

**Dónde:** `scripts/system/install_development_tools.sh`, `scripts/system/install_multimedia.sh`, `scripts/system/install_system_utils.sh` (los tres comparten una función `check_package_installed()` basada en `dpkg -s "$package"`) y `scripts/development/install_mongodb_compass.sh:18` (`dpkg -l | grep -q "mongodb-compass"`, sin anclar a `^ii`).

**Problema:** `dpkg -s` y un `grep` sin anclar devuelven éxito para un paquete que quedó en estado remanente "config-files" tras `apt remove` sin purgar — exactamente el bug de falso-positivo que motivó, en este mismo proyecto, el cambio a `dpkg -l | grep '^ii'` en Cursor, VS Code y Chrome durante el cierre del Hito 9. Los tres primeros scripts además usan `apt remove` (no `purge`) en `uninstall_tool()`, así que el estado remanente ocurre siempre que alguien desinstala.

**Impacto:** `./setup.sh status` reporta `INSTALLED` para estas 4 herramientas inmediatamente después de desinstalarlas, rompiendo la idempotencia que AGENT.md exige explícitamente (sección "Idempotencia").

**Propuesta:** aplicar el patrón ya establecido en el resto del proyecto: `dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'` y `apt purge` en `uninstall_tool()`. Es mecánico, de bajo riesgo, y buen candidato para extraer una función común (`apt_package_installed()`) a `scripts/lib/`, dado que se repite igual en 3+ archivos.

**Roadmap:** deuda directa del cierre del Hito 9 (mismo bug, mismo hito, instaladores que quedaron fuera del alcance acordado). No requiere hito nuevo — es trabajo pendiente dentro del Hito 9/mantenimiento continuo.

#### A2. El fix de keyring vacío de `gpg --dearmor` no se portó de VS Code de vuelta a Cursor (el script que originó el hallazgo)  ✅ **Corregido (2026-07-18)**

> install_cursor.sh ahora usa keyring temporal + verificación [[ -s ]] antes de instalar, igual que install_vscode.sh.

**Dónde:** `scripts/editors/install_cursor.sh` (paso de instalación de la clave GPG) vs. `scripts/editors/install_vscode.sh:47-59` (ya corregido este mismo hito).

**Problema:** Cursor fue el script donde se descubrió, vía CI, que `curl | gpg --dearmor | tee` sin `set -o pipefail` puede dejar un keyring vacío en silencio si `gnupg` falta, produciendo un error `NO_PUBKEY` recién en `apt update`. El fix completo (asegurar `gnupg` on-demand + keyring temporal + verificación `[[ -s "$keyring" ]]` antes de instalarlo) se aplicó a VS Code como "mismo patrón que Cursor", pero Cursor mismo se quedó con la versión anterior, sin la verificación de tamaño.

**Impacto:** el bug original que motivó todo el patrón sigue latente en el script donde se descubrió.

**Propuesta:** portar exactamente el bloque de `install_vscode.sh:47-59` a `install_cursor.sh`.

**Roadmap:** deuda directa del cierre del Hito 9. No requiere hito nuevo.

#### A3. Detección de Mise inconsistente entre `scripts/lib/runtime.sh`, `scripts/diagnostics/doctor.sh` y `setup.sh`  ✅ **Corregido (2026-07-18)**

> runtime.sh agrega runtime_resolve_mise_bin() (ruta canónica o PATH); doctor.sh y kubectl/yarn ya lo usan en vez de mecanismos distintos.

**Dónde:** `scripts/lib/runtime.sh:24` (`runtime_mise_bin`, solo mira `${home_dir}/.local/bin/mise`) vs. `scripts/diagnostics/doctor.sh:222` (`doctor_check_command "Mise" mise --version`, solo `command -v mise` vía PATH) vs. `setup.sh:241` (`ensure_node_via_mise`, comprueba ambas rutas).

**Problema:** son tres mecanismos distintos para la misma pregunta ("¿está Mise instalado?"). Si Mise se instaló por un medio distinto al oficial de este proyecto (paquete del sistema, symlink en `/usr/local/bin`, etc.), `runtime_status_all` puede reportar "no instalado" mientras `doctor` sí lo detecta, o viceversa si solo vive en `~/.local/bin/mise` sin estar en PATH.

**Impacto:** diagnóstico (`setup.sh doctor`) y gestión de runtimes (`setup.sh runtime status`) pueden contradecirse sobre el mismo sistema real.

**Propuesta:** unificar en una sola función en `runtime.sh` (p. ej. `runtime_resolve_mise_bin`, que compruebe ambas rutas) y que `doctor.sh` la reutilice en vez de `command -v mise` directo.

**Roadmap:** deuda del Hito 8 (Gestor de runtimes, ya `Done`). No requiere hito nuevo — corrección puntual de una función ya existente.

#### A4. ADR 0008 (modo estricto de Bash) ya exige subir a `set -Eeuo pipefail` cada script que se toca, y ninguno de los ~13 scripts modificados en el cierre del Hito 9 lo cumplió  ✅ **Corregido (2026-07-18)**

> Los 18 scripts tocados en el cierre del Hito 9 (más los de A1/A2) suben a '#!/usr/bin/env bash' + 'set -Eeuo pipefail', con 'case "${1:-}"' en el dispatcher. install_kernel.sh además corrige el 'local var=$(cmd)' que enmascaraba errores bajo set -e.

**Dónde:** `docs/adr/0008-bash-estricto-en-scripts-nuevos.md` ("Cada vez que se toca un script legacy, corresponde subirlo a este estándar como parte del cambio") vs. `scripts/editors/install_vscode.sh`, `scripts/editors/install_cursor.sh`, `scripts/productivity/install_chrome.sh`, `scripts/system/install_kernel.sh`, y los 8 instaladores Snap — todos reescritos o modificados en este mismo cierre, todos siguen con `#!/bin/bash` sin modo estricto. De los ~30 instaladores del repo, solo `install_vim.sh` cumple la ADR 0008.

**Problema:** no es que la política no exista — existe, está aceptada, y describe exactamente esta situación ("scripts que usan `#!/bin/bash` sin modo estricto de forma consistente, lo que oculta errores silenciosos"). El propio trabajo de este cierre de Hito 9, que corrigió activamente varios de estos scripts, no aplicó la ADR que ya obligaba a hacerlo como parte del cambio.

**Impacto:** la ausencia de modo estricto es la causa raíz común detrás de casi todos los bugs reales que este proyecto encontró vía CI (keyrings vacíos que "pasan" silenciosamente, paquetes no instalados que igual continúan la ejecución). Cada script tocado sin subir el estándar es una oportunidad perdida de cerrar esa clase de riesgo con costo marginal casi nulo.

**Propuesta:** la próxima vez que se toque cualquiera de estos scripts (incluidos los recién modificados), agregar `set -Eeuo pipefail` y el shebang `#!/usr/bin/env bash` como parte del mismo cambio, no como tarea aparte. No se propone aplicarlo ahora en volumen (excede el alcance de "no implementar" de este encargo), pero sí registrar que la ADR 0008 tiene una brecha de cumplimiento concreta y reciente, no solo teórica.

**Roadmap:** ya cubierto por ADR 0008 y por el alcance del Hito 11 (modernización de instaladores). No requiere hito nuevo — es checklist de PR, no trabajo adicional.

#### A5. CI sin cache de capas Docker entre jobs — tiempo/costo desperdiciado en cada corrida  ✅ **Corregido (2026-07-18)**

> .github/workflows/ci.yml migrado a docker/build-push-action con cache-from/cache-to: type=gha por variante de imagen.

**Dónde:** `.github/workflows/ci.yml:139-150` (`docker build` plano, 18 combinaciones job×Ubuntu, cada una reconstruye la imagen base desde cero).

**Problema:** el propio workflow ya reconoce el tradeoff en un comentario (línea 60: "cada grupo sigue construyendo su propia copia de la imagen... a costa de un poco de cómputo duplicado"), pero nunca se intentó resolver con cache nativo de GitHub Actions (`docker/build-push-action` con `cache-from/cache-to: type=gha`), que no requeriría rediseñar la matriz de jobs.

**Impacto:** margen real de reducción sobre los ~10-11 minutos actuales de CI; cada push/PR paga ese costo íntegro.

**Propuesta:** migrar el paso "Construir imagen base" a `docker/build-push-action@v5` con `cache-from: type=gha` / `cache-to: type=gha,mode=max`, manteniendo el resto de la matriz igual.

**Roadmap:** mejora incremental sobre el propio entregable del Hito 10 (ya `Done`). No requiere hito nuevo.

#### A6. `docs/TESTING.md` describe una estructura de CI anterior a la reestructuración de este mismo cierre de Hito 9  ✅ **Corregido (2026-07-18)**

> docs/TESTING.md actualizado: 18 combinaciones reales, lista completa de Nivel 1, advertencia obsoleta sobre ubuntu:26.04 eliminada.

**Dónde:** `docs/TESTING.md`, sección "CI (GitHub Actions)".

**Problema:** el texto actual describe "un job `docker-matrix` (Nivel 2, 8 combinaciones en paralelo — 4 variantes de imagen × Ubuntu 24.04/26.04)", que es la estructura previa a la reestructuración de este cierre (ahora son 9 `job`-types × 2 Ubuntu = 18 combinaciones, incluido el nuevo `vendor-repos`). Además, la sección "Nivel 1" no lista los 6 archivos de test agregados en el cierre de Hito 9 (`test_system_utils_contract.sh`, `test_system_update_contract.sh`, `test_mongodb_compass_download.sh`, `test_kernel_hwe_fallback.sh`, `test_chrome_arch_check.sh`, `test_snap_installers_contract.sh`), y todavía incluye una advertencia sobre que la etiqueta `ubuntu:26.04` "podría no existir en Docker Hub", ya contradicha por la evidencia real obtenida este cierre (Docker y VS Code confirmados funcionando en Ubuntu 26.04 real, codename `resolute`).

**Impacto:** es la puerta de entrada documentada de "cómo probar" — un colaborador nuevo que la siga al pie de la letra se forma un modelo mental incorrecto del CI actual y se pierde 6 de 13 suites de Nivel 1 si intenta correrlas manualmente en vez de usar `run-all-tests.sh` como fuente de verdad.

**Propuesta:** actualizar el párrafo de CI para reflejar los 9 job-types actuales; actualizar o eliminar la lista manual de Nivel 1 (remitir directamente a `tests/docker/run-all-tests.sh` en vez de duplicar la lista en dos lugares); eliminar la advertencia obsoleta sobre `ubuntu:26.04`.

**Roadmap:** deuda de documentación directa del cierre del Hito 9. No requiere hito nuevo.

#### A7. Documentación exigida por `AGENT.md` §5 que nunca se creó, pese a que el trabajo que la dispara ya está `Done`  ✅ **Corregido (2026-07-18)**

> docs/CONTRIBUTING.md, docs/MIGRATIONS.md y docs/RELEASES.md creados con contenido retroactivo mínimo.

**Dónde:** `docs/CONTRIBUTING.md`, `docs/MIGRATIONS.md`, `docs/RELEASES.md` — ninguno existe en `docs/`.

**Problema:** `AGENT.md` §5 dice explícitamente que `MIGRATIONS.md` "se actualiza cada vez que una migración versionada... se dé por completada" — la migración NVM→Mise (Hito 7) ya está `Done` y no tiene ningún registro. Lo mismo con `RELEASES.md` ("se actualiza en cada versión o hito entregado"), habiendo ya 9 hitos `Done`/`Review`. `CONTRIBUTING.md` tampoco existe pese a estar listado como documento de referencia central.

**Impacto:** un colaborador nuevo (humano o agente de IA) que siga `AGENT.md` al pie de la letra buscará estos archivos y no los encontrará, o asumirá incorrectamente que no hay migraciones/releases documentadas.

**Propuesta:** crear los tres archivos con contenido mínimo retroactivo (aunque sea un registro inicial), o si se decide que ya no son necesarios, actualizar `AGENT.md` §5 para dejar de exigirlos explícitamente.

**Roadmap:** deuda de documentación del roadmap actual. No requiere hito nuevo.

#### A8. `docs/ARCHITECTURE.md` mezcla arquitectura real y aspiracional sin separarlas de forma inequívoca  ✅ **Corregido (2026-07-18)**

> docs/ARCHITECTURE.md agrega nota de lectura (estado actual vs. futuro) y corrige las secciones 21/25 para el contrato completo de 6 verbos.

**Dónde:** `docs/ARCHITECTURE.md` (marcado "Versión 2.0, Borrador" en el encabezado, pero citado como fuente de verdad desde varias ADRs).

**Problema:** la sección de módulos describe una estructura futura de `scripts/` (`runtime/`, `configuration/`, `validation/` como subdirectorios de primer nivel) distinta de la real (`development/`, `editors/`, `system/`, `productivity/`, `maintenance/`, más `bootstrap/`, `migrations/`, `diagnostics/`, `lib/` de `AGENT.md` §5). La sección de arquitectura de plugins futura muestra un contrato `install.sh/update.sh/status.sh/repair.sh` sin `uninstall.sh` — inconsistente tanto con el hallazgo C1 como con el propio ADR 0009 que referencia.

**Impacto:** confunde a quien use el documento como mapa real del sistema; el disclaimer "Borrador" es insuficiente dado el uso que ya se le da como referencia citada.

**Propuesta:** separar explícitamente, en el propio documento, "estado actual" de "visión a futuro" (dos secciones tituladas sin ambigüedad), y alinear los ejemplos de contrato de instalador una vez resuelto C1.

**Roadmap:** deuda de documentación. No requiere hito nuevo; conviene resolverlo junto con C1 antes del Hito 11.

---

### Medio

#### M1. Duplicación de logging: `setup.sh` mantiene su propio `print_*` en paralelo a `scripts/lib/logging.sh`  ✅ **Corregido (2026-07-19)**

> setup.sh: print_header (código muerto) eliminado; print_status/warning/error/info reemplazados por log_success/warn/error/info de scripts/lib/logging.sh.

**Dónde:** `setup.sh:62-80` (`print_header`/`print_status`/`print_warning`/`print_error`/`print_info`) vs. `scripts/lib/logging.sh:29-43` (`log_info`/`log_warn`/`log_error`/`log_success`) — `setup.sh` ya sourcea `logging.sh` en la línea 33, pero conserva su propio set de funciones de presentación.

**Impacto:** cualquier cambio de formato de log debe hacerse en dos lugares; ya está documentado como deuda intencional heredada del flujo interactivo histórico, pero sigue siendo duplicación real.

**Propuesta:** sustituir los `print_*` por los `log_*` de la librería (son funciones puramente de presentación, sin lógica de negocio, bajo riesgo).

**Roadmap:** limpieza de bajo riesgo, candidata para el Hito 11 o para hacerse de forma aislada antes.

#### M2. Comentario desactualizado en `scripts/bootstrap/preflight.sh`  ✅ **Corregido (2026-07-19)**

> Comentario corregido: referencia a check_and_install_nodejs cambiada a ensure_node_via_mise.

**Dónde:** `scripts/bootstrap/preflight.sh:100-103` (comentario de `preflight_interactive`) referencia una función `check_and_install_nodejs` que ya no existe — fue renombrada a `ensure_node_via_mise` en la migración a Mise (ADR 0002).

**Propuesta:** corrección de una línea de comentario. (Se consideró aplicar esta corrección directamente por ser "documentación claramente incorrecta" de bajo riesgo, pero se deja registrada aquí en vez de editarla para no mezclar cambios de código con este documento de revisión; es trivial de aplicar en un commit aparte.)

**Roadmap:** trivial, sin hito asociado.

#### M3. Sin política de retención de sesiones de backup  ✅ **Corregido (2026-07-19)**

> Nota agregada en docs/ARCHITECTURE.md §8: retención de backups es responsabilidad manual hasta que exista un comando de limpieza.

**Dónde:** `scripts/lib/backup.sh` — cada corrida de `setup.sh backup` (y cada migración que use `backup_copy_dir`) crea una sesión nueva en `~/.local/state/ubuntu-workstation/backups/<timestamp>/` que nunca se limpia.

**Impacto:** correcto según AGENT.md ("nunca eliminar backups silenciosamente"), pero sin ningún mecanismo de limpieza documentado, el uso de disco no está acotado a largo plazo, especialmente si una migración con reintentos copia directorios grandes (`.nvm` completo, por ejemplo) más de una vez.

**Propuesta:** no es urgente, pero documentar en `docs/ARCHITECTURE.md`/`docs/ROADMAP.md` que la limpieza de backups antiguos es responsabilidad manual del usuario por ahora, o planificar a futuro un comando `setup.sh backup --list`/`--prune`.

**Roadmap:** posible tarea nueva pequeña dentro de un futuro hito de mantenimiento/backups; no amerita un hito propio.

#### M4. Sin harness de aserciones compartido entre tests — 12 archivos duplican `pass()`/`fail()` idénticos  ✅ **Corregido (2026-07-19)**

> Extraído tests/lib/assertions.sh (pass/fail/print_test_summary/exit_with_test_summary); los 12 archivos de test lo sourcean en vez de duplicar el bloque.

**Dónde:** `tests/test_router.sh`, `test_doctor.sh`, `test_backup.sh`, `test_backup_move_dir.sh`, `test_migrations.sh`, `test_install_nodejs_legacy.sh`, `test_system_utils_contract.sh`, `test_system_update_contract.sh`, `test_mongodb_compass_download.sh`, `test_kernel_hwe_fallback.sh`, `test_chrome_arch_check.sh`, `test_snap_installers_contract.sh` — los 12 copian el mismo bloque de ~15 líneas (`UCI_TESTS_RUN`, `UCI_TESTS_FAILED`, `pass()`, `fail()`). Los tests de `tests/docker/` usan además un patrón distinto (`check()` con `eval`) — dos convenciones de aserción coexistiendo sin centralizar ninguna.

**Impacto:** cualquier mejora al harness (resumen JSON, `--verbose`, etc.) requiere editar 12+ archivos a mano; el historial reciente del proyecto ya mostró que un bug en el patrón de captura de exit code tuvo que corregirse repetidamente en archivos distintos por esta misma razón.

**Propuesta:** extraer un `tests/lib/assertions.sh` (fuente única de `pass`/`fail`/contador/resumen) y sourcearlo desde cada test — no rompe la convención de "cada test es standalone", solo elimina la duplicación literal.

**Roadmap:** tarea chica dentro del Hito 10 (gate de calidad, ya `Done`, mejora incremental). No requiere hito nuevo.

#### M5. Clase de riesgo recurrente: greps de regresión frágiles ante los propios comentarios del código  ⏭️ **Diferido intencionalmente**

> No se tocó ningún archivo nuevo que exhiba este patrón; se deja para corregir la próxima vez que se edite ese test puntual, tal como recomendaba el hallazgo original.

**Dónde:** patrón usado en varios tests (ya corregido dos veces en este proyecto: `test_install_nodejs_legacy.sh`, `test_kernel_hwe_fallback.sh`). Revisado puntualmente `tests/docker/test_docker_apt_repo.sh` (`! grep -qE "focal|jammy|bionic|xenial" ...`): hoy no produce falso positivo, pero el patrón sigue siendo frágil — cualquier futuro comentario explicativo que mencione esos codenames rompería la prueba en falso.

**Propuesta:** cuando se toque ese test de nuevo, aplicar el mismo patrón ya usado en `test_kernel_hwe_fallback.sh` (excluir comentarios con `grep -vE '^\s*#'` antes de grepear código real).

**Roadmap:** checklist de PR para tests nuevos, no requiere trabajo inmediato.

#### M6. Duplicación de dispatcher y de funciones de verificación multi-paquete entre instaladores  ✅ **Corregido (Hito 11, revisado 2026-07-21 al cerrar el Hito 22)**

> Fase 1: se creó `scripts/lib/installer_cli.sh` (dispatcher compartido de 6 verbos, `installer_run_cli`) y `scripts/lib/apt.sh` (`apt_package_installed`/`apt_all_packages_installed`/`apt_install_packages`/`apt_purge_packages`), y se migró un único instalador piloto (`install_cmatrix.sh`) para validar la infraestructura de punta a punta.
>
> Fase 2: migrados `install_ranger.sh`, `install_terminator.sh` e `install_flameshot.sh` a la misma infraestructura, sin extenderla (validó que alcanza para instaladores apt-simples adicionales sin modificaciones).
>
> **Cierre (2026-07-21):** con el Hito 11 completo y cerrado administrativamente (Hito 20), se confirmó que 53 de los 55 scripts `install_*.sh` del repositorio sourcean `scripts/lib/installer_cli.sh` hoy (verificado por grep directo, sin ambigüedad) — los únicos 2 que no lo hacen son intencionales: `install_vim.sh` (instalador de referencia del contrato, [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md)) e `install_nodejs.sh` (legado congelado desde el Hito 7, sin acciones activas). Los 3 agrupadores delgados que en su momento duplicaban `check_package_installed()`/`check_all_packages_installed()` (`install_development_tools.sh`, `install_multimedia.sh`, `install_system_utils.sh`) ya no existen: se eliminaron en el Hito 11 al separarlos en instaladores individuales ([ADR 0035](adr/0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md)). El hallazgo queda completamente resuelto, no solo "en progreso".

**Dónde:** los ~30 instaladores repiten un dispatcher `main()`/`case` casi idéntico (~15-20 líneas cada uno); `install_development_tools.sh`, `install_multimedia.sh` e `install_system_utils.sh` además duplican literalmente `check_package_installed()`/`check_all_packages_installed()`.

**Impacto:** cualquier cambio al contrato de CLI (agregar un subcomando, cambiar el mensaje de uso) requiere editar 30 archivos a mano.

**Propuesta:** extraer un `scripts/lib/installer_cli.sh` con una función `run_installer_cli "$@"` que cada script invoque al final en vez de repetir el `case`, y una función `apt_all_packages_installed()` reutilizable para los instaladores multi-paquete (ver también A1, que necesita la misma función corregida).

**Roadmap:** este es, en esencia, el trabajo que ya cubre el Hito 11 (modernización de instaladores) — no requiere hito nuevo, refuerza su alcance ya planificado.

#### M7. Inconsistencia del fallback a Snap en instaladores apt-simples  ✅ **Corregido (2026-07-19)**

> Los 4 instaladores (cmatrix, ranger, terminator, flameshot) guardan el fallback a Snap con 'command -v snap' antes de invocarlo; suben a modo estricto de paso.

**Dónde:** `install_cmatrix.sh`, `install_ranger.sh`, `install_terminator.sh`, `install_flameshot.sh` — todos hacen `command -v X || snap list | grep -q "^X "` sin comprobar antes `command -v snap`, ni redirigir `stderr` de `snap list`.

**Impacto:** bajo-medio; si `snapd` no existe (como en la imagen Docker de CI), `snap list` imprime "command not found" en cada `status` — inofensivo funcionalmente (el `||` lo trata como falso) pero ruidoso, y contradice el patrón `UNKNOWN` ya aplicado este hito a los 8 instaladores Snap "reales". El fallback además parece vestigial: estas 4 herramientas nunca se instalan por Snap en su propio `install_tool()`.

**Propuesta:** quitar el fallback a Snap en estos 4 (no está implementado, así que no aporta), o aplicar el mismo guard `command -v snap &> /dev/null &&` antes de invocarlo si se quiere conservar por si el usuario instaló manualmente vía Snap.

**Roadmap:** limpieza menor, candidata al Hito 11.

#### M8. `install_docker.sh` usa `apt-get remove` en vez de `purge`, inconsistente con el resto de instaladores de repo propio ya migrados este hito  ✅ **Corregido (2026-07-19)**

> install_docker.sh migrado a 'apt-get purge' (antes 'remove'); mismo commit que B7.

**Dónde:** `scripts/development/install_docker.sh` (función `uninstall_tool()`).

**Impacto:** no es un bug funcional hoy (`check_status` ya usa `dpkg -l | grep '^ii'`, así que un estado remanente no reportaría `INSTALLED` falsamente), pero deja basura de configuración (`/etc/docker/`, etc.) tras "desinstalar", inconsistente con Cursor/VS Code/Chrome.

**Propuesta:** alinear a `apt-get purge` por consistencia.

**Roadmap:** limpieza menor, sin urgencia.

#### M9. ADR 0009 (postergar arquitectura de plugins) tiene su propio disparador de revisión ya cumplido, sin revisitar  ✅ **Corregido (2026-07-19)**

> Apéndice "Revisión (2026-07-19)" agregado a la ADR 0009 confirmando que el disparador se cumplió y la postergación sigue vigente por prioridad de roadmap.

**Dónde:** `docs/adr/0009-postergar-arquitectura-de-plugins.md` — el disparador declarado ("una vez completados Hito 2, Hito 5, Hito 6 y Hito 8") ya se cumplió; los cuatro están `Done`.

**Impacto:** bajo hoy (el hito que retomaría plugins está lejos y bloqueado), pero es señal de que las ADRs con disparadores condicionales no se monitorean activamente.

**Propuesta:** agregar un apéndice breve a la ADR 0009 confirmando que el disparador se cumplió y que la decisión de postergar sigue vigente por prioridad de roadmap, no por falta de condiciones.

**Roadmap:** mantenimiento de documentación, sin hito asociado.

#### M10. `docs/TOOLS.md` con clasificación `required | optional | retired | candidate` pendiente sin fecha de retoma  ✅ **Corregido (2026-07-19; clasificación completada 2026-07-20)**

> docs/TOOLS.md ahora asocia la clasificación pendiente a los Hitos 11/12, en vez de quedar sin fecha. Retomada y completada el 2026-07-20, tras confirmar caso por caso con el dueño del proyecto las 7 herramientas que faltaban: required (GitKraken, ULauncher, cmatrix, ranger) / optional (Postman, Insomnia, MongoDB Compass).

**Dónde:** `docs/TOOLS.md` — diferido explícitamente por el dueño del proyecto desde 2026-07-15, sin dueño ni fecha en el roadmap.

**Propuesta:** agregarla como tarea explícita con hito asociado (por ejemplo dentro del Hito 11 o 12) en vez de dejarla flotando solo en `docs/TOOLS.md`.

**Roadmap:** decisión pendiente del dueño del proyecto; sugerido asociarla a un hito existente cuando se retome.

#### M11. `docs/ACCEPTANCE_2_7.md` fuera del inventario de documentación declarado en `AGENT.md` §5  ✅ **Corregido (2026-07-19)**

> AGENT.md §5 formaliza la convención 'ACCEPTANCE_<rango>.md' como patrón opcional documentado.

**Dónde:** `docs/ACCEPTANCE_2_7.md` (191 líneas, patrón propio de evidencia por criterio de aceptación) no aparece en la lista de `AGENT.md` §5.

**Impacto:** no es un problema en sí, pero si el patrón "`ACCEPTANCE_N_M.md` por rango de hitos" se repite sin formalizarse, genera dispersión de documentación.

**Propuesta:** decidir si este patrón se vuelve convención formal (agregarlo a `AGENT.md` §5) o si su contenido se fusiona a `docs/TEST_CASES.md`/`ROADMAP.md` una vez cerrado un rango de hitos.

**Roadmap:** decisión de gobernanza documental, sin hito asociado.

---

### Bajo

#### B1. `setup.sh` instala `snapd` como dependencia básica sin revisar a la luz de ADR 0027  ✅ **Corregido (2026-07-19)**

> Comentario agregado en setup.sh documentando la tensión con ADR 0027, sin retirar snapd (8 instaladores todavía dependen de él).

`setup.sh` (`check_basic_dependencies`) incluye `snapd` como dependencia recomendada, pese a que ADR 0027 ya prioriza apt oficial sobre Snap y varios instaladores tratan Snap como mecanismo de último recurso. No es un bug, pero vale una pasada de coherencia cuando se aborde el Hito 11.

#### B2. `scripts/migrations/001_nvm_to_mise.sh` (629 líneas) es el script más largo y complejo del repo  ⏭️ **Diferido intencionalmente**

> Sin acción: ya documentado como deuda aceptada en la revisión original, dividir 001_nvm_to_mise.sh no es una corrección aislada de bajo riesgo.

Mezcla resolución de specs de versión NVM, migración de bloques de shell, inyección de fallos para pruebas, y el ciclo completo describe/check/dry-run/apply/validate/rollback. Ya tiene buena cobertura (incluida fault-injection, M07), así que no es urgente, pero es candidato natural a dividirse en funciones más pequeñas testeables si se vuelve a tocar (viola suavemente "Evitar scripts enormes" de AGENT.md §12).

#### B3. `setup.js` usa `execSync` con interpolación de string en vez de `execFileSync`  ✅ **Corregido (2026-07-19)**

> setup.js migrado de execSync a execFileSync en ambos usos.

El riesgo real es mínimo hoy (`tool.script` viene de un array interno fijo, no de entrada de usuario), pero si a futuro se implementa el "sistema de plugins" (prioridad menor en `docs/ROADMAP.md`) permitiendo registrar herramientas de terceros, este patrón se volvería una inyección de comandos trivial. Migrar a `execFileSync` con array de argumentos si esa funcionalidad avanza.

#### B4. `eval` en el helper `check()` de los tests funcionales Docker  ✅ **Corregido (2026-07-19)**

> Convención documentada en docs/TESTING.md: eval solo es seguro con literales hardcodeados, nunca con datos interpolados.

Usado en `test_docker_apt_repo.sh`, `test_vscode_apt_repo.sh`, `test_cursor_apt_repo.sh`, y otros — construye condiciones vía `eval "${condition}"`. No es explotable hoy (condiciones literales hardcodeadas, no input externo), pero es un code smell: cualquier interpolación futura de una variable no controlada sería una inyección de comando trivial. Sin acción urgente; documentar la convención como "seguro solo con literales hardcodeados".

#### B5. Advertencia de Node.js 20 deprecado en `actions/checkout@v4`  ⏭️ **Diferido intencionalmente**

> Sin acción: no hay una versión más nueva de actions/checkout verificable para adoptar; es un aviso de GitHub sobre el runner, no del proyecto.

Visible en las anotaciones de las últimas corridas de CI (19 jobs). No es un bug del proyecto sino de la versión fijada de la action. Sin apuro, pero GitHub eventualmente forzará la actualización.

#### B6. `CLAUDE.md` en la raíz es un symlink intencional a `AGENT.md`, sin documentarlo como tal  ✅ **Corregido (2026-07-19)**

> AGENT.md §5 documenta que CLAUDE.md es un symlink intencional a AGENT.md.

Funciona correctamente (permite que Claude Code lea las mismas instrucciones que el resto del equipo), pero un colaborador nuevo podría "corregirlo" sin saber que es deliberado. Agregar una línea en `AGENT.md` o el README aclarándolo.

#### B7. `install_docker.sh` sin comillas en `$USER` y con `groups | grep -q docker` como coincidencia de substring débil  ✅ **Corregido (2026-07-19)**

> install_docker.sh: $USER citado, 'groups | grep -qw docker' (match exacto, no substring). Mismo commit que M8.

`sudo usermod -aG docker $USER` y `groups | grep -q docker` funcionan en la práctica (los nombres de usuario Unix no llevan espacios), pero son inconsistentes con el resto del archivo, que sí cita casi todo. El segundo además matchearía en falso un grupo hipotético `docker-foo`. Cosmético, sin impacto real hoy.

#### B8. `install_ulauncher.sh` ejecuta `add-apt-repository -y universe` en cada `install`  ⏭️ **Diferido intencionalmente**

> Sin acción: el costo de la operación redundante es marginal frente al riesgo de tocar install_ulauncher.sh sin necesidad real.

`universe` casi siempre ya está habilitado en Ubuntu estándar — operación idempotente y de bajo costo, no es un bug, solo trabajo redundante menor.

#### B9. `docker build` en CI sin `--pull` explícito  ⏭️ **Diferido intencionalmente**

> Sin acción: ya se documentó como no-issue en runners efímeros de GitHub Actions.

Sin garantía teórica de que la imagen base `ubuntu:${UBUNTU_VERSION}` esté actualizada si el runner tuviera una copia cacheada obsoleta — en la práctica, irrelevante en runners efímeros de GitHub Actions. Documentado como no-issue.

---

## Tabla resumen

| # | Hallazgo | Severidad | Roadmap |
|---|---|---|---|
| C1 | Contrato real de instaladores contradice ADR 0004 / Hito 11 | Crítico | Precondición del Hito 11 (nueva ADR) |
| A1 | `dpkg -s`/grep sin anclar en 4 instaladores más | Alto | Deuda del Hito 9 |
| A2 | Fix de keyring vacío no portado a Cursor | Alto | Deuda del Hito 9 |
| A3 | Detección de Mise inconsistente (runtime/doctor/setup) | Alto | Deuda del Hito 8 |
| A4 | ADR 0008 incumplida en los scripts recién tocados | Alto | Cubierto por ADR 0008 / Hito 11 |
| A5 | CI sin cache de capas Docker | Alto | Mejora incremental del Hito 10 |
| A6 | `docs/TESTING.md` desactualizado | Alto | Deuda de documentación del Hito 9 |
| A7 | `CONTRIBUTING.md`/`MIGRATIONS.md`/`RELEASES.md` inexistentes | Alto | Deuda de documentación del roadmap actual |
| A8 | `ARCHITECTURE.md` mezcla real y aspiracional | Alto | Resolver junto con C1, antes del Hito 11 |
| M1 | `print_*` duplica `logging.sh` en `setup.sh` | Medio | Limpieza, candidata al Hito 11 |
| M2 | Comentario obsoleto en `preflight.sh` | Medio | Trivial |
| M3 | Sin política de retención de backups | Medio | Posible tarea nueva, sin hito propio |
| M4 | Sin harness de aserciones compartido en tests | Medio | Tarea chica del Hito 10 |
| M5 | Greps de regresión frágiles ante comentarios propios | Medio | Checklist de PR |
| M6 | Dispatcher y verificación multi-paquete duplicados | Medio | Alcance ya cubierto por el Hito 11 |
| M7 | Fallback a Snap inconsistente en 4 instaladores apt-simples | Medio | Limpieza, candidata al Hito 11 |
| M8 | `install_docker.sh` usa `remove` en vez de `purge` | Medio | Limpieza menor |
| M9 | ADR 0009 con disparador cumplido sin revisar | Medio | Mantenimiento de documentación |
| M10 | `docs/TOOLS.md` con clasificación pendiente sin fecha | Medio | Decisión del dueño del proyecto |
| M11 | `ACCEPTANCE_2_7.md` fuera del inventario declarado | Medio | Decisión de gobernanza documental |
| B1-B9 | Ver detalle arriba | Bajo | Sin hito asociado / alcance futuro |

---

## Qué NO se encontró (puntos positivos a preservar)

- No hay ADRs contradictorias entre sí, ni referencias cruzadas rotas hacia archivos/scripts inexistentes.
- No hay dependencias circulares en `docs/ROADMAP.md`; la cadena de hitos es lineal y consistente, incluido el reordenamiento documentado del Hito 10 (ADR 0026).
- No se detectó ninguna instancia viva (no ya corregida) del bug `OUTPUT="$(cmd)" || true; CODE=$?` en los tests.
- `docs/TEST_CASES.md`, `tests/docker/build-and-test-all.sh` y `.github/workflows/ci.yml` están sincronizados en sus IDs de caso de prueba.
- Todos los tests funcionales de `tests/docker/` tienen guarda `/.dockerenv`, previniendo ejecución accidental en un host real.
- `scripts/lib/backup.sh` verifica integridad completa (manifiesto por hash) antes de cualquier operación destructiva — cumple la política de seguridad de AGENT.md.
- No se encontraron scripts huérfanos: todo `install_*.sh` en disco está referenciado en `setup.js`, salvo `install_nodejs.sh`, correctamente retirado y documentado como tal.
