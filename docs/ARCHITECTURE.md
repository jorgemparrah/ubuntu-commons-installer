# ARCHITECTURE.md

# Ubuntu Workstation

## Documentación de arquitectura

**Versión:** 2.0 (Borrador)

**Nota de lectura:** este documento mezcla estado actual y visión a futuro. Donde no se indique explícitamente "futura"/"a largo plazo", el contenido describe el diseño ya vigente. Las secciones 14 y 25 están marcadas como objetivo/futuro y no describen la estructura de directorios ni la arquitectura de plugins reales de hoy (ver `AGENT.md` §5 para la estructura de directorios real).

---

# 1. Visión general

Ubuntu Workstation es un gestor del ciclo de vida de una workstation.

Aunque su origen fue un instalador de software para Ubuntu, el proyecto está evolucionando hacia una plataforma completa de aprovisionamiento de workstations.

El objetivo de largo plazo es hacer que una workstation Linux sea reproducible, mantenible, capaz de autodiagnosticarse y segura de evolucionar.

La workstation eventualmente debería volverse declarativa.

En vez de configurar el sistema operativo manualmente, el repositorio se convierte en la fuente de verdad.

---

# 2. Arquitectura de alto nivel

```
                 +----------------+
                 |    setup.sh    |
                 +-------+--------+
                         |
                         v
                 +----------------+
                 |   Bootstrap    |
                 +-------+--------+
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
   Preflight         Diagnostics      Backups
        |                |                |
        +----------------+----------------+
                         |
                         v
                 +----------------+
                 |   Migration    |
                 +-------+--------+
                         |
                         v
                 +----------------+
                 | Runtime Manager|
                 +-------+--------+
                         |
                         v
                 +----------------+
                 | Tool Installer |
                 +-------+--------+
                         |
                         v
                 +----------------+
                 | Configuration  |
                 +-------+--------+
                         |
                         v
                 +----------------+
                 | Validation     |
                 +----------------+
```

---

# 3. Objetivos de diseño

El proyecto debe proveer:

* reproducibilidad
* instalaciones deterministas
* migraciones seguras
* diagnósticos de la workstation
* configuración centralizada
* mantenibilidad
* evolución incremental

---

# 4. Principios centrales

## Seguridad

El instalador nunca debe destruir datos del usuario.

---

## Predictibilidad

Ejecutar el instalador varias veces debe producir la misma máquina.

---

## Idempotencia

La ejecución repetida no debe introducir cambios cuando el sistema ya coincide con el estado deseado.

---

## Modularidad

Cada responsabilidad pertenece a un módulo.

---

## Evolución incremental

Evitar reescribir el repositorio.

Mejorarlo gradualmente.

---

# 5. Flujo de ejecución

El pipeline de instalación sigue esta secuencia.

```
setup.sh

↓

Preflight

↓

Doctor

↓

Backup

↓

Migration

↓

Runtime Installation

↓

Package Installation

↓

Configuration

↓

Validation

↓

Summary
```

Cada fase tiene una única responsabilidad.

---

# 6. Capa de Bootstrap

El bootstrap prepara la máquina.

Responsabilidades incluyen:

* verificar el sistema operativo
* verificar privilegios
* verificar conexión a internet
* verificar el gestor de paquetes
* preparar el logging
* inicializar el workspace

El bootstrap nunca instala aplicaciones.

---

# 7. Capa de Diagnósticos

Los diagnósticos inspeccionan la workstation.

Ejemplos:

* versión de Ubuntu
* shell
* gestores de paquetes
* runtimes
* docker
* git
* kubectl
* aws
* helm
* mise

Los diagnósticos nunca modifican el sistema.

---

# 8. Capa de Backup

Toda operación destructiva debe estar precedida por un backup.

Los backups tienen timestamp.

Ejemplo:

```
~/.local/state/ubuntu-workstation/backups/

    2026-07-15/
```

Los backups deben ser inmutables.

**Retención:** no existe todavía un mecanismo automático de limpieza de sesiones de backup antiguas — cada corrida de `setup.sh backup` o de una migración crea una sesión nueva que nunca se borra sola (correcto según la política de seguridad: "nunca eliminar backups silenciosamente"). Hasta que se implemente un comando de limpieza (`setup.sh backup --prune` o similar, sin fecha comprometida en `docs/ROADMAP.md`), la limpieza de sesiones antiguas es responsabilidad manual de quien administra la workstation.

---

# 9. Capa de Migración

La migración es responsable de actualizar configuraciones previas de la workstation.

Ejemplos:

* NVM → Mise
* limpieza de shell
* eliminación de configuración deprecada

Las migraciones son:

* versionadas
* repetibles
* seguras

Cada migración debe registrar su finalización.

---

# 10. Capa de Runtime

La gestión de runtimes está separada de la instalación de paquetes.

Gestores de runtime soportados:

* Mise

Runtimes futuros:

* Node.js
* Python
* Java
* Go
* Rust

deberían gestionarse todos a través de Mise siempre que sea posible.

---

# 11. Capa de Paquetes

La instalación de paquetes es independiente de la gestión de runtimes.

Fuentes preferidas:

1. apt
2. repositorios de proveedor
3. instalador de proveedor
4. snap
5. flatpak

Evitar repositorios no oficiales.

---

# 12. Capa de Configuración

La configuración aplica los ajustes de la workstation.

Ejemplos:

* Git
* ZSH
* SSH
* Docker
* Cursor
* Claude Code

La configuración nunca debe sobrescribir cambios del usuario sin backup.

---

# 13. Capa de Validación

La validación asegura que la workstation esté saludable.

Los chequeos incluyen:

* ejecutables
* versiones
* PATH
* symlinks rotos
* dependencias faltantes

La validación debe reportar problemas, pero evitar corregirlos automáticamente salvo que se solicite explícitamente.

---

# 14. Módulos

Estructura de directorios futura.

```
scripts/

bootstrap/

diagnostics/

migrations/

installers/

maintenance/

runtime/

configuration/

validation/

lib/
```

Cada módulo es dueño de una sola responsabilidad.

---

# 15. Librería compartida

La funcionalidad común pertenece a:

```
scripts/lib/
```

Ejemplos:

logging

filesystem

network

shell

backup

validation

Evitar duplicar funciones auxiliares.

**Infraestructura compartida de instaladores (Hito 11, Fase 1 — 2026-07-19):**

- `scripts/lib/installer_cli.sh` — dispatcher compartido de la CLI de instaladores. Expone `installer_run_cli "$@"`, que cada instalador invoca como última línea en vez de declarar su propio bloque `main()`/`case`. Implementa el contrato de 6 verbos (`status|install|uninstall|reinstall|update|repair`, ver sección 21 y [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md)), valida con `declare -F` que las funciones obligatorias (`check_status`/`install_tool`/`uninstall_tool`) estén definidas antes de invocarlas, y da un fallback mecánico solo a `reinstall` (nunca a `update`/`repair`, que se rechazan explícitamente si el instalador no los implementa).
- `scripts/lib/apt.sh` — helpers APT compartidos (`apt_package_installed`, `apt_all_packages_installed`, `apt_install_packages`, `apt_purge_packages`). Centraliza la detección de "¿está este paquete realmente instalado?" vía `dpkg -l <paquete>` (una consulta por paquete puntual, nunca `dpkg -s` ni un `grep` sin anclar sobre la lista completa — ambos patrones dieron falsos positivos reales en este proyecto, ver `docs/TECHNICAL_REVIEW.md`).
- `scripts/system/install_cmatrix.sh` es, por ahora, el único instalador migrado a esta infraestructura (instalador piloto de la Fase 1). El resto sigue con su propio bloque `main()`/`case`, válido de forma transitoria (ver sección 21) hasta que le toque su turno en una fase posterior del Hito 11.

**Registro central de metadata de instaladores (infraestructura previa a la Fase 3 del Hito 11 — 2026-07-19, ver [ADR 0030](adr/0030-registro-central-de-metadata-de-instaladores.md)):**

- `scripts/lib/tools_registry.sh` — catálogo de metadata en Bash puro (sin YAML/JSON ni parser externo), con el mismo patrón ya usado por `UCI_RUNTIME_CATALOG` en `scripts/lib/runtime.sh` (Hito 8). Expone `tools_registry_register <id> campo=valor...`, `tools_registry_has <id>`, `tools_registry_ids` y `tools_registry_field <id> <campo>`. No fuerza un esquema de campos a nivel de biblioteca; el esquema mínimo recomendado (`name`, `category`, `manager`, `packages`, `script`, `supported_os`, `supported_arch`, `requires_gui`, `requires_manual_validation`, `migration_status`) vive en la ADR.
- `scripts/lib/tools_catalog.sh` — datos del registro, separados del mecanismo a propósito. Registra `cmatrix`, `ranger`, los 14 instaladores individuales y los 3 agrupadores creados al separar los instaladores multi-paquete (ver [ADR 0031](adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md) más abajo). Un agrupador se distingue con los campos no-esquemáticos `kind=group`/`members=<ids separados por coma>` — el mecanismo no fuerza ningún esquema (ver ADR 0030), así que esto no requirió cambiar `tools_registry.sh`.
- Puramente aditivo: ningún script existente sourcea todavía este catálogo desde `setup.sh`/`setup.js` para cambiar comportamiento en tiempo de ejecución; no cambia el comportamiento de ningún instalador ni del dispatcher/helpers compartidos.
- **Primer consumidor real** (2026-07-19): `tests/test_tools_catalog_docs_consistency.sh` recorre `tools_registry_ids()` y confirma que el script de cada entrada registrada está mencionado en `docs/TOOLS.md` — si se registra un instalador nuevo en el catálogo sin actualizar el inventario de documentación, esta prueba falla. Es la primera vez que algo *usa* el catálogo más allá de validarse contra sí mismo.

**Separación de instaladores multi-paquete en instaladores individuales (Hito 11 — 2026-07-19, ver [ADR 0031](adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md)):**

- Los 3 instaladores que antes bandeaban varios paquetes no relacionados (`install_development_tools.sh`, `install_multimedia.sh`, `install_system_utils.sh`) se separaron en 14 instaladores individuales (uno por paquete, migrados directamente al contrato completo vía `installer_cli.sh`/`apt.sh`), manteniendo los 3 archivos originales como **agrupadores delgados**: solo implementan `check_status`/`install_tool`/`uninstall_tool`, delegando en sus miembros vía `bash "$member" <verbo>` en un bucle.
- Los agrupadores no implementan `update_tool`/`repair_tool` a propósito: el dispatcher los rechaza con código 3 (mismo mecanismo que cualquier instalador que no los implemente) en vez de inventar una semántica de "actualizar/reparar el grupo completo".
- Paquetes meta sin binario propio en `PATH` (`build-essential`, `apt-transport-https`, `ubuntu-restricted-extras`) no intentan detectar `BROKEN` vía `command -v` — limitación honesta y documentada, no una detección inventada.
- `setup.js` no cambió: sigue ofreciendo las mismas 3 opciones de menú, que ahora delegan internamente en los instaladores individuales sin cambiar el resultado neto para quien las usa.

**Registro de instaladores ya migrados sin código nuevo, y siguiente grupo apt-simple (Hito 11 — 2026-07-19):**

- `vim`, `terminator` y `flameshot` se registraron en `tools_catalog.sh` sin tocar su código: ya implementaban el contrato objetivo, solo faltaba declararlos. `vim` queda con `migration_status=legacy` (implementa los 6 verbos desde el Hito 3, pero con su propia lógica de `dpkg`, nunca sourceó `installer_cli.sh`/`apt.sh` — un eje distinto de "usa la infraestructura compartida", ver ADR 0030).
- `install_ulauncher.sh` se migró al contrato completo (`installer_cli.sh`/`apt.sh`), el único de los apt-simples migrados que agrega/quita un PPA propio (`ppa:agornostal/ulauncher`, ver ADR 0027) en `install`/`uninstall` — registrado con `manager=apt-vendor-repo` para distinguirlo de un paquete de repositorio oficial simple. La prueba funcional real (`tests/docker/test_ulauncher_ppa.sh`, caso L01) sigue existiendo sin cambios; se agregó `tests/test_ulauncher_installer.sh` (I20) para cubrir el contrato de 6 verbos con mocks, sin tocar la red.

**Segundo consumidor real del catálogo** (2026-07-19): `tests/test_tools_catalog_setup_js_consistency.sh` (I21) valida el menú interactivo de `setup.js` contra el catálogo — complementa al primer consumidor (I19, que valida `docs/TOOLS.md`), esta vez sobre el código que arma el menú. Excluye a propósito los ids que son solo miembros internos de un agrupador (por ejemplo `wget` dentro de `development_tools_group`): esos nunca tuvieron ni deben tener una entrada propia en el menú, solo su agrupador la tiene.

---

# 16. Logging

Cada módulo debe usar la misma interfaz de logging.

Niveles:

INFO

WARN

ERROR

SUCCESS

DEBUG

Las versiones futuras deben centralizar el formato.

---

# 17. Manejo de errores

Los errores deben ser explícitos.

Nunca ignorar fallas de comandos.

Nunca ocultar stderr sin motivo.

Cada falla debe explicar:

* qué pasó
* por qué
* cómo recuperarse

---

# 18. Detección de estado

El instalador debe entender el estado actual de la workstation.

Ejemplos:

Instalación existente de Docker

Configuración existente de Git

Claves SSH existentes

Runtimes existentes

Configuración de shell existente

La detección de estado siempre debe preceder a la instalación.

---

# 19. Estrategia de Home del usuario

Soportar la reutilización de `/home` es una funcionalidad de primera clase.

El instalador debe detectar:

* gestores de runtime previos
* configuración previa del editor
* personalizaciones previas del shell
* repositorios existentes
* credenciales existentes

Nada debe eliminarse sin backup.

---

# 20. Perfiles

Las versiones futuras deben soportar perfiles de instalación.

Ejemplo:

```
minimal

developer

desktop

workstation

full
```

Los perfiles definen qué módulos se ejecutan.

---

# 21. Instaladores

Cada instalador debe exponer una interfaz consistente.

Contrato objetivo (6 verbos, ver [ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md), [ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) y [ADR 0029](adr/0029-contrato-completo-de-instalador-referencia.md)):

status

install

uninstall

reinstall

update

repair

`scripts/editors/install_vim.sh` es el instalador de referencia que ya implementa los 6 verbos, incluyendo que `status` distinga `OUTDATED`/`BROKEN` de `INSTALLED`/`NOT_INSTALLED`. El Hito 11 migra el resto de los instaladores hacia este mismo contrato; mientras tanto, implementar solo `status/install/uninstall/reinstall` es válido de forma transitoria.

`reinstall` es una acción avanzada explícita, nunca el comportamiento por defecto ante una herramienta instalada y sana.

Status debe ser liviano.

---

# 22. Migraciones

Cada migración debe tener:

identificador único

descripción

prerequisitos

estrategia de rollback

marca de finalización

El historial de migraciones debe mantenerse disponible.

---

# 23. Testing

Cada módulo debe soportar validación.

Ejemplos:

bash -n

shellcheck

verificación manual

dry-run

Ningún instalador debería requerir ejecución real para validar su sintaxis.

---

# 24. Seguridad

Nunca loguear:

contraseñas

tokens

claves privadas

credenciales

Nunca modificar la configuración SSH sin confirmación.

---

# 25. Futura arquitectura de plugins

A largo plazo, cada aplicación debería convertirse en un plugin.

Ejemplo:

```
Docker

metadata.yaml

install.sh

uninstall.sh

reinstall.sh

update.sh

status.sh

repair.sh
```

El instalador descubre dinámicamente los plugins disponibles.

No debería requerirse un registro central.

---

# 26. Roadmap

Prioridades actuales:

1. Bootstrap

2. Diagnósticos

3. Gestor de Backups

4. Migración NVM

5. Runtime Mise

6. Ubuntu 26

7. Instaladores idempotentes

8. Validación

9. Perfiles

10. Plugins

---

# 27. Definición de éxito

Una instalación de workstation exitosa debería:

instalar todo el software requerido

reutilizar un `/home` existente

preservar la configuración del usuario

detectar instalaciones previas

requerir mínima intervención manual

mantenerse reproducible

mantenerse mantenible

mantenerse fácil de evolucionar

---

# 28. Visión de largo plazo

Ubuntu Workstation se convierte en la definición autoritativa de la workstation.

El sistema operativo ya no se configura manualmente.

En cambio, el repositorio describe el estado deseado de la workstation y provee las herramientas necesarias para converger cualquier instalación de Ubuntu compatible hacia ese estado, de forma segura, incremental y reproducible.
