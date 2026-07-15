# ARCHITECTURE.md

# Ubuntu Workstation

## Documentación de arquitectura

**Versión:** 2.0 (Borrador)

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

Comandos preferidos:

status

install

update

repair

uninstall

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
