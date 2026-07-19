# TOOLS.md

# Inventario de herramientas gestionadas

**Estado:** Clasificación de uso confirmada con el dueño del proyecto el 2026-07-15. La columna `required | optional | retired | candidate` sigue pendiente para varias herramientas — el dueño prefiere confirmarla caso por caso más adelante en vez de asumirla ahora.

## System

| Script | Propósito | Decisión |
|---|---|---|
| `install_system_update.sh` | Actualizaciones del sistema | Mantener; `status` corregido en el Hito 9 para reportar un diagnóstico real (paquetes con actualización pendiente), no un stub fijo en `INSTALLED` (ver [ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md)) |
| `install_kernel.sh` | Kernel y headers | Alto riesgo; revisar versión de Ubuntu y comportamiento de reinicio |
| `install_development_tools.sh` | Paquetes base de desarrollo | Mantener; convertir la lista de paquetes a configuración más adelante |
| `install_system_utils.sh` | Utilidades del sistema | Mantener; inventariar paquetes explícitamente |
| `install_multimedia.sh` | Paquetes multimedia | Mantener; verificar nombres de paquetes y códecs |
| `install_terminator.sh` | Terminal Terminator | **Mantener** — confirmado, sigue siendo la terminal preferida |
| `install_oh_my_zsh.sh` | Oh My Zsh | **Mantener** — corregido en el Hito 9: antes solo instalaba `zsh`, nunca clonaba el framework (hallazgo de `docs/UBUNTU_COMPATIBILITY.md`); no toca `.zshrc`, respeta la personalización existente al reutilizar `/home` (ver [ADR 0021](adr/0021-reutilizar-personalizacion-shell-en-home.md)) |
| `install_powerlevel10k.sh` | Powerlevel10k | **Mantener** — corregido en el Hito 9: antes solo instalaba `zsh`, nunca clonaba el tema; misma lógica de no tocar `.zshrc`/reutilizar personalización que Oh My Zsh (ver [ADR 0021](adr/0021-reutilizar-personalizacion-shell-en-home.md)) |
| `install_ranger.sh` | Gestor de archivos de terminal | Mantener, salvo que surja una alternativa más amigable |
| `install_cmatrix.sh` | Utilidad visual de terminal | **Mantener** — confirmado |
| `install_gimp.sh` | GIMP vía Snap | Revisar fuente deseada |
| `install_obs_studio.sh` | OBS Studio vía Snap | Mantener; verificar fuente deseada |

## Editors

| Script | Propósito | Decisión |
|---|---|---|
| `install_vscode.sh` | Visual Studio Code | Mantener |
| `install_cursor.sh` | Cursor | Mantener — corregido en el Hito 9: pasó de AppImage (x86_64 hardcodeado, sin checksum) a su repo APT oficial (`downloads.cursor.com/aptrepo`, `signed-by`, amd64+arm64), ver [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md) |
| `install_vim.sh` | Vim | Mantener como editor base; instalador de referencia del contrato de estado enriquecido (`status` soporta `INSTALLED\|NOT_INSTALLED\|OUTDATED\|BROKEN\|UNSUPPORTED`, y agrega las acciones `update`/`repair`). Ver [ADR 0012](adr/0012-modelo-de-estado-enriquecido.md) |

## Development

| Script | Propósito | Decisión |
|---|---|---|
| `install_docker.sh` | Docker Engine | Mantener; alta prioridad de modernización |
| `install_nodejs.sh` | Node.js vía NVM | Reemplazar por módulo de runtime Mise y migración (ver [ADR 0001](adr/0001-bootstrap-bash-sin-node.md), [ADR 0002](adr/0002-mise-como-unico-gestor-runtime.md)). Política de versiones: última estable + últimas 2 LTS; se respetan `.nvmrc`/`.node-version`/`mise.toml` a nivel de proyecto (ver [ADR 0016](adr/0016-politica-de-versiones-node-mise.md)) |
| `install_yarn.sh` | Yarn | **Vía Mise** — implementado en el Hito 9 usando `scripts/lib/runtime.sh` (ver [ADR 0017](adr/0017-mise-instala-yarn-pnpm-directo.md) y [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md)); antes instalaba el paquete `yarn` de apt, que en Ubuntu es en realidad `cmdtest` (bug preexistente detectado en `docs/UBUNTU_COMPATIBILITY.md`) |
| `install_postman.sh` | Postman | **Mantener** — confirmado, junto con Insomnia |
| `install_dbeaver.sh` | DBeaver | Mantener |
| `install_gitkraken.sh` | GitKraken | **Mantener** — confirmado |
| `install_insomnia.sh` | Insomnia | **Mantener** — confirmado, junto con Postman |
| `install_mongodb_compass.sh` | MongoDB Compass | **Mantener** — confirmado; manejo de errores de descarga corregido en el Hito 9 (mensaje claro + limpieza si falla, ver `docs/UBUNTU_COMPATIBILITY.md`); versión fija en la URL sigue como riesgo aceptado (documentado en el propio script) |
| `install_kubectl.sh` | kubectl | **Vía Mise** (ver [ADR 0018](adr/0018-kubectl-via-mise.md)) — implementado en el Hito 9 usando `scripts/lib/runtime.sh` (Hito 8); antes se recomendaba mantener Snap, y el script siguió en Snap hasta esta corrección |

## Productivity

| Script | Propósito | Decisión |
|---|---|---|
| `install_ulauncher.sh` | ULauncher | Mantener, salvo que surja una alternativa mejor — corregido en el Hito 9: nunca agregaba el PPA oficial (`ppa:agornostal/ulauncher`) que necesita, así que `apt install` fallaba siempre (hallazgo de `docs/UBUNTU_COMPATIBILITY.md`); fuente justificada como "comunitario de confianza" bajo [ADR 0027](adr/0027-orden-de-fuentes-por-categoria.md) |
| `install_chrome.sh` | Google Chrome | Mantener |
| `install_spotify.sh` | Spotify | Mantener si se usa |
| `install_zoom.sh` | Zoom | Mantener si se usa |
| `install_flameshot.sh` | Flameshot y configuración de atajos | **Mantener** — confirmado como la herramienta de captura; falta que el instalador configure el atajo `PrintScreen` para que lance Flameshot en vez del capturador nativo de GNOME (ver [ADR 0019](adr/0019-flameshot-atajo-printscreen.md)) |

## Maintenance

| Script | Propósito | Decisión |
|---|---|---|
| `install_final_update.sh` | Actualización final y limpieza | Mantener, pero renombrar conceptualmente como una acción de mantenimiento; `status` corregido en el Hito 9 para considerar actualizaciones y paquetes huérfanos pendientes (ver [ADR 0013](adr/0013-separar-mantenimiento-de-instaladores.md)) |

## Fuera de alcance (confirmado)

- **Drivers NVIDIA / CUDA**: no se gestionan como instalador del repositorio; quedan documentados como una fase manual separada (ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md)).
- **Ajustes de escritorio y atajos de teclado en general**: fuera de alcance, salvo el atajo puntual de Flameshot en `PrintScreen` (ver [ADR 0019](adr/0019-flameshot-atajo-printscreen.md)).
- **Symlinks de `.agents`, `.claude`, `.cursor`**: no se gestionan por ahora (ver [ADR 0020](adr/0020-alcance-fuera-nvidia-dotfiles-agentes.md)).

## Observación de inventario

Node.js tiene un script instalador, pero está intencionalmente ausente de la lista interactiva de aplicaciones porque se lo trata como un prerequisito para la interfaz de Node.js. Esto genera un ciclo de bootstrap que se resuelve con [ADR 0001](adr/0001-bootstrap-bash-sin-node.md).

## Pendiente: clasificación `required | optional | retired | candidate`

El dueño del proyecto prefiere revisar esta clasificación caso por caso en una sesión posterior, en vez de asumirla ahora. Herramientas ya confirmadas como "mantener" pero aún sin clasificar formalmente: Postman, Insomnia, GitKraken, MongoDB Compass, ULauncher, cmatrix, ranger.

Sin fecha propia todavía (`docs/TECHNICAL_REVIEW.md`, hallazgo M10): la revisión natural de esta clasificación es junto con el Hito 11 (Modernización de instaladores) o el Hito 12 (Framework de validación), cuando de todas formas se revisa instalador por instalador — no antes.
