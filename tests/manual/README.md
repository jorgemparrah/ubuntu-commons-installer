# tests/manual/

Scripts de validación manual (Hito 18/19, ver `docs/ROADMAP.md`) para lo que ningún contenedor Docker de este proyecto puede probar de verdad: los 8 instaladores Snap, Antigravity IDE, las 7 candidatas de IA del Hito 16, el atajo `PrintScreen` de Flameshot (Hito 17) y el kernel HWE.

**Esto NUNCA se corre en CI ni en la máquina de desarrollo de este repositorio.** Está pensado para clonar el repo en una VM Ubuntu 24.04 o 26.04 **Desktop** (con sesión gráfica GNOME real) que puedas descartar o revertir sin problema, y correrlo ahí.

## Uso

```bash
git clone <este repositorio>
cd ubuntu-commons-installer

# Todo lo seguro por defecto (Snap, IA/Antigravity IDE, Flameshot, y solo
# el 'status' del kernel HWE — nunca instala el kernel automáticamente):
bash tests/manual/run_all_manual_tests.sh
```

El log completo queda guardado en `/tmp/ubuntu-workstation-manual-tests/manual-tests-<timestamp>.log` (y un symlink `manual-tests-latest.log` apuntando a la corrida más reciente), además de verse en vivo por terminal. Pegá ese log de vuelta para iterar sobre cualquier fallo.

## Qué corre cada script

| Script | Qué prueba | Riesgo |
|---|---|---|
| `test_manual_snap_apps.sh` | Ciclo `status→install→status→uninstall→status` real de DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi | Bajo — instala/desinstala software real, sin tocar configuración del sistema |
| `test_manual_ai_and_ide.sh` | Mismo ciclo para Antigravity IDE (repo APT oficial) y las 7 candidatas de IA (Claude Code, Codex CLI, OpenCode, Antigravity CLI, OpenClaw, Hermes Agent, Claude Desktop) | Bajo — mismo criterio |
| `test_manual_flameshot_configure.sh` | El verbo `configure` nuevo del Hito 17: agrega el atajo `PrintScreen` vía `gsettings`, confirma que no se duplica en una segunda corrida, y que se respaldó la lista previa | Bajo — requiere sesión GNOME real (falla explícitamente si no la hay). El único paso que no automatiza: confirmar a mano que apretar PrintScreen abre Flameshot de verdad |
| `test_manual_kernel_hwe.sh` | `install_kernel.sh` (kernel HWE) | **Alto si se corre con `--install`** — modifica el kernel de arranque, puede requerir reiniciar. Por defecto (sin `--install`) solo corre `status`, que es de solo lectura |

`run_all_manual_tests.sh` corre los 4 en orden, pero **nunca** pasa `--install` al de kernel — ese paso se corre aparte, a mano, cuando estés listo para asumir el riesgo en una VM que puedas descartar:

```bash
bash tests/manual/test_manual_kernel_hwe.sh --install
```

## Si algo falla

Compartí el log completo (`/tmp/ubuntu-workstation-manual-tests/manual-tests-latest.log`, o el de un script individual si corriste uno suelto). A partir de ahí se decide si el problema está en el instalador real (se corrige el instalador) o en cómo lo prueba el script (se corrige el script de `tests/manual/`) — ver Hito 19 en `docs/ROADMAP.md`.
