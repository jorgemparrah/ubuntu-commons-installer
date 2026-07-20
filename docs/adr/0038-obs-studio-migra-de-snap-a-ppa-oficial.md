# 0038. OBS Studio migra de Snap a su PPA oficial

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

`docs/TOOLS.md` dejaba a `install_obs_studio.sh` con la nota "Mantener; verificar fuente deseada" desde el Hito 9 — a diferencia del resto del catálogo, nunca se confirmó explícitamente si Snap era la fuente correcta para esta herramienta (mismo caso que GIMP, ver más abajo).

Investigando ambas fuentes:

- **GIMP**: el Snap Store ya sigue la rama 3.2.x en las 3 LTS soportadas (incluida 24.04, donde el paquete apt todavía trae 2.10.x); en 26.04 el apt ya trae 3.2.x también. Snap es la fuente más actualizada de forma consistente — se **confirma** Snap sin cambios.
- **OBS Studio**: el propio [OBS Project recomienda oficialmente su PPA](https://obsproject.com/forum/threads/ubuntu-ppa-installation-instructions.16495/) (`ppa:obsproject/obs-studio`) para Ubuntu, junto con Flatpak — son los **dos únicos builds Linux oficiales y soportados**. El snap de OBS Studio está etiquetado explícitamente **"unofficial"**, mantenido por la comunidad (Snapcrafters) — aunque desde mediados de 2025 se compila del mismo código fuente que el PPA oficial, sigue sin ser el canal oficial del proveedor.

Esto contradice la jerarquía de fuentes del proyecto (`AGENT.md` §15 / [ADR 0027](0027-orden-de-fuentes-por-categoria.md)): repositorio oficial de Ubuntu > repositorio oficial del proveedor > instalador oficial > Snap > Flatpak. El PPA oficial de OBS Project encaja en la segunda categoría; el Snap actual encaja en una cuarta categoría inferior, y encima no es el propio proveedor quien lo publica.

## Decisión

`install_obs_studio.sh` migra de `manager=snap` a `manager=apt-vendor-repo`, usando el PPA oficial `ppa:obsproject/obs-studio` vía `add-apt-repository` — mismo mecanismo que `install_ulauncher.sh` (el único otro instalador del catálogo que agrega un PPA en vez de un repositorio APT con keyring manual).

- `check_status`: `apt_package_installed` + `command -v obs` (el binario real se llama `obs`, no `obs-studio`) + `apt list --upgradable`, mismo patrón que ULauncher/Ranger.
- `install`: si falta `add-apt-repository`, instala `software-properties-common` primero; agrega `universe` y el PPA; instala `obs-studio` vía `apt_install_packages`.
- `uninstall`: `apt_purge_packages` + remueve el PPA.
- `update`/`repair`/`reinstall`: mismo patrón que ULauncher (verbos completos, ya no hay limitación de Snap).
- `requires_manual_validation` pasa de `yes` a `no`: ya no depende de `snapd` (ausente en los contenedores Docker de CI), así que puede probarse automáticamente igual que el resto de los instaladores `apt-vendor-repo`.
- Se retira de `tests/test_snap_installers_contract.sh` y `tests/test_snap_installers_full_contract.sh` (pasa de 9 a 8 instaladores Snap); se agrega un contrato mockeado propio, mismo criterio que `tests/test_ulauncher_installer.sh`.

GIMP queda confirmado sin cambios: su nota "Revisar fuente deseada" en `docs/TOOLS.md` se actualiza a "confirmado" (Snap ya es la fuente más nueva en ambas versiones de Ubuntu soportadas).

## Consecuencias

- `docs/TOOLS.md`, `docs/UBUNTU_COMPATIBILITY.md` y `docs/ARCHITECTURE.md` se actualizan para reflejar el mecanismo nuevo de OBS Studio y la confirmación de GIMP.
- El grupo Snap del catálogo pasa de 9 a 8 instaladores (DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi).
- Relacionado: [ADR 0027](0027-orden-de-fuentes-por-categoria.md) (orden de fuentes por categoría), [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato completo de 6 verbos).
