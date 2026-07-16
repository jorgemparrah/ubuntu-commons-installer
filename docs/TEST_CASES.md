# TEST_CASES.md

# Casos de prueba funcionales

Este documento lista los casos de prueba funcionales por comando (o combinación de comandos), sus condiciones iniciales, y qué imagen/Dockerfile de `tests/docker/` los cubre. Se actualiza a medida que se agregan comandos o escenarios nuevos — es la fuente de verdad a partir de la cual se derivan los Dockerfiles, no al revés.

Convención de estado: `✅ pasa` / `❌ falla` / `🚧 pendiente de implementar`.

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

Cubierto hoy por: `tests/docker/run-all-tests.sh` (agrupa U01-U07 vía `tests/test_router.sh`, `tests/test_doctor.sh`, `tests/test_backup.sh`, `tests/test_migrations.sh`, `tests/test_status_mapping.js`).

## Nivel 2 — Migración NVM → Mise (`001_nvm_to_mise.sh`)

Instalan software real (NVM, Node, Mise); solo corren en contenedores desechables.

| ID | Escenario | Condición inicial | Imagen | Resultado esperado | Estado |
|---|---|---|---|---|---|
| M01 | Sin NVM instalado | Home vacío | `Dockerfile` (base) | `migrate check` de `001_nvm_to_mise` dice "no aplica"; `migrate` no falla, simplemente omite la migración | ✅ pasa (cubierto como parte del paso 0 de M02, antes de instalar NVM) |
| M02 | Desde cero: instalar NVM en tiempo de ejecución + 1 versión de Node, luego migrar | NVM instalado durante la corrida del test (no en el build de la imagen) | `Dockerfile` (base) | `.nvm` movido a backup, Mise instalado, Node accesible vía Mise, marca de finalización, idempotente | ✅ pasa |
| M03 | Home reutilizado simple: NVM + 1 versión de Node ya en la imagen | NVM + Node (alias `default` = `lts/*`) horneados en el build | `Dockerfile.nvm-single` | Igual que M02, partiendo de un estado "ya existente" en vez de instalado en la corrida | ✅ pasa |
| M04 | Home reutilizado con múltiples versiones, alias `default` != versión más alta | NVM + 2 versiones (Node 18 y la LTS vigente), alias `default` fijado a la más vieja (18) | `Dockerfile.nvm-multi` | La versión global que queda en Mise coincide con la que resuelve el alias `default` de NVM, **no** con "la más alta detectada" | ✅ pasa (encontró y corrigió un bug real: `alias/default` guarda el valor tal cual, ej. `"18"`, no la versión resuelta `"v18.20.8"`) |
| M05 | Ejecutar `migrate` dos veces sobre el mismo estado ya migrado | Cualquiera de M02-M04, ya aplicada una vez | Las mismas de M02-M04 | No se crea una segunda sesión de backup; el archivo informativo/estado no cambia | ✅ pasa (incluido al final de M02-M04) |
| M06 | Mise ya instalado antes de migrar (por ejemplo, de una corrida anterior fallida a medias) | NVM + Mise ya presente | 🚧 sin imagen dedicada todavía | La migración detecta Mise existente y no lo reinstala, pero sigue instalando las versiones de Node y moviendo `.nvm` | 🚧 pendiente de implementar |
| M07 | `apply` falla a mitad de camino (por ejemplo, sin conexión a internet para instalar Mise) | NVM instalado, sin acceso de red dentro del contenedor | 🚧 sin imagen dedicada todavía | La migración no marca finalización, muestra notas de rollback, no deja `.nvm` a medio mover | 🚧 pendiente de implementar |

Cubierto hoy por:
- `tests/docker/test_nvm_to_mise_apply.sh` → M01, M02, M05 (imagen base)
- `tests/docker/test_nvm_to_mise_prebaked.sh` → M03, M04, M05 (imágenes `nvm-single` y `nvm-multi`)
- `tests/docker/build-and-test-all.sh` → arma todas las imágenes (24.04 y 26.04) y corre Nivel 1 + Nivel 2 (M02-M05) en cada una

## Matriz de sistema operativo

Todos los casos anteriores corren en **Ubuntu 24.04 y 26.04** (`--build-arg UBUNTU_VERSION=`).

## Cómo se relacionan los Dockerfiles con este documento

Cada Dockerfile de `tests/docker/` existe porque un caso de prueba de este documento necesita esa condición inicial específica:

- `Dockerfile` → condición inicial "vacío" (U01-U07, M01, M02)
- `Dockerfile.nvm-single` → condición inicial "NVM + 1 versión de Node, alias default = lts/*" (M03)
- `Dockerfile.nvm-multi` → condición inicial "NVM + 2 versiones, alias default = la más vieja" (M04)

Si se agrega un caso de prueba nuevo que necesite una condición inicial que ningún Dockerfile actual provee (por ejemplo M06 o M07), el flujo es: **primero** agregar la fila a este documento con su condición inicial, **después** crear el Dockerfile/script que la implemente.
