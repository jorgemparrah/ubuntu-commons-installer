# ROADMAP.md

# Ubuntu Workstation

## Roadmap Técnico

**Estado:** Activo

---

# Propósito

Este roadmap define la evolución de largo plazo de Ubuntu Workstation.

Sirve como backlog técnico tanto para colaboradores humanos como para agentes de IA.

El roadmap prioriza intencionalmente la **evolución incremental** por sobre las reescrituras grandes.

Cada fase completada debe dejar el repositorio en un estado funcional.

---

# Flujo de trabajo

Cada fase sigue el mismo ciclo de vida:

```text
Ready
↓

In Progress
↓

Review

↓

Done
```

Si está bloqueada:

```text
Blocked
```

Si se abandona:

```text
Cancelled
```

---

# Reglas de desarrollo

Cada fase debe:

* preservar la retrocompatibilidad siempre que sea posible
* evitar refactors innecesarios
* producir commits pequeños
* incluir actualizaciones de documentación cuando corresponda
* pasar la validación antes de darse por completada

Ninguna fase debe modificar datos del usuario silenciosamente.

---

# Hito 1

## Evaluación del repositorio

**Prioridad**

Crítica

**Estado**

Done

### Objetivo

Entender el estado actual del repositorio antes de introducir cambios de arquitectura.

### Tareas

* Inventariar todos los instaladores
* Inventariar scripts auxiliares
* Detectar código duplicado
* Detectar herramientas obsoletas
* Detectar métodos de instalación deprecados
* Identificar dependencias de runtime
* Revisar la estructura del repositorio
* Revisar la documentación
* Identificar deuda técnica

### Entregables

* Evaluación inicial del repositorio (2026-07-13). Su contenido se distribuyó luego en `docs/adr/` (decisiones), `docs/TOOLS.md` (inventario de herramientas) y este roadmap (preguntas abiertas).

### Criterios de aceptación

* [x] Ningún código modificado
* [x] Inventario completo del repositorio generado
* [x] Riesgos identificados
* [x] Oportunidades de mejora documentadas

---

# Hito 2

## Bootstrap

**Prioridad**

Crítica

**Estado**

Ready

Depende de:

* Evaluación del repositorio

### Objetivo

Crear un proceso de bootstrap robusto e independiente de Node.js.

### Tareas

* Chequeos de preflight
* Inicialización de logging
* Inicialización del workspace
* Verificación del sistema operativo
* Verificación de privilegios
* Verificación de conexión a internet

### Entregables

Módulo de bootstrap.

### Criterios de aceptación

El bootstrap se completa exitosamente sin modificar la configuración del usuario.

### Decisión relacionada

[ADR 0001](adr/0001-bootstrap-bash-sin-node.md) — `setup.sh` como router de comandos Bash, independiente de Node.

---

# Hito 3

## Idempotencia del menú y modelo de estado enriquecido

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

* Bootstrap

### Objetivo

Corregir el hallazgo crítico de idempotencia (una herramienta instalada se reinstala por defecto) antes de avanzar con Doctor, Backups y Migraciones. Es un cambio acotado, principalmente en `setup.js`/la lógica de mapeo estado→acción, que no depende de tener el bootstrap Bash completo salvo por el router de comandos ya creado en el Hito 2.

### Tareas

* Adoptar el contrato de estado enriquecido (`INSTALLED`, `NOT_INSTALLED`, `OUTDATED`, `BROKEN`, `UNSUPPORTED`, `UNKNOWN`) en el resultado de `status`, aunque los instaladores lo adopten de forma incremental
* Cambiar el mapeo por defecto del menú interactivo: `NOT_INSTALLED → install`, `INSTALLED → skip`, `OUTDATED → update`, `BROKEN → repair`
* Dejar `reinstall` como acción avanzada explícita, nunca por defecto

### Entregables

Menú interactivo que ya no reinstala automáticamente una herramienta sana.

### Criterios de aceptación

* Seleccionar una herramienta ya instalada y sana no dispara `uninstall`/`install`
* `reinstall` sigue disponible como acción explícita
* Al menos un instalador de referencia expone el contrato de estado enriquecido de punta a punta

### Decisiones relacionadas

[ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md) — una herramienta instalada se omite por defecto.
[ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) — modelo de estado enriquecido para `status`.

---

# Hito 4

## Doctor

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

* Idempotencia del menú y modelo de estado enriquecido

### Objetivo

Inspeccionar el estado de la workstation.

### Tareas

Detectar:

* versión de Ubuntu
* shell
* Git
* Docker
* Node
* Mise
* AWS CLI
* kubectl
* Helm
* SSH
* runtimes existentes

### Entregables

`setup.sh doctor`

### Criterios de aceptación

Doctor nunca modifica el sistema.

Produce un reporte legible.

Soporta modo verbose.

Usa el contrato de estado enriquecido del Hito 3.

---

# Hito 5

## Gestor de Backups

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

* Doctor

### Objetivo

Crear un sistema de backups centralizado.

### Tareas

Respaldar:

* configuración del shell
* configuración de runtime
* carpetas migradas
* archivos modificados

### Entregables

Módulo de backup.

### Criterios de aceptación

Backups con timestamp.

Sin sobrescritura.

Sin comportamiento destructivo.

### Decisión relacionada

[ADR 0005](adr/0005-gestor-de-backups-centralizado.md).

---

# Hito 6

## Framework de migraciones

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

* Gestor de Backups

### Objetivo

Proveer un sistema de migraciones reutilizable.

### Tareas

* registro de migraciones
* marcas de finalización
* estrategia de rollback
* ejecución de migraciones

### Entregables

Framework de migraciones.

### Criterios de aceptación

Ejecución repetible.

Ejecución segura.

Historial de migraciones registrado.

### Decisión relacionada

[ADR 0006](adr/0006-framework-de-migraciones-versionado.md).

---

# Hito 7

## Migración NVM → Mise

**Prioridad**

Crítica

**Estado**

Blocked

Depende de:

Framework de migraciones

### Objetivo

Reemplazar NVM por Mise.

### Tareas

Detectar:

* versiones de Node instaladas
* paquetes globales

Respaldar:

* .nvm
* configuración del shell

Instalar:

* Mise

Restaurar:

* runtimes de Node

Validar:

* PATH
* ejecutables

### Criterios de aceptación

Node ya no depende de NVM.

La migración es repetible.

### Decisiones relacionadas

[ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md), [ADR 0003](adr/0003-migracion-nvm-sin-borrado-directo.md), [ADR 0007](adr/0007-bloques-gestionados-en-archivos-de-shell.md).

---

# Hito 8

## Gestor de runtimes

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Migración NVM

### Objetivo

Centralizar la gestión de runtimes.

### Tareas

Soportar:

* Node
* Python
* Java
* Go
* Rust

a través de Mise siempre que sea posible.

### Criterios de aceptación

Todos los runtimes soportados se gestionan de forma consistente.

---

# Hito 9

## Compatibilidad con Ubuntu 26

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Gestor de runtimes

### Objetivo

Revisar cada instalador para Ubuntu 26.

### Tareas

Revisar:

* repositorios
* nombres de paquetes
* comandos deprecados
* métodos de instalación

### Criterios de aceptación

Todos los instaladores soportados funcionan correctamente en Ubuntu 26.

---

# Hito 10

## Gate de calidad automatizado (CI)

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Compatibilidad con Ubuntu 26

### Objetivo

Agregar un workflow de CI no destructivo antes de modernizar instaladores en volumen.

### Tareas

* Validar `bash -n` en todos los scripts de shell
* Validar con ShellCheck
* Lint del código Node.js
* Ejecutar tests si existen

### Entregables

Workflow de CI.

### Criterios de aceptación

El CI no ejecuta instaladores reales contra un sistema; solo valida sintaxis y estilo.

### Decisión relacionada

[ADR 0014](adr/0014-gate-de-calidad-ci.md).

---

# Hito 11

## Modernización de instaladores

**Prioridad**

Alta

**Estado**

Blocked

Depende de:

Gate de calidad automatizado (CI)

### Objetivo

Estandarizar las interfaces de los instaladores.

Cada instalador debe exponer:

* status
* install
* update
* repair
* uninstall

Separar conceptualmente las acciones de mantenimiento de sistema (kernel, actualizaciones) de los instaladores de aplicaciones.

### Criterios de aceptación

Comportamiento consistente entre instaladores.

### Decisión relacionada

[ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md) — separar mantenimiento de sistema de instaladores de aplicaciones.

---

# Hito 12

## Framework de validación

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Modernización de instaladores

### Objetivo

Verificar la integridad de la workstation.

### Tareas

Validar:

* PATH
* ejecutables
* dependencias
* symlinks
* versiones de runtime

### Entregables

Módulo de validación.

---

# Hito 13

## Perfiles

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Framework de validación

### Objetivo

Soportar perfiles de instalación.

Ejemplos:

* minimal
* desktop
* developer
* workstation
* full

---

# Hito 14

## Arquitectura de plugins

**Prioridad**

Media

**Estado**

Blocked

Depende de:

Perfiles

### Objetivo

Convertir los instaladores en plugins descubribles.

Ejemplo:

```
docker/

metadata.yaml

install.sh

update.sh

repair.sh

status.sh
```

### Decisión relacionada

[ADR 0009](adr/0009-postergar-arquitectura-de-plugins.md) — postergada hasta este punto del roadmap.

---

# Hito 15

## Documentación

**Prioridad**

Continua

### Tareas

Mantener la documentación sincronizada.

Una vez aceptada la nueva arquitectura, acortar el `README.md` raíz a propósito, inicio rápido, seguridad y enlaces a `docs/`; mover los detalles de implementación a `docs/`; asegurar que los ejemplos no prometan idempotencia hasta que esté implementada.

Documentos requeridos:

* AGENT.md
* ARCHITECTURE.md
* ROADMAP.md
* CONTRIBUTING.md
* TOOLS.md
* docs/adr/ (decisiones de arquitectura, una por archivo)
* MIGRATIONS.md
* RELEASES.md

---

# Preguntas resueltas por el dueño del proyecto (2026-07-15)

Migradas desde la evaluación inicial del repositorio (2026-07-13) y resueltas en una revisión de inventario de herramientas. Las decisiones de arquitectura resultantes están en `docs/adr/` (0016–0021) y el inventario actualizado en `docs/TOOLS.md`.

1. **Versiones de Node vía Mise:** última estable + últimas 2 LTS. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
2. **Archivo de versión por proyecto:** se soportan `.nvmrc` y `.node-version`, además de `mise.toml`. Ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md).
3. **Yarn/pnpm:** los instala Mise directamente, no Corepack. Ver [ADR 0017](adr/0017-mise-instala-yarn-pnpm-directo.md).
4. **Terminal:** se mantiene Terminator.
5. **Oh My Zsh y Powerlevel10k:** se mantienen ambos; al reutilizar `/home` se respalda/reutiliza la personalización existente en vez de sobrescribirla. Ver [ADR 0021](adr/0021-reutilizar-personalizacion-shell-en-home.md).
6. **Postman, Insomnia, GitKraken:** se mantienen los tres.
7. **Bruno:** no se agrega; se mantienen Postman e Insomnia.
8. **MongoDB Compass:** se mantiene.
9. **kubectl:** se gestiona vía Mise, no vía Snap. Ver [ADR 0018](adr/0018-kubectl-via-mise.md).
10. **Obligatorias vs. opcionales:** el dueño del proyecto prefiere revisar la clasificación `required | optional | retired | candidate` caso por caso en una sesión posterior — sigue pendiente, ver `docs/TOOLS.md`.
11. **Soporte de Ubuntu:** solo 24.04 y 26.04.
12. **NVIDIA/CUDA:** fuera de alcance del repositorio; se documentan como fase manual separada. Ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md).
13. **Ajustes de escritorio y atajos de teclado:** fuera de alcance, salvo el atajo de `PrintScreen` para lanzar Flameshot. Ver [ADR 0019](adr/0019-flameshot-atajo-printscreen.md).
14. **Symlinks `.agents`, `.claude`, `.cursor`:** no se gestionan por ahora. Ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md).

También se confirmó, fuera de la lista original: mantener ULauncher (salvo alternativa mejor), cmatrix y ranger (salvo alternativa más amigable para este último).

---

# Deuda técnica

Los siguientes puntos requieren revisión periódica:

* funciones de shell duplicadas
* repositorios obsoletos
* instaladores deprecados
* gestores de paquetes deprecados
* dependencias innecesarias

---

# Ideas futuras

Estas quedan intencionalmente fuera de alcance por ahora.

* Dashboard de instalación
* Reportes HTML
* Reportes JSON
* TUI interactiva
* Marketplace de plugins
* Actualizaciones automáticas
* Sincronización entre workstations
* Inventario de máquinas
* Aprovisionamiento remoto
* Múltiples perfiles de workstation

---

# Criterios de éxito

El proyecto se considerará maduro cuando:

* Una instalación limpia de Ubuntu pueda aprovisionarse con mínima intervención manual.
* Los directorios `/home` existentes puedan reutilizarse de forma segura.
* Las instalaciones sean deterministas e idempotentes.
* Todas las herramientas gestionadas puedan diagnosticarse, actualizarse, repararse y eliminarse de forma consistente.
* El repositorio sirva como fuente única de verdad para la configuración de la workstation.
