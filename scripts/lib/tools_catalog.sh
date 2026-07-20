#!/usr/bin/env bash
# scripts/lib/tools_catalog.sh
#
# Datos del registro central de instaladores (Hito 11, Fase 4 —
# integración mínima, ver docs/adr/0030-registro-central-de-metadata-de-instaladores.md).
# Separado de scripts/lib/tools_registry.sh (el mecanismo) a propósito:
# este archivo solo declara entradas, para poder probar el mecanismo y
# los datos por separado.
#
# Registra cmatrix/ranger (validación mínima del diseño, Hito 11 Fase 4) y,
# desde la separación de los instaladores multi-paquete (ver ADR 0031,
# docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md),
# los 14 instaladores individuales resultantes. Los 3 agrupadores delgados
# que ADR 0031 había conservado (kind=group) se eliminaron en ADR 0035
# (docs/adr/0035-eliminar-agrupadores-delgados-y-recategorizar-catalogo.md):
# ya no existen ni como scripts ni como entradas del catálogo.
#
# ADR 0035 también agrega un campo no-esquemático nuevo, `subcategory`
# (tools_registry.sh no fuerza ningún esquema, ver ADR 0030), para
# subdividir `category=system` (cli-utils/terminals/shell-personalization/
# gui-utils/misc) sin cambiar la estructura de menú de `setup.js`, que
# sigue usando solo `category`.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_TOOLS_CATALOG_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_TOOLS_CATALOG_SH_LOADED=1

UCI_TOOLS_CATALOG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TOOLS_CATALOG_SCRIPT_DIR
# shellcheck source=tools_registry.sh
source "${UCI_TOOLS_CATALOG_SCRIPT_DIR}/tools_registry.sh"

tools_registry_register "cmatrix" \
    "name=cmatrix" \
    "category=system" \
    "subcategory=misc" \
    "manager=apt" \
    "packages=cmatrix" \
    "script=scripts/system/install_cmatrix.sh" \
    "supported_os=24.04,26.04" \
    "supported_arch=any" \
    "requires_gui=no" \
    "requires_manual_validation=no" \
    "migration_status=migrated"

tools_registry_register "ranger" \
    "name=Ranger" \
    "category=system" \
    "subcategory=terminals" \
    "manager=apt" \
    "packages=ranger" \
    "script=scripts/system/install_ranger.sh" \
    "supported_os=24.04,26.04" \
    "supported_arch=any" \
    "requires_gui=no" \
    "requires_manual_validation=no" \
    "migration_status=migrated"

# install_vim.sh es el instalador de referencia del contrato completo de 6
# verbos (ADR 0029) desde el Hito 3 (ADR 0012), pero nunca sourceó
# scripts/lib/installer_cli.sh/apt.sh (son posteriores, Hito 11 Fase 1):
# migration_status=legacy documenta esa distinción — "implementa los 6
# verbos" y "usa la infraestructura compartida" son ejes distintos (ver
# docs/ARCHITECTURE.md §15).
tools_registry_register "vim" \
    "name=Vim" "category=editors" "manager=apt" "packages=vim" \
    "script=scripts/editors/install_vim.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=legacy"

tools_registry_register "terminator" \
    "name=Terminator" "category=system" "subcategory=terminals" "manager=apt" "packages=terminator" \
    "script=scripts/system/install_terminator.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "flameshot" \
    "name=Flameshot" "category=productivity" "manager=apt" "packages=flameshot" \
    "script=scripts/productivity/install_flameshot.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# ULauncher: manager=apt-vendor-repo (PPA propio, no repositorio oficial de
# Ubuntu — ver ADR 0027) en vez de manager=apt como el resto de los
# instaladores apt-simple migrados hasta ahora.
tools_registry_register "ulauncher" \
    "name=ULauncher" "category=productivity" "manager=apt-vendor-repo" "packages=ulauncher" \
    "script=scripts/productivity/install_ulauncher.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "Development Tools" (ver ADR 0031/0035) —
# subcategory=cli-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "wget" \
    "name=wget" "category=system" "subcategory=cli-utils" "manager=apt" "packages=wget" \
    "script=scripts/system/install_wget.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "curl" \
    "name=curl" "category=system" "subcategory=cli-utils" "manager=apt" "packages=curl" \
    "script=scripts/system/install_curl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "git" \
    "name=Git" "category=system" "subcategory=cli-utils" "manager=apt" "packages=git" \
    "script=scripts/system/install_git.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "build_essential" \
    "name=build-essential" "category=system" "subcategory=cli-utils" "manager=apt" "packages=build-essential" \
    "script=scripts/system/install_build_essential.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "software_properties_common" \
    "name=software-properties-common" "category=system" "subcategory=cli-utils" "manager=apt" "packages=software-properties-common" \
    "script=scripts/system/install_software_properties_common.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "apt_transport_https" \
    "name=apt-transport-https" "category=system" "subcategory=cli-utils" "manager=apt" "packages=apt-transport-https" \
    "script=scripts/system/install_apt_transport_https.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gnupg2" \
    "name=GnuPG" "category=system" "subcategory=cli-utils" "manager=apt" "packages=gnupg2" \
    "script=scripts/system/install_gnupg2.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "Multimedia Tools" (ver ADR 0031/0035) — ya
# vivían en category=multimedia, no necesitan subcategoría
tools_registry_register "cheese" \
    "name=Cheese" "category=multimedia" "manager=apt" "packages=cheese" \
    "script=scripts/system/install_cheese.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "v4l_utils" \
    "name=v4l-utils" "category=multimedia" "manager=apt" "packages=v4l-utils" \
    "script=scripts/system/install_v4l_utils.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "ubuntu_restricted_extras" \
    "name=ubuntu-restricted-extras" "category=multimedia" "manager=apt" "packages=ubuntu-restricted-extras" \
    "script=scripts/system/install_ubuntu_restricted_extras.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vlc" \
    "name=VLC" "category=multimedia" "manager=apt" "packages=vlc" \
    "script=scripts/system/install_vlc.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "System Utilities" (ver ADR 0031/0035) —
# subcategory=gui-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "meld" \
    "name=Meld" "category=system" "subcategory=gui-utils" "manager=apt" "packages=meld" \
    "script=scripts/system/install_meld.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "baobab" \
    "name=Baobab" "category=system" "subcategory=gui-utils" "manager=apt" "packages=baobab" \
    "script=scripts/system/install_baobab.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gparted" \
    "name=GParted" "category=system" "subcategory=gui-utils" "manager=apt" "packages=gparted" \
    "script=scripts/system/install_gparted.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo Snap (Hito 11): manager=snap en vez de apt, ver scripts/lib/snap.sh.
# requires_manual_validation=yes en los 8: snapd no corre sin systemd
# dentro de los contenedores Docker usados por este proyecto, así que
# ninguno se prueba funcionalmente en CI (ver docs/UBUNTU_COMPATIBILITY.md).
tools_registry_register "dbeaver" \
    "name=DBeaver" "category=development" "manager=snap" "packages=dbeaver-ce" \
    "script=scripts/development/install_dbeaver.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gitkraken" \
    "name=GitKraken" "category=development" "manager=snap" "packages=gitkraken" \
    "script=scripts/development/install_gitkraken.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "insomnia" \
    "name=Insomnia" "category=development" "manager=snap" "packages=insomnia" \
    "script=scripts/development/install_insomnia.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "postman" \
    "name=Postman" "category=development" "manager=snap" "packages=postman" \
    "script=scripts/development/install_postman.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gimp" \
    "name=GIMP" "category=system" "subcategory=gui-utils" "manager=snap" "packages=gimp" \
    "script=scripts/system/install_gimp.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "obs_studio" \
    "name=OBS Studio" "category=system" "subcategory=gui-utils" "manager=snap" "packages=obs-studio" \
    "script=scripts/system/install_obs_studio.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "spotify" \
    "name=Spotify" "category=productivity" "manager=snap" "packages=spotify" \
    "script=scripts/productivity/install_spotify.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "zoom" \
    "name=Zoom" "category=productivity" "manager=snap" "packages=zoom-client" \
    "script=scripts/productivity/install_zoom.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Grupo vendor-repo (Hito 11): manager=apt-vendor-repo, ver
# scripts/lib/apt_vendor_repo.sh. requires_manual_validation=no: los 3
# tienen prueba funcional real en CI (tests/docker/test_*_apt_repo.sh:
# C01/V01/D01), a diferencia del grupo Snap.
tools_registry_register "docker" \
    "name=Docker" "category=development" "manager=apt-vendor-repo" "packages=docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin" \
    "script=scripts/development/install_docker.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vscode" \
    "name=Visual Studio Code" "category=editors" "manager=apt-vendor-repo" "packages=code" \
    "script=scripts/editors/install_vscode.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "cursor" \
    "name=Cursor AI IDE" "category=editors" "manager=apt-vendor-repo" "packages=cursor" \
    "script=scripts/editors/install_cursor.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo Mise (Hito 11): manager=mise, ver scripts/lib/runtime.sh (Hito 8).
# migration_status=migrated aquí significa "usa scripts/lib/installer_cli.sh"
# — la lógica de instalación en sí (scripts/lib/runtime.sh) no cambió,
# solo el dispatcher.
tools_registry_register "kubectl" \
    "name=kubectl" "category=development" "manager=mise" "packages=kubectl" \
    "script=scripts/development/install_kubectl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yarn" \
    "name=Yarn" "category=development" "manager=mise" "packages=yarn" \
    "script=scripts/development/install_yarn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# gh (GitHub CLI): manager=mise igual que kubectl/Yarn, aunque también está
# en el repositorio oficial de Ubuntu (universe) — decisión explícita del
# dueño del proyecto (ver ADR 0033 y ADR 0034, esta última corrige el
# manager=mise-tool propuesto originalmente en 0033 tras confirmar que
# kubectl/Yarn ya resuelven este mismo caso con manager=mise).
tools_registry_register "gh" \
    "name=GitHub CLI" "category=development" "manager=mise" "packages=gh" \
    "script=scripts/development/install_gh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo deb-directo (Hito 11): manager=deb-direct, ver
# scripts/lib/deb_direct.sh. Chrome es supported_arch=amd64 (ver ADR
# 0028); MongoDB Compass no publica un .deb multi-arch tampoco pero su
# instalador nunca implementó un chequeo de arquitectura propio (fuera de
# alcance de esta migración, ver docs/UBUNTU_COMPATIBILITY.md).
tools_registry_register "chrome" \
    "name=Google Chrome" "category=productivity" "manager=deb-direct" "packages=google-chrome-stable" \
    "script=scripts/productivity/install_chrome.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "mongodb_compass" \
    "name=MongoDB Compass" "category=development" "manager=deb-direct" "packages=mongodb-compass" \
    "script=scripts/development/install_mongodb_compass.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo git-clone (Hito 11): manager=git-clone, ver scripts/lib/git_clone.sh.
# 'packages' se omite: no instalan un paquete propio con ese nombre, solo
# 'zsh' como dependencia compartida entre ambos.
tools_registry_register "oh_my_zsh" \
    "name=Oh My Zsh" "category=system" "subcategory=shell-personalization" "manager=git-clone" \
    "script=scripts/system/install_oh_my_zsh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "powerlevel10k" \
    "name=Powerlevel10k" "category=system" "subcategory=shell-personalization" "manager=git-clone" \
    "script=scripts/system/install_powerlevel10k.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo mantenimiento (Hito 11, ver ADR 0013): acciones de sistema, no
# instaladores de apps. 'kind=maintenance' las distingue de una
# herramienta o de un agrupador (ver ADR 0031) — no tienen 'packages' (no
# instalan un paquete propio con ese nombre) y system_update/final_update
# solo implementan status/install a propósito (uninstall/reinstall/
# update/repair se rechazan explícitamente, ver el propio script).
tools_registry_register "system_update" \
    "name=System Updates" "category=maintenance" "manager=apt" \
    "script=scripts/system/install_system_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "final_update" \
    "name=Final System Update" "category=maintenance" "manager=apt" \
    "script=scripts/maintenance/install_final_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "kernel" \
    "name=Kernel & Headers" "category=maintenance" "manager=apt" \
    "script=scripts/system/install_kernel.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated" \
    "kind=maintenance"

# Terminales y gestores de archivos de terminal nuevos (2026-07-20).
tools_registry_register "nnn" \
    "name=nnn" "category=system" "subcategory=terminals" "manager=apt" "packages=nnn" \
    "script=scripts/system/install_nnn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "lf" \
    "name=lf" "category=system" "subcategory=terminals" "manager=apt" "packages=lf" \
    "script=scripts/system/install_lf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yazi" \
    "name=Yazi" "category=system" "subcategory=terminals" "manager=snap" "packages=yazi" \
    "script=scripts/system/install_yazi.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# manager=apt (mecanismo de fondo): la rama condicional PPA/repo oficial
# según versión de Ubuntu vive en el propio script, ver ADR 0032 — no se
# modela como un campo separado del catálogo.
tools_registry_register "ghostty" \
    "name=Ghostty" "category=system" "subcategory=terminals" "manager=apt" "packages=ghostty" \
    "script=scripts/system/install_ghostty.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "wezterm" \
    "name=WezTerm" "category=system" "subcategory=terminals" "manager=apt-vendor-repo" "packages=wezterm" \
    "script=scripts/system/install_wezterm.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo curl-script (Hito 16): manager=curl-script, ver
# scripts/lib/curl_script.sh (ADR 0037). Categorías por función real, no
# por ser "de IA" en sí (ver ADR 0036): CLIs de desarrollo en
# category=development/subcategory=ai-cli, agentes de propósito general
# en category=productivity/subcategory=ai-agent. requires_manual_validation=yes
# en los 6: no hay prueba funcional real contra los dominios oficiales de
# estos proveedores en esta ronda (servicios externos nuevos, sin
# historial de estabilidad verificado en CI, ver ADR 0037).
tools_registry_register "claude_code" \
    "name=Claude Code" "category=development" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_claude_code.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "codex_cli" \
    "name=Codex CLI" "category=development" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_codex_cli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "opencode" \
    "name=OpenCode" "category=development" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_opencode.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Antigravity: solo el CLI 'agy' (category=development/ai-cli). El
# IDE/Desktop queda diferido a propósito — sin apt/snap oficial, solo
# tarball manual sin checksum/firma descripta (ver ADR 0037).
tools_registry_register "antigravity" \
    "name=Antigravity CLI" "category=development" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_antigravity.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "openclaw" \
    "name=OpenClaw" "category=productivity" "subcategory=ai-agent" "manager=curl-script" \
    "script=scripts/productivity/install_openclaw.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "hermes_agent" \
    "name=Hermes Agent" "category=productivity" "subcategory=ai-agent" "manager=curl-script" \
    "script=scripts/productivity/install_hermes_agent.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Claude Desktop: manager=apt-vendor-repo (reutiliza la infraestructura
# existente, mismo patrón que Docker/VS Code/Cursor), no curl-script — sí
# tiene repo APT oficial propio. Cowork (KVM/disco/RAM) no se valida en
# el instalador, ver el propio script.
tools_registry_register "claude_desktop" \
    "name=Claude Desktop" "category=productivity" "subcategory=ai-agent" "manager=apt-vendor-repo" "packages=claude-desktop" \
    "script=scripts/productivity/install_claude_desktop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"
