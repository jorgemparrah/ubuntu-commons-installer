# Ubuntu Workstation

> Nombre interno del proyecto: **Ubuntu Workstation**. El repositorio en GitHub mantiene su nombre histórico (`ubuntu-commons-installer`) — ver [ADR 0015](docs/adr/0015-idioma-de-la-documentacion.md) y [`AGENT.md`](AGENT.md), symlinkeado como `CLAUDE.md` en la raíz a propósito.

Gestor del ciclo de vida de una workstation Ubuntu (24.04 LTS / 26.04): aprovisiona herramientas, diagnostica el estado de la máquina, respalda configuración antes de tocarla, y migra estado histórico (por ejemplo, NVM) de forma segura e idempotente.

## Inicio rápido

```bash
git clone <este repositorio>
cd ubuntu-commons-installer
./setup.sh                          # flujo interactivo (checklist de herramientas)
```

Otros comandos frecuentes:

```bash
./setup.sh doctor --verbose          # diagnóstico de solo lectura, nunca modifica nada
./setup.sh list                       # catálogo de herramientas gestionadas (id/categoría/perfiles)
./setup.sh info                        # lo mismo, agregando el estado real de instalación
./setup.sh install --profile developer  # instala sin interacción todo lo del perfil elegido
./setup.sh backup --dry-run              # qué respaldaría, sin crear nada
./setup.sh migrate --dry-run              # qué haría cada migración pendiente, sin aplicar nada
./setup.sh help                            # ayuda completa
```

Una herramienta ya instalada **nunca se reinstala por defecto** (`INSTALLED → skip`, `OUTDATED → update`, `BROKEN → repair`) — ver [ADR 0004](docs/adr/0004-idempotencia-instalado-igual-skip.md) y [ADR 0012](docs/adr/0012-modelo-de-estado-enriquecido.md). Perfiles disponibles y demás detalles de uso: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Seguridad

- **Nunca elimina datos del usuario sin respaldo previo.** Los backups quedan con timestamp en `~/.local/state/ubuntu-workstation/backups/`, nunca se sobrescriben ni se borran silenciosamente ([ADR 0005](docs/adr/0005-gestor-de-backups-centralizado.md)).
- **`doctor` nunca modifica el sistema**, solo reporta.
- **`/home` reutilizado se respeta**: runtimes, claves SSH y configuración de shell existentes se detectan y se preservan/respaldan, nunca se sobrescriben a ciegas (`AGENT.md` sección 7).
- La migración NVM → Mise limpia únicamente las líneas exactas que el propio proyecto agregó, nunca un patrón amplio, y mueve `~/.nvm` a un backup en vez de borrarlo ([ADR 0003](docs/adr/0003-migracion-nvm-sin-borrado-directo.md)).
- Requiere permisos de administrador (`sudo`) para instalar paquetes; nunca imprime ni loguea secretos/tokens/contraseñas (`AGENT.md` sección 16).

## Documentación de referencia

- [`AGENT.md`](AGENT.md) — visión, filosofía y lineamientos completos del proyecto
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — diseño técnico
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — plan de evolución y estado de cada hito
- [`docs/TOOLS.md`](docs/TOOLS.md) — inventario de herramientas gestionadas
- [`docs/TESTING.md`](docs/TESTING.md) / [`docs/TEST_CASES.md`](docs/TEST_CASES.md) — cómo se prueba el proyecto (unitario, Docker, y validación manual en VM real)
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — guía práctica para contribuir
- [`docs/MIGRATIONS.md`](docs/MIGRATIONS.md) — migraciones ya ejecutadas
- [`docs/RELEASES.md`](docs/RELEASES.md) — historial de hitos entregados
- [`docs/adr/`](docs/adr/README.md) — decisiones de arquitectura (ADRs), una por archivo

## Requisitos

- Ubuntu 24.04 LTS o 26.04
- Conexión a internet
- Permisos de administrador (`sudo`)
