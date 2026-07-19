# AGENT.md

# Ubuntu Workstation

> Lineamientos del proyecto para agentes de IA y colaboradores.

---

# 1. Visión del proyecto

Este repositorio **no es solo un instalador de Ubuntu**.

Su propósito es convertirse en un gestor completo de workstation capaz de:

* aprovisionar una workstation Ubuntu nueva
* migrar instalaciones existentes
* mantener el software instalado
* reparar configuraciones rotas
* actualizar herramientas
* gestionar el ciclo de vida de la workstation de forma segura

El proyecto debe evolucionar hacia un instalador de workstation reproducible y determinista.

Instalar un computador nuevo eventualmente debería requerir solo:

```
git clone ...
./setup.sh
```

Todo lo demás debe manejarse automáticamente.

---

# 2. Filosofía de diseño

Este proyecto sigue estos principios.

## Seguridad primero

Nunca eliminar datos del usuario sin crear un respaldo antes.

Preferir preguntar antes de ejecutar acciones destructivas.

---

## Idempotencia

Ejecutar el instalador dos veces debe producir el mismo resultado.

El instalador debe converger la máquina hacia el estado deseado.

Nunca debe reinstalar software de forma continua.

---

## Cambios pequeños

Cada modificación debe ser:

* pequeña
* revisable
* reversible

Evitar refactors grandes.

---

## Modularidad

Cada funcionalidad pertenece a un módulo dedicado.

Evitar scripts monolíticos.

---

## Explícito antes que implícito

Cada decisión debe ser fácil de entender.

Evitar comportamiento oculto.

---

# 3. Objetivos

El proyecto debe eventualmente soportar:

* Aprovisionamiento de Ubuntu
* Migración de workstations existentes
* Instalación de software
* Actualizaciones de software
* Reparación de configuración
* Diagnósticos
* Backups
* Gestión de runtimes
* Gestión de herramientas
* Configuración de workstation para desarrolladores

---

# 4. No-objetivos

Este proyecto NO tiene la intención de:

* gestionar documentos del usuario
* gestionar backups personales
* sincronizar almacenamiento en la nube
* reemplazar Ansible
* reemplazar NixOS
* convertirse en una distribución Linux genérica

Se enfoca en **una sola workstation**.

---

# 5. Organización del repositorio

Estructura preferida:

```
config/
docs/
dotfiles/
scripts/

scripts/
    bootstrap/
    migrations/
    installers/
    maintenance/
    diagnostics/
    lib/

tests/

setup.sh
setup.js
```

La estructura actual puede evolucionar gradualmente.

Nunca se realiza una reescritura completa.

`CLAUDE.md`, en la raíz, es un symlink intencional a este archivo (`AGENT.md`) — no un duplicado a mantener sincronizado ni un archivo para "corregir" apuntándolo a otro lado. Existe para que Claude Code lea exactamente los mismos lineamientos que el resto del equipo.

## Documentación de referencia (`docs/`)

```
docs/
├── ARCHITECTURE.md   ⭐ Diseño técnico
├── ROADMAP.md        ⭐ Plan de evolución
├── CONTRIBUTING.md   ⭐ Guía para humanos
├── TESTING.md        ⭐ Cómo probar (incluye Docker para lo que instala/modifica de verdad)
├── TEST_CASES.md      ⭐ Casos de prueba funcionales por comando, con su condición inicial
├── adr/              ⭐ Decisiones de arquitectura (ADRs), una por archivo
├── MIGRATIONS.md      ⭐ Migraciones importantes ya ejecutadas
├── RELEASES.md        ⭐ Historial de versiones
└── TOOLS.md            ⭐ Inventario de herramientas gestionadas
```

Cada archivo se mantiene vivo a medida que se implementa, no solo al inicio del proyecto:

- **ARCHITECTURE.md** — se actualiza cuando cambia una decisión de diseño ya vigente (no cuando se propone una nueva; eso primero se registra como ADR).
- **ROADMAP.md** — se actualiza al cerrar o reordenar una etapa del plan de evolución.
- **CONTRIBUTING.md** — se actualiza cuando cambia el flujo de trabajo esperado para contribuir (convenciones de commits, cómo correr validaciones, cómo probar un instalador).
- **TESTING.md** — se actualiza cuando cambia cómo se prueba el proyecto: nuevos niveles de prueba, cambios al `Dockerfile` de `tests/docker/`, o instrucciones nuevas para validar un hito de punta a punta sin arriesgar una máquina real.
- **TEST_CASES.md** — es la fuente de verdad de los casos de prueba funcionales: se agrega una fila nueva (con su condición inicial) **antes** de crear el Dockerfile/script que la implementa, nunca después. Se actualiza el estado (`pasa`/`falla`/`pendiente`) cada vez que se corre la batería.
- **docs/adr/** — se agrega un archivo nuevo (`NNNN-slug.md`) cada vez que se toma una decisión de arquitectura no trivial. Nunca se edita una ADR aceptada para cambiar su contenido: se agrega una ADR nueva que la reemplaza y se marca el estado de la anterior como `Reemplazada por NNNN`. Ver la convención completa en `docs/adr/README.md`.
- **MIGRATIONS.md** — se actualiza cada vez que una migración versionada (`scripts/migrations/NNN_*.sh`) se da por completada en el proyecto, documentando qué cambió y para quién aplica.
- **RELEASES.md** — se actualiza en cada versión o hito entregado del proyecto.
- **TOOLS.md** — normalmente se crearía recién después de los hitos fundacionales (bootstrap, doctor, backups, migraciones); en este proyecto se creó antes, como excepción, para no perder el inventario ya relevado en el diagnóstico inicial. Se actualiza cada vez que se agrega, retira o reclasifica una herramienta gestionada (`required | optional | retired | candidate`).
- **`ACCEPTANCE_<rango>.md`** (ej. `docs/ACCEPTANCE_2_7.md`) — convención opcional para registrar la evidencia de los criterios de aceptación de un rango de hitos ya cerrado, cuando ese registro no cabe naturalmente en `TEST_CASES.md` ni en `ROADMAP.md`. No se crea para cada hito por defecto; solo cuando un cierre de rango lo amerita.

El diagnóstico inicial del repositorio (2026-07-13) ya no vive como archivo aparte: sus decisiones se registraron en `docs/adr/`, su inventario de herramientas pasó a `docs/TOOLS.md`, y sus preguntas abiertas pasaron a `docs/ROADMAP.md`.

---

# 6. Flujo de bootstrap

El orden de ejecución esperado es:

```
preflight

↓

doctor

↓

backup

↓

migrations

↓

runtime installation

↓

interactive installer

↓

validation
```

El bootstrap nunca debe asumir una máquina limpia.

---

# 7. Directorio Home

Este proyecto DEBE soportar la reutilización de un `/home` existente.

Antes de instalar cualquier cosa, detectar:

* instalaciones previas
* runtimes antiguos
* configuración previa del shell
* claves SSH existentes
* configuración de Git existente
* configuración de editor existente

Nunca sobrescribir la configuración del usuario sin respaldo.

---

# 8. Gestión de runtimes

## Mise

Mise es el único gestor de runtimes soportado.

No introducir:

* NVM
* ASDF
* Volta

salvo que se solicite explícitamente.

---

## Migración

Las instalaciones existentes de NVM deben migrarse.

La migración debe:

* detectar versiones
* inventariar paquetes globales
* respaldar la configuración
* eliminar referencias a NVM
* instalar Mise
* restaurar runtimes

La migración debe ser repetible.

---

# 9. Instaladores

Cada instalador debe exponer la misma interfaz siempre que sea posible.

El contrato objetivo (ver [ADR 0004](docs/adr/0004-idempotencia-instalado-igual-skip.md), [ADR 0012](docs/adr/0012-modelo-de-estado-enriquecido.md) y [ADR 0029](docs/adr/0029-contrato-completo-de-instalador-referencia.md)) tiene 6 verbos:

```
status

install

uninstall

reinstall

update

repair
```

`scripts/editors/install_vim.sh` es el instalador de referencia: implementa los 6 verbos y distingue `OUTDATED`/`BROKEN` en `status`, no solo `INSTALLED`/`NOT_INSTALLED`. Los instaladores todavía no migrados (Hito 11) implementan hoy solo `status/install/uninstall/reinstall` — eso es válido de forma transitoria, pero `update`/`repair` no se abandonan como objetivo.

`reinstall` es una acción avanzada, nunca el comportamiento por defecto ante una herramienta ya instalada y sana (ADR 0004): el menú interactivo la ofrece solo si la persona usuaria la pide explícitamente.

---

# 10. Doctor

El proyecto debe proveer diagnósticos.

Ejemplo:

```
setup.sh doctor
```

Doctor nunca debe modificar la máquina.

Solo reporta.

Doctor debe inspeccionar:

* versión de Ubuntu
* arquitectura
* shell
* gestores de paquetes
* Docker
* Git
* Node
* Mise
* AWS CLI
* kubectl
* Helm

y otras herramientas gestionadas.

---

# 11. Política de backups

Los backups siempre van primero.

Ubicación sugerida:

```
~/.local/state/ubuntu-workstation/backups/
```

Los backups deben tener timestamp.

Nunca sobrescribir backups.

Nunca eliminar backups silenciosamente.

---

# 12. Estándares de código (Bash)

Usar:

```
#!/usr/bin/env bash
```

Siempre habilitar:

```
set -euo pipefail
```

Preferir:

* funciones
* variables locales
* nombres descriptivos

Evitar:

* código duplicado
* scripts enormes
* condicionales anidados

Extraer lógica reutilizable hacia:

```
scripts/lib/
```

---

# 13. Logging

Todos los scripts deben producir salida consistente.

Niveles preferidos:

```
INFO
WARN
ERROR
SUCCESS
DEBUG
```

Las versiones futuras deben centralizar el logging en una librería compartida.

---

# 14. Manejo de errores

Nunca ignorar errores.

Nunca ocultar fallas.

Si un comando puede fallar:

* explicar por qué
* explicar cómo recuperarse

---

# 15. Instalación de paquetes

Orden preferido:

1. Repositorios oficiales de Ubuntu
2. Repositorio oficial del proveedor
3. Instalador oficial
4. Snap
5. Flatpak

Evitar PPAs de terceros salvo que sea necesario.

---

# 16. Seguridad

Nunca:

* imprimir secretos
* loguear tokens
* loguear contraseñas
* commitear credenciales

Nunca modificar la configuración SSH sin confirmación.

Nunca eliminar claves SSH.

---

# 17. Configuración del usuario

La configuración le pertenece al usuario.

Ejemplos:

* .zshrc
* .bashrc
* .gitconfig

Siempre respaldar antes de editar.

---

# 18. Testing

Antes de dar por completada cualquier tarea:

Ejecutar:

```
bash -n
```

Si está disponible:

```
shellcheck
```

Si un script no puede probarse, explicar por qué.

---

# 19. Commits

Los commits deben ser:

* pequeños
* enfocados
* descriptivos

Ejemplos:

```
feat: add workstation diagnostics

feat: add backup manager

feat: migrate nvm to mise

refactor: improve bootstrap

fix: detect reused home
```

Evitar commits grandes.

---

# 20. Pull Requests

Cada PR debe contener:

* propósito
* resumen
* archivos modificados
* impacto de migración
* pruebas realizadas

---

# 21. Flujo de trabajo de desarrollo

Al recibir una tarea:

1. Entender la solicitud.
2. Inspeccionar la implementación actual.
3. Reutilizar código existente siempre que sea posible.
4. Explicar el enfoque previsto.
5. Implementar.
6. Validar.
7. Resumir los cambios.
8. Sugerir un mensaje de commit.
9. Detenerse y esperar aprobación.

Nunca continuar automáticamente a la siguiente fase.

---

# 22. Roadmap

Prioridades actuales:

* Diagnósticos de workstation
* Gestor de backups
* Migración NVM → Mise
* Mejoras al bootstrap
* Instaladores idempotentes
* Soporte para Ubuntu 26
* Actualización de herramientas
* Validación automatizada

Prioridad menor:

* Reportes
* Sistema de plugins
* Perfiles
* Documentación automatizada

---

# 23. Reglas para agentes de IA

Los agentes de IA deben:

* preservar la consistencia del proyecto
* evitar reescrituras innecesarias
* preferir mejoras incrementales
* documentar decisiones de arquitectura importantes
* preguntar cuando los requisitos sean ambiguos

Los agentes de IA nunca deben:

* eliminar funcionalidades silenciosamente
* reescribir la estructura del repositorio
* introducir dependencias innecesarias
* cambiar la configuración del usuario sin respaldo
* asumir que la workstation está limpia

---

# 24. Definición de terminado

Una tarea está completa solo si:

* la implementación está terminada
* el código es legible
* los scripts pasan la validación de sintaxis
* no se introdujo lógica duplicada
* se respetaron los backups
* la documentación se actualizó cuando corresponde
* se sugirió un mensaje de commit
* el agente espera aprobación antes de continuar

---

# 25. Visión de largo plazo

El objetivo de largo plazo es transformar este repositorio en la fuente única de verdad de la workstation Ubuntu del autor.

Una instalación limpia de Ubuntu debería poder recuperarse con mínima intervención manual, manteniéndose segura, reproducible, mantenible y fácil de evolucionar durante muchos años.
