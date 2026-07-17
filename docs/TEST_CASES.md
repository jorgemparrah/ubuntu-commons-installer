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
| I01 | `install_system_utils.sh` ya no se autoejecuta al invocarse sin argumentos | Ninguna (mocks de apt/sudo/dpkg) | Prueba simulada (mocks) | Código != 0, ningún `apt install` interceptado | ✅ pasa |
| I02 | `install_system_utils.sh` contrato `status\|install\|uninstall\|reinstall` | Mocks con dpkg "instalado"/"no instalado" | Prueba simulada (mocks) | `status` reporta INSTALLED/NOT_INSTALLED correctamente, de solo lectura; `install` invoca `apt install`; subcomando inválido falla | ✅ pasa |
| I03 | `install_development_tools.sh` — mismo caso que I01/I02 | Igual que I01/I02 | Prueba simulada (mocks) | Igual que I01/I02 | ✅ pasa |
| I04 | `install_multimedia.sh` — mismo caso que I01/I02, más `DEBIAN_FRONTEND=noninteractive` para el EULA de `ubuntu-restricted-extras` | Igual que I01/I02 | Prueba simulada (mocks) | Igual que I01/I02, y el código fuente fija `DEBIAN_FRONTEND=noninteractive` antes de instalar | ✅ pasa |

Cubierto hoy por: `tests/test_system_utils_contract.sh` (I01-I04), incluido en `tests/docker/run-all-tests.sh` (corre también dentro de `tests/docker/build-and-test-all.sh` y en el job `lint`/`base` del CI).

Instala software real (Mise, kubectl); solo corre en contenedores desechables.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| K01 | `install_kubectl.sh` instala kubectl vía Mise, nunca vía Snap | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` instala Mise+kubectl; `status` INSTALLED después, código 0; `mise which kubectl` resuelve un ejecutable; `snap list` no incluye kubectl; una segunda corrida de `install` no falla (idempotencia); subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_kubectl_via_mise.sh` (K01), incluido en `tests/docker/build-and-test-all.sh`.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| Y01 | `install_yarn.sh` instala Yarn vía Mise, nunca vía apt (paquete `yarn` de Ubuntu es en realidad `cmdtest`) | Home vacío | `Dockerfile` (base) | `status` NOT_INSTALLED antes, código ≠0; `install` instala Mise+Yarn; `status` INSTALLED después, código 0; `mise which yarn` resuelve un ejecutable; el paquete apt `yarn` nunca se instala; una segunda corrida de `install` no falla (idempotencia); subcomando inválido falla | ✅ pasa |

Cubierto hoy por: `tests/docker/test_yarn_via_mise.sh` (Y01), incluido en `tests/docker/build-and-test-all.sh`.

## Matriz de sistema operativo

Todos los casos anteriores corren en **Ubuntu 24.04 y 26.04** (`--build-arg UBUNTU_VERSION=`).

## Cómo se relacionan los Dockerfiles con este documento

Cada Dockerfile de `tests/docker/` existe porque un caso de prueba de este documento necesita esa condición inicial específica:

- `Dockerfile` → condición inicial "vacío" (U01-U07, M01, M02, M07)
- `Dockerfile.nvm-single` → condición inicial "NVM + 1 versión de Node, alias default = lts/*" (M03)
- `Dockerfile.nvm-multi` → condición inicial "NVM + 2 versiones, alias default = la más vieja" (M04)
- `Dockerfile.nvm-mise-preexisting` → condición inicial "NVM + 1 versión de Node + Mise ya instalado" (M06)

Si se agrega un caso de prueba nuevo que necesite una condición inicial que ningún Dockerfile actual provee, el flujo es: **primero** agregar la fila a este documento con su condición inicial, **después** crear el Dockerfile/script que la implemente.
