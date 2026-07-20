# TEST_CASES.md

# Casos de prueba funcionales

Este documento lista los casos de prueba funcionales por comando (o combinación de comandos), sus condiciones iniciales, y qué imagen/Dockerfile de `tests/docker/` los cubre. Se actualiza a medida que se agregan comandos o escenarios nuevos — es la fuente de verdad a partir de la cual se derivan los Dockerfiles, no al revés.

Convención de estado: `✅ pasa` / `❌ falla` / `🚧 pendiente de implementar`.

## Cómo correr TODO

```bash
bash tests/docker/build-and-test-all.sh          # Ubuntu 24.04 y 26.04
bash tests/docker/build-and-test-all.sh 24.04     # solo una versión
```

Este es el **único punto de entrada**: arma las 4 imágenes (base, `nvm-single`, `nvm-multi`, `nvm-mise-preexisting`) para cada versión de Ubuntu listada, y corre dentro de cada una todos los casos de este documento. No hace falta ejecutar ningún otro script de `tests/docker/` por separado salvo que quieras aislar un caso puntual para depurar.

## Nivel 1 — Comandos de solo lectura / con estado mínimo

No requieren software real preinstalado. Corren sobre la imagen base.

| ID | Comando | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| U01 | `help`, `--help` | Ninguna | `Dockerfile` (base) | Código 0, muestra el uso | ✅ pasa |
| U02 | `version` | Ninguna | `Dockerfile` (base) | Código 0, muestra el nombre del proyecto | ✅ pasa |
| U03 | comando desconocido | Ninguna | `Dockerfile` (base) | Código != 0, mensaje de error + ayuda | ✅ pasa |
| U04 | `help`/`version` con `PATH` sin Node | Ninguna | `Dockerfile` (base) | Código 0 igual (no dependen de Node) | ✅ pasa |
| U05 | `doctor`, `doctor --verbose` | Home vacío (sin NVM/Mise/etc.) | `Dockerfile` (base) | Código 0, reporta todo como "no instalado", no modifica `$HOME` | ✅ pasa |
| U06 | `backup`, `backup --dry-run` | Home con `tests/fixtures/sample_home/` copiado | `Dockerfile` (base) | Sesión con timestamp, manifest.tsv, dry-run no crea nada, no sobrescribe | ✅ pasa |
| U07 | `migrate --list`/`--dry-run`/`migrate` (framework genérico) | Home vacío + migración de ejemplo `000_example_noop` | `Dockerfile` (base) | Ciclo completo list→dry-run→apply→list, idempotente | ✅ pasa |
| U08 | `backup_dir_manifest`/`backup_move_dir`: integridad completa antes de eliminar el origen | Directorios de prueba con archivo, symlink y subdirectorio vacío; 5 variantes deliberadamente alteradas (contenido, symlink, directorio vacío faltante, permiso, contenido distinto mismo tamaño) | `Dockerfile` (base) | Cada alteración cambia el manifiesto; el camino feliz mueve todo correctamente; no se reutiliza un destino ya presente | ✅ pasa |
| BOOT01 | Flujo interactivo (`./setup.sh` sin argumentos) en workstation limpia | Node/npm de apt inhabilitados dentro del contenedor, sin NVM ni Mise | `Dockerfile` (base) | Nunca instala NVM; instala Mise con confirmación explícita, instala Node vía Mise, dejan el bloque gestionado en `.bashrc`; `install_nodejs.sh` (legado) se niega siempre a instalar/desinstalar/reinstalar, sin ninguna variable de entorno que lo reactive | ✅ pasa |

Cubierto hoy por: `tests/docker/run-all-tests.sh` (agrupa U01-U08 vía `tests/test_router.sh`, `tests/test_doctor.sh`, `tests/test_backup.sh`, `tests/test_backup_move_dir.sh`, `tests/test_migrations.sh`, `tests/test_status_mapping.js`, `tests/test_install_nodejs_legacy.sh`) y `tests/docker/test_bootstrap_mise_no_nvm.sh` (BOOT01).

## Nivel 2 — Migración NVM → Mise (`001_nvm_to_mise.sh`)

Instalan software real (NVM, Node, Mise); solo corren en contenedores desechables.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| M01 | Sin NVM instalado | Home vacío | `Dockerfile` (base) | `migrate check` de `001_nvm_to_mise` dice "no aplica"; `migrate` no falla, simplemente omite la migración | ✅ pasa (cubierto como parte del paso 0 de M02, antes de instalar NVM) |
| M02 | Desde cero: instalar NVM en tiempo de ejecución + 1 versión de Node, luego migrar | NVM instalado durante la corrida del test (no en el build de la imagen) | `Dockerfile` (base) | `.nvm` movido a backup, Mise instalado, Node accesible vía Mise, marca de finalización, idempotente | ✅ pasa |
| M03 | Home reutilizado simple: NVM + 1 versión de Node ya en la imagen | NVM + Node (alias `default` = `lts/*`) horneados en el build | `Dockerfile.nvm-single` | Igual que M02, partiendo de un estado "ya existente" en vez de instalado en la corrida | ✅ pasa |
| M04 | Home reutilizado con múltiples versiones, alias `default` != versión más alta | NVM + 2 versiones (Node 18 y la LTS vigente), alias `default` fijado a la más vieja (18) | `Dockerfile.nvm-multi` | La versión global que queda en Mise coincide con la que resuelve el alias `default` de NVM, **no** con "la más alta detectada" | ✅ pasa (encontró y corrigió un bug real: `alias/default` guarda el valor tal cual, ej. `"18"`, no la versión resuelta `"v18.20.8"`) |
| M05 | Ejecutar `migrate` dos veces sobre el mismo estado ya migrado | Cualquiera de M02-M04, ya aplicada una vez | Las mismas de M02-M04 | No se crea una segunda sesión de backup; el archivo informativo/estado no cambia | ✅ pasa (incluido al final de M02-M04) |
| M06 | Mise ya instalado antes de migrar (por ejemplo, de una corrida anterior fallida a medias) | NVM + Mise ya presente | `Dockerfile.nvm-mise-preexisting` | La migración detecta Mise existente y no lo reinstala (misma versión antes/después), pero sigue instalando las versiones de Node vía Mise, resuelve el alias global y mueve `.nvm` | ✅ pasa |
| M07 | `apply` falla a mitad de camino, en 5 checkpoints inyectados vía `UCI_TEST_FAIL_MIGRATION_AT` (variable exclusiva de pruebas, sin efecto si no se define): `after_shell_backup`, `before_mise_install`, `after_mise_before_node`, `after_node_before_move`, `before_done_marker` | NVM + Node instalados en tiempo de ejecución, sin Mise | `Dockerfile` (base) | Código de salida ≠ 0 en cada checkpoint; nunca se marca `.done`; `.nvm` no se pierde (intacto o ya movido de forma segura al backup si el fallo es el último checkpoint); la sesión de backup del intento fallido se conserva; los archivos de shell quedan recuperables desde esa sesión; una corrida posterior sin la variable completa la migración y marca `.done`, sin duplicar el bloque gestionado de Mise. Recuperación por **reanudación idempotente** (no rollback automático) — ver `scripts/migrations/001_nvm_to_mise.sh` y `docs/TESTING.md` | ✅ pasa |
| M08 | Limpieza de líneas conocidas de NVM en `.bashrc` + reportes de inventario persistidos | Cualquiera de M02-M04 | Las mismas de M02-M04 | Las líneas exactas del instalador de NVM se eliminan de `.bashrc`; `.bashrc` final no contiene ninguna mención a "nvm"; `reports/nvm-versions.tsv`, `reports/nvm-global-packages.tsv` y `reports/shell-changes.tsv` quedan escritos en la sesión de backup con datos reales (incluye un paquete global instalado a propósito con `npm install -g`) | ✅ pasa (verificado también manualmente inspeccionando el contenido de los tres reportes) |

Cubierto hoy por:
- `tests/docker/test_nvm_to_mise_apply.sh` → M01, M02, M05, M08 (imagen base)
- `tests/docker/test_nvm_to_mise_prebaked.sh` → M03, M04, M05, M08 (imágenes `nvm-single` y `nvm-multi`)
- `tests/docker/test_nvm_to_mise_mise_preexisting.sh` → M06 (imagen `nvm-mise-preexisting`)
- `tests/docker/test_nvm_to_mise_fault_injection.sh` → M07 (imagen base)
- `tests/docker/build-and-test-all.sh` → **único punto de entrada**: arma todas las imágenes (24.04 y 26.04) y corre Nivel 1 (incluido BOOT01) + Nivel 2 (M01-M08) en cada una

## Nivel 3 — Gestor de runtimes (`scripts/lib/runtime.sh`, `setup.sh runtime status`)

Instala software real (Mise, Node, Python); solo corre en contenedores desechables.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| R01 | `runtime status` sin Mise instalado | Home vacío | `Dockerfile` (base) | Código 0, avisa que Mise no está instalado, no falla | ✅ pasa |
| R02 | `runtime status` con Node gestionado por Mise | Mise instalado + `node@lts` fijado como global | `Dockerfile` (base) | Node.js aparece "gestionado por Mise"; el resto de runtimes del catálogo (Python, Java, Go, Rust) aparecen como "no gestionado" | ✅ pasa |
| R03 | `runtime status` con dos runtimes distintos gestionados (Node y Python) | Igual que R02 + `python@latest` fijado como global | `Dockerfile` (base) | Ambos aparecen como gestionados (prueba que la abstracción es genérica, no algo hecho a medida solo para Node); Java/Go/Rust siguen "no gestionado" | ✅ pasa |
| R04 | `runtime status` no modifica nada | Igual que R03 | `Dockerfile` (base) | El contenido de `~/.config/mise` y `~/.local/share/mise` es idéntico antes/después (hash de archivos) | ✅ pasa |
| R05 | Subcomando inválido (`runtime esto-no-existe`) | Ninguna | `Dockerfile` (base) | Código != 0 | ✅ pasa |
| R06 | La migración NVM→Mise usa `scripts/lib/runtime.sh` en vez de duplicar la instalación de Mise | Cualquiera de M02-M04 | Las mismas de M02-M04 | Sin cambios de comportamiento tras el refactor (re-corridas de M02-M04 después del refactor, todas en verde) | ✅ pasa |

Cubierto hoy por: `tests/docker/test_runtime_status.sh` (R01-R05, imagen base), re-ejecución de `test_nvm_to_mise_apply.sh`/`test_nvm_to_mise_prebaked.sh` tras el refactor (R06), todo incluido en `tests/docker/build-and-test-all.sh`.

## Nivel 4 — Instaladores: contrato de interfaz (Hito 9, Fase B)

Ver `docs/UBUNTU_COMPATIBILITY.md` para la matriz completa de compatibilidad Ubuntu 24.04/26.04 de los 30 instaladores. Esta sección solo cubre los casos de prueba nuevos agregados junto con las correcciones de la Fase B. Prueba simulada (comandos `apt`/`sudo`/`dpkg` interceptados con mocks en PATH, nunca instala nada real) — corre en cualquier máquina, incluida la de desarrollo.

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I01 | `install_system_utils.sh` ya no se autoejecuta al invocarse sin argumentos | Ninguna (mocks de apt-get/apt/sudo/dpkg) | Prueba simulada (mocks) | Código != 0, ningún `apt-get install` interceptado | ✅ pasa |
| I02 | `install_system_utils.sh` (agrupador delgado, ver [ADR 0031](adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md)): delega `status\|install\|uninstall` en sus 3 instaladores individuales (`install_meld.sh`, `install_baobab.sh`, `install_gparted.sh`); `update`/`repair` se rechazan a propósito | Mocks con dpkg "instalado"/"no instalado" para cualquier paquete consultado | Prueba simulada (mocks) | `status` reporta INSTALLED solo si los 3 miembros lo están, NOT_INSTALLED si falta cualquiera, de solo lectura; `install`/`uninstall` invocan `apt-get install`/`apt-get purge` (delegado en los miembros); subcomando inválido falla; `update`/`repair` a nivel de grupo salen con código ≠0 | ✅ pasa |
| I03 | `install_development_tools.sh` (agrupador delgado de 7 instaladores individuales: `wget`, `curl`, `git`, `build-essential`, `software-properties-common`, `apt-transport-https`, `gnupg2`) — mismo caso que I01/I02 | Igual que I01/I02 | Prueba simulada (mocks) | Igual que I01/I02 | ✅ pasa |
| I04 | `install_multimedia.sh` (agrupador delgado de 4 instaladores individuales: `cheese`, `v4l-utils`, `ubuntu-restricted-extras`, `vlc`) — mismo caso que I01/I02, más `DEBIAN_FRONTEND=noninteractive` para el EULA de `ubuntu-restricted-extras` (ahora fijado en `install_ubuntu_restricted_extras.sh`, no en el agrupador) | Igual que I01/I02 | Prueba simulada (mocks) | Igual que I01/I02, y `install_ubuntu_restricted_extras.sh` fija `DEBIAN_FRONTEND=noninteractive` antes de instalar | ✅ pasa |
| I05 | `install_system_update.sh`/`install_final_update.sh`: `status` deja de ser un stub fijo en `INSTALLED` | Mocks de `apt list --upgradable`/`apt-get --simulate autoremove` con 0 o N pendientes | Prueba simulada (mocks) | Sin pendientes: INSTALLED, código 0, `status` no ejecuta upgrade/autoremove real; con pendientes (o paquetes huérfanos en Final Update): NOT_INSTALLED, código ≠0; `install` sí invoca `apt upgrade` real; subcomando inválido falla | ✅ pasa |
| I07 | `install_mongodb_compass.sh` falla con mensaje claro y limpia el `.deb` parcial si la descarga o la instalación fallan | Mocks de `wget`/`apt` devolviendo error | Prueba simulada (mocks) | Código ≠0 si `wget` falla, mensaje claro, sin `.deb` residual; código ≠0 si `apt install` del `.deb` falla, igual sin `.deb` residual | ✅ pasa |
| I08 | `install_kernel.sh`: `resolve_hwe_fallback_package_name()` usa la versión numérica de Ubuntu, no el codename | Ninguna (función pura, sin I/O; el archivo se sourcea con guarda para no disparar `main()`) | Prueba unitaria | `resolve_hwe_fallback_package_name "24.04"` → `linux-generic-hwe-24.04`; el código ya no usa `lsb_release -cs`, usa `lsb_release -rs`; ninguna referencia a `update-grub`/`grub-mkconfig`/`reboot`/`shutdown` | ✅ pasa |
| I09 | `install_chrome.sh` revisa la arquitectura antes de descargar el `.deb` amd64 (ver [ADR 0028](adr/0028-arquitectura-soportada-amd64.md)) | Mocks de `dpkg --print-architecture` devolviendo `amd64` y `arm64` | Prueba simulada (mocks) | amd64: `status` NOT_INSTALLED, `install` intenta descargar; arm64: `status` UNSUPPORTED, `install` rechaza sin descargar nada, mensaje claro | ✅ pasa |
| I10 | 8 instaladores Snap (DBeaver, GitKraken, Insomnia, Postman, GIMP, OBS Studio, Spotify, Zoom): `status` distingue snap instalado / no instalado / snapd ausente | Mocks de `snap list` con 3 variantes (instalado, vacío, comando `snap` inexistente) | Prueba simulada (mocks) | Instalado → INSTALLED/código 0; no instalado → NOT_INSTALLED/código≠0; snapd ausente → UNKNOWN/código≠0 (antes se confundía con NOT_INSTALLED) | ✅ pasa |

Cubierto hoy por: `tests/test_system_utils_contract.sh` (I01-I04), `tests/test_system_update_contract.sh` (I05), `tests/test_mongodb_compass_download.sh` (I07), `tests/test_kernel_hwe_fallback.sh` (I08), `tests/test_chrome_arch_check.sh` (I09) y `tests/test_snap_installers_contract.sh` (I10), todos incluidos en `tests/docker/run-all-tests.sh` (corre también dentro de `tests/docker/build-and-test-all.sh`) y, desde el cierre técnico de 2026-07-19, cada uno en su propio job de CI (`system-utils-contract`, `system-update-contract`, `mongodb-compass-download`, `kernel-hwe-fallback`, `chrome-arch-check`, `snap-installers-contract`). El caso de Cursor (antes I06, validación estática del AppImage) se retiró y reemplazó por C01 (prueba funcional Docker), ver más abajo — Cursor pasó a instalarse vía su repo APT oficial, no AppImage.

## Nivel 5 — Infraestructura compartida de instaladores (Hito 11, Fase 1)

Ver `docs/adr/0029-contrato-completo-de-instalador-referencia.md` y `docs/ARCHITECTURE.md` §21. Prueba simulada (mocks/fixtures, nunca instala nada real) — corre en cualquier máquina, incluida la de desarrollo.

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I11 | `scripts/lib/installer_cli.sh`: dispatcher compartido de 6 verbos | Fixtures temporales que sourcean la biblioteca real con funciones falsas | Prueba simulada (fixtures) | Los 6 verbos válidos invocan su función correspondiente; comando desconocido y ausencia de argumentos caen al mismo caso de uso (código 1, sin ejecutar nada); función obligatoria ausente se detecta con `declare -F` (código 2, sin `eval`); `update`/`repair` sin implementación propia se rechazan explícitamente (código 3), nunca caen a `reinstall`; `reinstall` sin función propia usa el fallback mecánico (`uninstall_tool` + `install_tool`); los códigos de salida de las funciones del instalador se propagan tal cual, sin reescribirse | ✅ pasa |
| I12 | `scripts/lib/apt.sh`: helpers APT compartidos (`apt_package_installed`, `apt_all_packages_installed`) | Mocks de `dpkg -l <paquete>` con estados `ii`/`rc`/ausente | Prueba simulada (mocks) | `ii` → instalado; estado residual `rc` y paquete ausente → no instalado (nunca se confunden); con varios paquetes, todos instalados → éxito; uno ausente o en `rc` → fallo; un error inesperado de `dpkg` (código ≠0/1) nunca se interpreta como "instalado" | ✅ pasa |
| I13 | `install_cmatrix.sh` (instalador piloto de la Fase 1): ciclo de vida completo de los 6 verbos sobre la infraestructura compartida | Mocks de `dpkg`/`apt`/`apt-get`/`sudo`, estado inicial sin el paquete | Prueba simulada (mocks) | Estado inicial NOT_INSTALLED; `install` invoca `apt-get install -y`; segunda instalación idempotente; estado INSTALLED tras instalar; OUTDATED si el cache local de apt muestra una actualización; `update` invoca `--only-upgrade`; `repair` corre `dpkg --configure -a` + reinstalación forzada; `uninstall` invoca `apt-get purge` (no `remove`); estado final NOT_INSTALLED; comando inválido falla con mensaje de uso | ✅ pasa |

Cubierto hoy por: `tests/test_installer_cli.sh` (I11), `tests/test_apt_helpers.sh` (I12), `tests/test_cmatrix_installer.sh` (I13), incluidos en `tests/docker/run-all-tests.sh` (corre también dentro de `tests/docker/build-and-test-all.sh`) y, cada uno, en su propio job de CI (`installer-cli`, `apt-helpers`, `cmatrix-installer`).

### Fase 2 — instaladores apt-simples migrados (ranger, terminator, flameshot)

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I14 | `install_ranger.sh`: ciclo de vida completo de los 6 verbos | Mocks de `dpkg`/`apt`/`apt-get`/`sudo` | Prueba simulada (mocks) | Comando desconocido falla; estado inicial NOT_INSTALLED; `install` instala e idempotente en segunda corrida; estado INSTALLED; `update` con y sin candidato disponible; `repair` sobre estado BROKEN (dpkg dice instalado, binario ausente) y rechazo explícito de `repair` sobre NOT_INSTALLED; `reinstall` usa `apt-get install --reinstall` (nunca pasa por `purge`); `uninstall` purga e idempotente en segunda corrida; propagación de un fallo real de `apt-get`; estado residual `rc` de dpkg nunca se confunde con instalado | ✅ pasa |
| I15 | `install_terminator.sh` — mismos escenarios que I14 | Igual que I14 | Prueba simulada (mocks) | Igual que I14 | ✅ pasa |
| I16 | `install_flameshot.sh` — mismos escenarios que I14, más: `install` documenta explícitamente que el atajo `PrintScreen` (ADR 0019) todavía no se configura | Igual que I14 | Prueba simulada (mocks) | Igual que I14, y la salida de `install` menciona "PrintScreen" | ✅ pasa |

Cubierto hoy por: `tests/test_ranger_installer.sh` (I14), `tests/test_terminator_installer.sh` (I15), `tests/test_flameshot_installer.sh` (I16), incluidos en `tests/docker/run-all-tests.sh` (corre también dentro de `tests/docker/build-and-test-all.sh`) y, cada uno, en su propio job de CI (`ranger-installer`, `terminator-installer`, `flameshot-installer`).

### Infraestructura previa a la Fase 3 — registro central de metadata (`tools_registry.sh`/`tools_catalog.sh`)

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I17 | `scripts/lib/tools_registry.sh` (mecanismo) y `scripts/lib/tools_catalog.sh` (datos de `cmatrix`/`ranger`, ver ADR 0030) | Entradas de prueba registradas en memoria, más el catálogo real sourceado | Prueba simulada (fixtures) + validación cruzada contra archivos reales | `tools_registry_has`/`tools_registry_field`/`tools_registry_ids` responden correctamente, incluida ausencia de campo/id; volver a registrar un id no lo duplica y sobrescribe sus campos; `cmatrix` y `ranger` están en el catálogo; el `script` declarado de cada uno existe en el repositorio; si `manager=apt`, el script sourcea `scripts/lib/apt.sh`; si `migration_status=migrated`, el script usa `installer_run_cli` | ✅ pasa |

Cubierto hoy por: `tests/test_tools_registry.sh` (I17), incluido en `tests/docker/run-all-tests.sh` y en su propio job de CI (`tools-registry`).

### Separación de instaladores multi-paquete (ver ADR 0031)

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I18 | Los 14 instaladores individuales creados al separar `install_development_tools.sh`/`install_multimedia.sh`/`install_system_utils.sh` (`wget`, `curl`, `git`, `build-essential`, `software-properties-common`, `apt-transport-https`, `gnupg2`, `cheese`, `v4l-utils`, `ubuntu-restricted-extras`, `vlc`, `meld`, `baobab`, `gparted`): ciclo de vida completo de los 6 verbos, mismo patrón que `install_ranger.sh` | Mocks de `dpkg`/`apt`/`apt-get`/`sudo` | Prueba simulada (mocks) | Igual que I14, para cada uno de los 14; para los 3 paquetes meta sin binario propio (`build-essential`, `apt-transport-https`, `ubuntu-restricted-extras`) se omite el escenario de detección `BROKEN` vía `command -v` (limitación honesta documentada en ADR 0031) | ✅ pasa |

Cubierto hoy por: `tests/test_split_installers_contract.sh` (I18), incluido en `tests/docker/run-all-tests.sh` y en su propio job de CI (`split-installers-contract`).

### Primer consumidor real del registro central (ver ADR 0030, "trabajo futuro")

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I19 | `docs/TOOLS.md` no diverge de `scripts/lib/tools_catalog.sh`: cada instalador registrado en el catálogo (herramienta o agrupador) tiene su script mencionado en el inventario de documentación | El catálogo real sourceado, `docs/TOOLS.md` real leído del repositorio | Prueba simulada (validación cruzada, sin mocks) | Para cada id registrado, el nombre base de su `script` aparece en `docs/TOOLS.md`; si algún instalador nuevo se registra en el catálogo sin actualizar `docs/TOOLS.md`, esta prueba falla | ✅ pasa |

Cubierto hoy por: `tests/test_tools_catalog_docs_consistency.sh` (I19), incluido en `tests/docker/run-all-tests.sh` y en su propio job de CI (`tools-catalog-docs-consistency`).

### Siguiente grupo apt-simple tras la Fase 2: ULauncher

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I20 | `install_ulauncher.sh` migrado al contrato completo de 6 verbos (`scripts/lib/installer_cli.sh`/`scripts/lib/apt.sh`); a diferencia de los demás apt-simples, `install`/`uninstall` agregan/quitan el PPA oficial (`ppa:agornostal/ulauncher`) | Mocks de `dpkg`/`apt`/`apt-get`/`sudo`/`add-apt-repository` | Prueba simulada (mocks) | Igual que I14 (ranger), más: `install` agrega `universe` y el PPA antes de instalar; si `add-apt-repository` no existe todavía, instala `software-properties-common` primero; `uninstall` purga (no remove) y quita el PPA; `reinstall` no vuelve a tocar el PPA | ✅ pasa |

Cubierto hoy por: `tests/test_ulauncher_installer.sh` (I20, mocks — no toca la red), que complementa a `tests/docker/test_ulauncher_ppa.sh` (L01, prueba funcional real ya existente desde el Hito 9). Incluido en `tests/docker/run-all-tests.sh` y en su propio job de CI (`ulauncher-installer`).

### Segundo consumidor real del registro central (setup.js vs. catálogo)

| ID | Escenario | Condición inicial | Clasificación | Resultado esperado | Estado |
|---|---|---|---|---|---|
| I21 | El menú interactivo de `setup.js` no diverge de `scripts/lib/tools_catalog.sh`: cada herramienta registrada que el menú debería ofrecer (agrupadores y herramientas independientes, excluyendo los ids que son solo miembros internos de un agrupador) tiene una entrada real en el array `tools` | El catálogo real sourceado, `setup.js` real leído del repositorio | Prueba simulada (validación cruzada, sin mocks) | Para cada id registrado que no es miembro de un agrupador, el nombre base de su `script` aparece en `setup.js`; los miembros internos de un agrupador (ej. `wget` dentro de `development_tools_group`) se excluyen a propósito, ya que no tienen entrada propia en el menú | ✅ pasa |

Cubierto hoy por: `tests/test_tools_catalog_setup_js_consistency.sh` (I21), incluido en `tests/docker/run-all-tests.sh` y en su propio job de CI (`tools-catalog-setup-js-consistency`).

Cubierto hoy por: `tests/test_tools_registry.sh` (I17), incluido en `tests/docker/run-all-tests.sh` (corre también dentro de `tests/docker/build-and-test-all.sh`) y en su propio job de CI (`tools-registry`). Es infraestructura puramente aditiva (no cambia comportamiento de ningún instalador existente, ver ADR 0030); no migra más instaladores por sí sola.

### Validación manual pendiente: instaladores Snap en Ubuntu 26.04 Desktop

Ninguno de los 8 instaladores Snap (DBeaver, GitKraken, Insomnia, Postman, GIMP, OBS Studio, Spotify, Zoom) se prueba funcionalmente en CI: `snapd` no corre sin systemd dentro de los contenedores Docker usados por este proyecto. `tests/test_snap_installers_contract.sh` (I10) solo prueba la lógica de `status` con mocks. Antes de declarar cualquiera de estos 8 "probado funcionalmente" en Ubuntu 26.04, corresponde ejecutar esta pauta en un sistema Ubuntu 26.04 Desktop real (VM o máquina física, con systemd y snapd reales):

1. `./scripts/<categoría>/install_<herramienta>.sh status` → confirmar `NOT_INSTALLED` (estado inicial limpio).
2. `./scripts/<categoría>/install_<herramienta>.sh install` → confirmar que termina sin error.
3. `./scripts/<categoría>/install_<herramienta>.sh status` → confirmar `INSTALLED`.
4. Ejecutar o abrir la aplicación al menos una vez (confirmar que abre una ventana / no crashea al iniciar).
5. `./scripts/<categoría>/install_<herramienta>.sh install` de nuevo → confirmar idempotencia (no falla, no duplica nada).
6. `./scripts/<categoría>/install_<herramienta>.sh uninstall` → confirmar que termina sin error.
7. `./scripts/<categoría>/install_<herramienta>.sh status` → confirmar `NOT_INSTALLED` otra vez.

Repetir por cada uno de los 8. Ningún instalador Snap se marca como `compatible`/probado en `docs/UBUNTU_COMPATIBILITY.md` hasta que esta pauta se haya corrido al menos una vez en Ubuntu 26.04 Desktop real.

Instala software real (Mise, kubectl); solo corre en contenedores desechables.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| K01 | `install_kubectl.sh` instala kubectl vía Mise, nunca vía Snap | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` instala Mise+kubectl; `status` INSTALLED después, código 0; `mise which kubectl` resuelve un ejecutable; `snap list` no incluye kubectl; una segunda corrida de `install` no falla (idempotencia); subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_kubectl_via_mise.sh` (K01), incluido en `tests/docker/build-and-test-all.sh`.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| Y01 | `install_yarn.sh` instala Yarn vía Mise, nunca vía apt (paquete `yarn` de Ubuntu es en realidad `cmdtest`) | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` instala Mise+Yarn; `status` INSTALLED después, código 0; `mise which yarn` resuelve un ejecutable; el paquete apt `yarn` nunca se instala; una segunda corrida de `install` no falla (idempotencia); subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_yarn_via_mise.sh` (Y01), incluido en `tests/docker/build-and-test-all.sh`.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| Z01 | `install_oh_my_zsh.sh`/`install_powerlevel10k.sh` instalan el framework/tema real, no solo el paquete `zsh` | Home vacío | `Dockerfile` (base) | `~/.oh-my-zsh` y el tema `powerlevel10k` quedan clonados con su archivo principal; `status` INSTALLED después; segunda corrida de `install` no reclona (mismo commit git); ninguno crea/modifica `~/.zshrc`; subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_zsh_personalization.sh` (Z01), incluido en `tests/docker/build-and-test-all.sh`.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| L01 | `install_ulauncher.sh` agrega el PPA oficial (`ppa:agornostal/ulauncher`) antes de instalar | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` agrega el PPA e instala el paquete real; `status` INSTALLED después, código 0; segunda corrida de `install` no falla (idempotencia); subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_ulauncher_ppa.sh` (L01), incluido en `tests/docker/build-and-test-all.sh`.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| C01 | `install_cursor.sh` instala vía su repo APT oficial (signed-by, amd64+arm64), nunca AppImage/apt-key | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` agrega la clave GPG (keyring, no apt-key) y el repo con `signed-by`; `status` INSTALLED después, código 0; segunda corrida de `install` no falla (idempotencia); `uninstall` limpia paquete+repo+keyring; subcomando inválido falla | ✅ pasa |
| V01 | `install_vscode.sh` instala vía su repo APT oficial de Microsoft (signed-by, gnupg asegurado, keyring no vacío) | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` asegura `gnupg`, genera un keyring no vacío, agrega el repo con `signed-by` (nunca apt-key), declara `amd64,arm64,armhf`; `apt update` sigue funcionando con el repo activo; `status` INSTALLED después, código 0; segunda corrida de `install` no falla; `uninstall` limpia paquete+repo+keyring; `apt update` sigue sano después; subcomando inválido falla | ✅ pasa |
| D01 | `install_docker.sh`: detección dinámica de arquitectura/codename, clave y repo se crean siempre, paquete se instala si el proveedor lo publica para este codename | Home vacío | `Dockerfile` (base) | Arquitectura y codename detectados no vacíos; el keyring (`/etc/apt/keyrings/docker.asc`) y el archivo de repo se crean siempre, con `signed-by` y sin `apt-key`, aunque el paquete `docker-ce` no tenga candidato para este codename; si hay candidato: `install` instala de verdad, `status` INSTALLED, idempotencia en segunda corrida; si NO hay candidato: se reporta como **limitación de proveedor** documentada (no como fallo), sin fallback hacia el codename de otra versión de Ubuntu; nunca arranca el demonio ni usa Docker-en-Docker privilegiado | ✅ pasa (mecanismo); limitación de proveedor evaluada según disponibilidad real en cada corrida — ver resultado exacto en `docs/UBUNTU_COMPATIBILITY.md` |

Cubierto hoy por: `tests/docker/test_cursor_apt_repo.sh` (C01), `tests/docker/test_vscode_apt_repo.sh` (V01) y `tests/docker/test_docker_apt_repo.sh` (D01), incluidos en `tests/docker/build-and-test-all.sh` y, desde el cierre técnico de 2026-07-19, cada uno en su propio job de CI (`cursor-apt-repo`, `vscode-apt-repo`, `docker-apt-repo`).

## Matriz de sistema operativo

Todos los casos anteriores corren en **Ubuntu 24.04 y 26.04** (`--build-arg UBUNTU_VERSION=`).

## Cómo se relacionan los Dockerfiles con este documento

Cada Dockerfile de `tests/docker/` existe porque un caso de prueba de este documento necesita esa condición inicial específica:

- `Dockerfile` → condición inicial "vacío" (U01-U07, M01, M02, M07)
- `Dockerfile.nvm-single` → condición inicial "NVM + 1 versión de Node, alias default = lts/*" (M03)
- `Dockerfile.nvm-multi` → condición inicial "NVM + 2 versiones, alias default = la más vieja" (M04)
- `Dockerfile.nvm-mise-preexisting` → condición inicial "NVM + 1 versión de Node + Mise ya instalado" (M06)

Si se agrega un caso de prueba nuevo que necesite una condición inicial que ningún Dockerfile actual provee, el flujo es: **primero** agregar la fila a este documento con su condición inicial, **después** crear el Dockerfile/script que la implemente.
