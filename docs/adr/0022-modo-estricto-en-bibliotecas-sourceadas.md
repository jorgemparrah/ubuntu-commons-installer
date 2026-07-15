# 0022. Las bibliotecas pensadas para `source` no declaran su propio modo estricto

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

[ADR 0008](0008-bash-estricto-en-scripts-nuevos.md) exige `set -Eeuo pipefail` en todo script nuevo. Al implementar `scripts/lib/logging.sh` y `scripts/bootstrap/preflight.sh` (Hito 2: Bootstrap) surgió un caso no cubierto por esa ADR: estos archivos nunca se ejecutan como proceso propio, siempre se cargan con `source` desde `setup.sh`. En Bash, `source`/`.` no tiene alcance (scope) propio para las opciones de shell: si un archivo sourceado ejecuta `set -Eeuo pipefail`, esas opciones quedan activas en el script que lo cargó durante el resto de su ejecución, se haya pedido o no.

Esto es relevante porque `setup.sh` contiene el flujo interactivo histórico (`main_setup` y sus funciones), que usa varios `read` para pausar la ejecución o pedir confirmación. Si una biblioteca sourceada activara `set -e` de forma "silenciosa" antes de que `setup.sh` mismo decida su propio modo estricto, un `read` fallido por EOF/entrada no interactiva abortaría el script completo — un cambio de comportamiento no buscado y difícil de rastrear, porque el `set -e` "vendría" de un archivo que aparenta ser solo una biblioteca de funciones.

## Decisión

Los archivos pensados exclusivamente para cargarse con `source` (bibliotecas de funciones, como `scripts/lib/logging.sh` y `scripts/bootstrap/preflight.sh`) **no** declaran `set -Eeuo pipefail` ni ninguna otra opción de shell. Cada uno documenta esto explícitamente en un comentario. El modo estricto lo controla únicamente el script que se ejecuta como proceso (por ejemplo `setup.sh`), que sí sigue [ADR 0008](0008-bash-estricto-en-scripts-nuevos.md) sin excepción.

Estas bibliotecas también incluyen una guarda de carga única (`if [[ "${UCI_..._LOADED:-0}" == "1" ]]; then return 0; fi`) para poder sourcearse más de una vez sin error, dado que declaran variables `readonly`.

## Consecuencias

- Al escribir una nueva biblioteca pensada para `source` (por ejemplo, un futuro `scripts/lib/backup.sh`), se sigue este mismo patrón: sin `set` propio, con guarda de carga.
- Un script que SÍ se ejecuta directamente (por ejemplo, una futura migración en `scripts/migrations/NNN_*.sh`) sigue aplicando [ADR 0008](0008-bash-estricto-en-scripts-nuevos.md) sin cambios; esta ADR no lo exime.
- `bash -n` sigue validando la sintaxis de estos archivos igual, ya que es un chequeo estático que no depende de si se declara o no `set -e`.
