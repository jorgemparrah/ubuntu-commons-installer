# 0025. Mise se instala con su script oficial (`https://mise.run`), verificando después

Fecha: 2026-07-16
Estado: Aceptada

## Contexto

[ADR 0002](0002-mise-como-unico-gestor-runtime.md) estableció que Mise es el único gestor de runtimes soportado, y varios componentes ya instalan Mise en la práctica: `ensure_node_via_mise()` en `setup.sh` (bootstrap interactivo), y `scripts/migrations/001_nvm_to_mise.sh` (migración NVM→Mise). Ninguna ADR anterior registraba explícitamente **cómo** se instala Mise, sus riesgos, ni qué verificación se hace después — la auditoría de estabilización de los Hitos 2-7 encontró este vacío y pidió cerrarlo con una ADR dedicada antes de cerrar la fase formalmente.

El mecanismo actual, usado en ambos lugares:

```bash
curl -fsSL https://mise.run | sh
```

seguido de una verificación de que el binario quedó en `${home}/.local/bin/mise`, es ejecutable, y resuelve un `node` funcional (`mise which node`).

## Decisión

Se mantiene el instalador oficial de Mise (`curl -fsSL https://mise.run | sh`) como único método soportado para instalar Mise en este proyecto. No se introduce un mecanismo alternativo (paquete `.deb`, binario descargado y verificado por checksum propio, gestor de paquetes del sistema, etc.) sin una ADR nueva que reemplace esta.

**Verificaciones posteriores obligatorias**, ya implementadas en `ensure_node_via_mise()` y en `runtime_ensure_mise()`/`migration_apply()`:

1. Comprobar el código de salida de `curl | sh` (bajo `set -Eeuo pipefail`, un fallo de `curl` o de `sh` aborta el flujo).
2. Verificar que el binario existe y es ejecutable en la ruta esperada (`${home}/.local/bin/mise`).
3. Registrar la versión instalada (`mise --version`) en el log.
4. Confirmar que Mise resuelve un ejecutable real (`mise which node`) antes de continuar.

**Riesgos conocidos y aceptados:**

- Es una cadena de suministro de terceros: se confía en que `mise.run` sirve el script correcto y en que GitHub/jdx (autor de Mise) no está comprometido. No se fija un hash/checksum del script descargado hoy.
- `curl | sh` no permite inspeccionar el script antes de ejecutarlo. Es el mismo patrón que ya usa el proyecto para instalar NVM (histórico) y que usan prácticamente todos los gestores de runtime del ecosistema (nvm, rustup, etc.) — se acepta como riesgo estándar de esta clase de herramientas, no específico de este proyecto.
- Una descarga incompleta (conexión cortada a mitad de la transferencia) podría dejar un script parcial; `sh` normalmente falla al interpretar un script truncado, y el chequeo de código de salida (punto 1) debería capturarlo. No hay una verificación de integridad adicional (tamaño esperado, checksum) más allá de eso.
- No se registra ni se imprime ningún secreto ni información sensible durante la instalación (no aplica: el instalador de Mise no requiere credenciales).

**Alternativas consideradas y descartadas por ahora:**

- Empaquetar/vendorizar el instalador de Mise dentro del repositorio: agrega mantenimiento (mantenerlo actualizado) sin reducir significativamente el riesgo de cadena de suministro (seguiría confiando en el binario que ese script descarga).
- Verificar un checksum fijo del script de instalación: el script de `mise.run` cambia con las versiones de Mise: fijar un hash requeriría actualizarlo en cada release de Mise, con alto costo de mantenimiento para un beneficio de seguridad limitado (el binario final igual se descarga sin checksum fijado por este proyecto).
- Instalar Mise vía APT/PPA de terceros: no hay un repositorio APT oficial mantenido por el proyecto Mise al momento de esta ADR; introduciría una fuente de paquetes no oficial, en contra de la política de fuentes del proyecto ([ADR 0010](0010-orden-de-fuentes-de-paquetes.md)).

## Condiciones bajo las cuales debe revisarse esta ADR

- Si el proyecto Mise publica y mantiene un repositorio APT oficial (cambiaría el orden de preferencia de [ADR 0010](0010-orden-de-fuentes-de-paquetes.md): repositorio oficial antes que un instalador de script).
- Si se detecta o reporta un incidente de seguridad relacionado con `mise.run` o con el proceso de build de Mise.
- Si el proyecto decide fijar versiones exactas de Mise (hoy se instala "la última disponible" implícitamente vía el script oficial) — eso cambiaría el mecanismo de instalación, no solo esta ADR.

## Consecuencias

- Ningún cambio de comportamiento respecto a lo ya implementado en `setup.sh` y `scripts/migrations/001_nvm_to_mise.sh`: esta ADR documenta la decisión ya tomada de forma implícita, no introduce una implementación distinta.
- Cualquier cambio futuro al mecanismo de instalación de Mise requiere una ADR nueva que reemplace esta, no un cambio silencioso de código.
