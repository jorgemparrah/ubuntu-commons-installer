# 0031. Separar los instaladores multi-paquete en instaladores individuales, con un agrupador delgado

Fecha: 2026-07-19
Estado: Aceptada

## Contexto

Tres instaladores (`scripts/system/install_development_tools.sh`, `scripts/system/install_multimedia.sh`, `scripts/system/install_system_utils.sh`) instalan varios paquetes de APT no relacionados entre sí como si fueran una sola herramienta (hallazgo M6 de `docs/TECHNICAL_REVIEW.md`). Esto trae dos problemas reales, no solo estéticos:

- **`status` es todo-o-nada.** Si de 7 paquetes de "Development Tools" falta uno solo, `status` reporta `NOT_INSTALLED` sin decir cuál falta.
- **El contrato de 6 verbos ([ADR 0029](0029-contrato-completo-de-instalador-referencia.md)) no tiene sentido a nivel de bandeja.** `update`/`repair` de un paquete individual dentro del bandeo no se pueden expresar sin ambigüedad: ¿qué significa "reparar Development Tools" si solo `git` está roto?

Antes de que el registro central de metadata (`scripts/lib/tools_registry.sh`/`tools_catalog.sh`, ver [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md)) creciera registrando estos 3 bandeos como si fueran una unidad, correspondía resolver esta ambigüedad de raíz: el catálogo modela "una herramienta = un `script` responsable", y forzar un bandeo de 7 paquetes en esa forma habría sido una ficción.

## Decisión

Cada paquete de los 3 instaladores se separa en su propio instalador individual, migrado directamente al contrato completo (`scripts/lib/installer_cli.sh` + `scripts/lib/apt.sh`, mismo patrón que `install_ranger.sh`):

- **Development Tools** → `install_wget.sh`, `install_curl.sh`, `install_git.sh`, `install_build_essential.sh`, `install_software_properties_common.sh`, `install_apt_transport_https.sh`, `install_gnupg2.sh`.
- **Multimedia** → `install_cheese.sh`, `install_v4l_utils.sh`, `install_ubuntu_restricted_extras.sh`, `install_vlc.sh`.
- **System Utilities** → `install_meld.sh`, `install_baobab.sh`, `install_gparted.sh`.

Los 3 archivos originales **no se eliminan**: pasan a ser **agrupadores delgados** que invocan a los instaladores individuales de su grupo en secuencia, para no romper `setup.js` (que sigue listando "Development Tools"/"Multimedia Tools"/"System Utilities" como una sola opción de menú) ni el hábito de instalar un paquete de herramientas de una sola vez.

Un agrupador implementa únicamente `check_status`/`install_tool`/`uninstall_tool` (recorriendo sus miembros) y se apoya en `scripts/lib/installer_cli.sh` igual que cualquier instalador: `reinstall` usa el fallback mecánico del dispatcher (desinstalar todo + instalar todo, razonable para un bandeo sin estado propio), y `update`/`repair` **no se implementan a propósito** — el dispatcher los rechaza explícitamente (código 3, mismo mecanismo que ya usa cualquier instalador que no los implementa), en vez de inventar una semántica ambigua de "actualizar/reparar el grupo". El mensaje de rechazo del dispatcher ya señala qué verbos sí existen; queda documentado en cada agrupador que `update`/`repair` deben pedirse contra el script individual del paquete afectado.

Para paquetes sin un binario propio en `PATH` (paquetes meta/de transición: `build-essential`, `apt-transport-https`, `ubuntu-restricted-extras`), `check_status` no intenta detectar `BROKEN` vía `command -v` — solo distingue `NOT_INSTALLED`/`INSTALLED`/`OUTDATED` vía `apt_package_installed`/`apt list --upgradable`. Es una limitación honesta y documentada en el propio script, no una detección inventada.

## Consecuencias

- `docs/TOOLS.md` y `setup.js` se actualizan: los 3 agrupadores quedan documentados como tales, y se agrega una fila/entrada por cada instalador individual nuevo.
- `scripts/lib/tools_catalog.sh` puede registrar cada instalador individual como una herramienta real (`packages` de un solo elemento, consistente con el resto del catálogo), y registrar los 3 agrupadores con un campo adicional (`kind=group`, `members=<ids separados por coma>`) para distinguirlos de una herramienta individual — el mecanismo de `tools_registry.sh` ya soporta campos no forzados por esquema (ver ADR 0030), así que esto no requiere cambiar la biblioteca.
- Cada instalador individual nuevo sube directamente al contrato completo de 6 verbos y al modo estricto de Bash ([ADR 0008](0008-bash-estricto-en-scripts-nuevos.md)), sin pasar por un estado intermedio de 4 verbos — no tiene sentido migrar código nuevo a un contrato que ya se sabe insuficiente.
- No se elimina compatibilidad: cualquier flujo que hoy invoque `install_development_tools.sh install` (por ejemplo, `setup.js`) sigue funcionando igual, con el mismo resultado neto (todos los paquetes del grupo instalados).
- Relacionado: [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato de 6 verbos), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md) (registro central de metadata).
