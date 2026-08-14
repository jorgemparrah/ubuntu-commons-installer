# 0048. Un `apt-get update` fallido no es fatal, y los repositorios rotos se limpian

Fecha: 2026-08-14
Estado: Aceptada

## Contexto

La primera ejecución real del instalador interactivo (Ubuntu 26.04, 27 herramientas seleccionadas) terminó con **26 de 27 fallas**. Al analizar el log, 23 de esas 26 no tenían ningún problema propio: fallaron por una sola causa compartida.

### La cadena de fallos

1. `scripts/development/install_ngrok.sh` descargaba la clave GPG de ngrok —que se publica en **ASCII armor**— y la guardaba como `ngrok-archive-keyring.gpg` **sin desarmarla**. APT decide el formato por la extensión, así que la ignoró: `the file has an unsupported filetype`.
2. Con el keyring ignorado, el repositorio de ngrok quedó **sin firmar**, y `apt-get update` empezó a devolver un código distinto de cero de forma **permanente**.
3. `apt_install_packages()` hacía `sudo apt-get update` bajo `set -Eeuo pipefail`. Como `apt-get update` devuelve error si **cualquier** repositorio del sistema está roto —aunque no tenga nada que ver con lo que se instala— todo instalador que pasara por APT abortaba antes de intentar nada.

El resultado: un bug en el instalador de ngrok dejó sin instalar `cmatrix`, `Meld`, `GParted`, `FFmpeg`, VS Code, Docker y otras 17 herramientas que vienen de los repositorios de Ubuntu o de repositorios sanos.

Un segundo repositorio contribuía al mismo bloqueo: el de Azure CLI, escrito con `Suites: resolute` cuando Microsoft aún no publicaba para Ubuntu 26.04 (verificado: `resolute` → 404, `noble` → 200).

### Qué expone esto

El problema de fondo no es ngrok ni Azure CLI, sino que el proyecto trataba `apt-get update` como una precondición cuyo fallo es fatal. En una workstation real conviven repositorios de terceros que se rompen solos: un proveedor deja de publicar, rota una clave, se atrasa con un release nuevo de Ubuntu. Cualquiera de esas cosas —**ajenas al proyecto y fuera de su control**— dejaba el instalador completo inutilizable, y con un síntoma que además apunta al lugar equivocado (el mensaje culpa al repositorio, no al keyring mal escrito).

## Decisión

### 1. `apt-get update` deja de ser fatal

Se agrega `apt_update()` en `scripts/lib/apt.sh`: corre `apt-get update` y, si falla, emite un aviso visible que explica el motivo probable y **continúa**. `apt_install_packages()` lo usa con `|| true`.

Si el paquete pedido realmente no se puede resolver, el `apt-get install` posterior falla igual y ese sí corta: no se pierde la capacidad de detectar un fallo real, solo se deja de convertir un problema ajeno en un bloqueo total.

Se aplicó a las **102 ubicaciones** que hacían `sudo apt-get update` suelto en un instalador, más los `sudo apt update` de los scripts de mantenimiento, kernel y Vim.

Se descartaron dos alternativas: fallar con mejor diagnóstico (deja el instalador igual de bloqueado) y limitar el `update` a los repositorios relevantes vía `Dir::Etc::sourcelist` (más quirúrgico, pero obliga a que cada instalador conozca y pase su propia lista, y no ayuda a los instaladores de paquetes de Ubuntu).

### 2. Verificar que el proveedor publique antes de escribir su repositorio

Se agrega `apt_vendor_repo_suite_available <repo_url> <suite>`, que comprueba que el archivo `Release` exista antes de escribir nada. Si el proveedor no publica para esta versión de Ubuntu, el instalador **falla limpio y no deja un repositorio roto atrás**, que es lo que envenenaba `apt` para el resto del sistema.

Aplicado a Azure CLI (el caso que falló) y a Albert (mismo riesgo: su repositorio en OBS tiene una ruta distinta por release). Dos casos reales, así que el helper se justifica como compartido según [ADR 0032](0032-mecanismo-condicional-por-version-de-ubuntu.md).

### 3. Un comando para limpiar los repositorios ya rotos

Arreglar los instaladores evita volver a crear el problema, pero no limpia las máquinas donde ya quedó. Se agrega `./setup.sh repair-apt`:

- **Sin argumentos solo reporta**, no toca nada.
- Con `--apply`, respalda cada archivo culpable y lo **deshabilita renombrándolo** a `.disabled`, extensión que APT no lee. **Nunca borra** (AGENT.md §2, §11).
- Nunca toca `/etc/apt/sources.list`: deshabilitarlo dejaría la máquina sin repositorios base.
- Al terminar vuelve a correr `apt-get update` para confirmar si quedó limpio.

La detección se basa en las líneas `Err:` de la salida de APT, **no** en los mensajes `E:`. El prefijo `Err:` no se traduce; los mensajes largos sí (en la corrida real venían en español), y depender de ellos ataría la detección al idioma del sistema.

### 4. Doctor reporta el problema antes de que rompa algo

Se agrega `doctor_check_apt_keyrings`, una revisión **estática** de los keyrings referenciados por `signed-by=`/`Signed-By:` que detecta los dos modos de falla silenciosa: una clave en ASCII armor guardada como `.gpg`, y un `signed-by` que apunta a un archivo inexistente.

No corre `apt-get update`: eso escribiría en `/var/lib/apt/lists` y pediría `sudo`, y Doctor nunca modifica el sistema (AGENT.md §10). Tampoco usa red. Es exactamente la pista que faltaba para diagnosticar esto sin leer un log de 1000 líneas.

## Consecuencias

- Un repositorio de terceros roto ya no puede bloquear el instalador completo. Sigue siendo un problema, pero acotado a la herramienta que depende de él.
- Se instala con listas potencialmente algo desactualizadas cuando `apt-get update` falla. Es un riesgo aceptado y explícito: APT ya trabaja bien con las listas que tiene, y el aviso queda en el log.
- Los instaladores de proveedores rezagados fallan antes, con un mensaje que dice el motivo real, en vez de "instalar" y romper el sistema.
- `doctor` gana una comprobación más; sigue siendo de solo lectura.
- Queda un precedente claro: **una clave en ASCII armor siempre se desarma** si el destino es `.gpg`, y si el destino lo fija el proveedor (como el `vscodium.sources` de upstream) hay que desarmar en esa ruta exacta. El mismo bug estaba latente en VSCodium y OpenTofu, encontrados al auditar los 8 instaladores que usaban el helper sin desarmar.
