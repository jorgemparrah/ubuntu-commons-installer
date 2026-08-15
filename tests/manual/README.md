# tests/manual/

Scripts de validación manual (Hito 18/19, ver `docs/ROADMAP.md`) para lo que ningún contenedor Docker de este proyecto puede probar de verdad: instalar software real, contra repositorios reales, en una Ubuntu real.

## Estado de la cobertura

El grupo original (Hito 18) cubría 18 instaladores. Los grupos nuevos (Hito 19) suman los **51 restantes** que estaban marcados `requires_manual_validation=yes` sin script que los validara, así que hoy **las 69 herramientas del catálogo que requieren validación manual están cubiertas**.

Conviene tener presente qué significa eso: las pruebas automatizadas (`tests/`, 145 de 147 entradas) son en su mayoría **mockeadas** — verifican que el instalador invoque los comandos correctos, no que la app se instale de verdad. Estos scripts son los únicos que prueban el ciclo real contra la red real.

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

## Grupos nuevos (Hito 19)

Se corren con un runner propio que deja **un log por grupo**, para revisar y reportar de a tandas en vez de generar un log gigante:

```bash
bash tests/manual/run_manual_group.sh --list        # ver los grupos
bash tests/manual/run_manual_group.sh cli           # uno puntual
bash tests/manual/run_manual_group.sh cli deb-direct # varios
bash tests/manual/run_manual_group.sh all           # todo (varios GB)
```

Cada grupo deja `/tmp/ubuntu-workstation-manual-tests/<grupo>-<timestamp>.log` (más un symlink `<grupo>-latest.log`). Un grupo que falla **no corta** los siguientes: la idea es juntar todos los resultados en una corrida.

| Grupo | Cubre | Peso / riesgo |
|---|---|---|
| `cli` | 6 livianos (Starship, Joplin, procs, xh, pipes.sh, pokemon-colorscripts) + el verbo `configure` de Starship (Nerd Font) | **El más rápido y seguro — empezar por acá** |
| `snap-extra` | 8 Snap posteriores al Hito 18 (Bitwarden, Bruno, Chromium, Helix, Krita, Obsidian, Telegram, yq) | Medio: Chromium/Krita/Obsidian/Telegram son pesados |
| `apt-vendor` | 13 con repo APT del proveedor (Brave, Signal, Slack, Element, KeePassXC, OnlyOffice, Syncthing, Inkscape, fastfetch, cloudflared, VSCodium, ngrok, Albert) | Medio; verifica además que `apt-get update` siga sano con todos los repos |
| `deb-direct` | 9 que bajan un `.deb` (dust, LocalSend, Discord, Beekeeper, DbGate, Hoppscotch, Lutris, Heroic, **Orca**) | Medio-alto: Lutris y Heroic son grandes |
| `flatpak` | 3 Flatpak (Kooha, Logseq, Papers) | La primera app baja el runtime de GNOME (>1 GB) |
| `system-heavy` | 6 que tocan el sistema (Wireshark, Steam, virt-manager, Tailscale, LibreOffice, SoapUI) | **Alto**: grupos de usuario, arquitectura i386, servicios. VirtualBox aparte |
| `ai-local` | 5 de IA local (AnythingLLM, Ollama, LM Studio, Open WebUI, OmniRoute) | **El más pesado**: varios GB |

Orden sugerido: `cli` → `snap-extra` → `apt-vendor` → `deb-direct` → `flatpak` → `system-heavy` → `ai-local`.

### Verificaciones específicas, más allá del ciclo de vida

Varios grupos comprueban cosas que solo tienen sentido en una máquina real:

- **Orca** — que `/usr/bin/orca-ide` sea el symlink que crea el `postinst` (no viene en el `.deb`), y que el paquete `orca` de Ubuntu (**el lector de pantalla de GNOME**) quede intacto antes y después. Un error ahí dejaría a alguien sin accesibilidad.
- **Wireshark** — que exista el grupo `wireshark`, que el usuario quede dentro y que `dumpcap` pertenezca a ese grupo, o sea que el preseed de debconf tomó efecto y la captura funciona sin `sudo`.
- **Open WebUI / OmniRoute** — que Mise haya instalado su propio Python 3.11 y Node 24. Es la razón de existir de `pip-mise` y `npm-mise`, y ningún mock puede demostrarlo. Si Mise no está al empezar, se verifica además que `status` diga `UNKNOWN` y no `NOT_INSTALLED`.
- **Starship `configure`** — que queden las **4** variantes de MesloLGS NF y que `fc-list` ya reconozca la fuente; y que una segunda corrida sea idempotente.
- **Steam** — que la arquitectura `i386` quede habilitada.
- **Flatpak** — que el remoto `flathub` quede configurado.
- **apt-vendor** — que `apt-get update` no emita `W:`/`E:` con los 13 repositorios agregados.

### Lo que estos scripts NO revierten

Algunos efectos quedan a propósito tras `uninstall`, y el log lo deja anotado: la arquitectura `i386`, los grupos de usuario, el runtime de GNOME de Flatpak, `libfuse2`, los repositorios de proveedor y la Nerd Font. Quitarlos podría romper otras herramientas. Es otra razón para usar una VM descartable.

### VirtualBox

Queda fuera de `system-heavy` por defecto: compila módulos del kernel y, con Secure Boot activo, abre un diálogo interactivo de inscripción de clave (MOK). Se corre a conciencia, igual que el kernel HWE:

```bash
bash tests/manual/test_manual_system_heavy.sh --include-virtualbox
```

## Grupo original (Hito 18)

`run_all_manual_tests.sh` corre los 4 en orden, pero **nunca** pasa `--install` al de kernel — ese paso se corre aparte, a mano, cuando estés listo para asumir el riesgo en una VM que puedas descartar:

```bash
bash tests/manual/test_manual_kernel_hwe.sh --install
```

## Si algo falla

Compartí el log completo (`/tmp/ubuntu-workstation-manual-tests/manual-tests-latest.log`, o el de un script individual si corriste uno suelto). A partir de ahí se decide si el problema está en el instalador real (se corrige el instalador) o en cómo lo prueba el script (se corrige el script de `tests/manual/`) — ver Hito 19 en `docs/ROADMAP.md`.
