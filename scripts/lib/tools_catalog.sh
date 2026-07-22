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
    "category=system" "classification=optional" "profiles=cli,full" \
    "subcategory=extras" \
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
    "category=system" "classification=optional" "profiles=cli,full" \
    "subcategory=file-managers" \
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
    "name=Vim" "category=editors" "subcategory=terminal-editors" "classification=optional" "profiles=cli,desktop,developer,workstation,full,editor" "manager=apt" "packages=vim" \
    "script=scripts/editors/install_vim.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=legacy"

tools_registry_register "terminator" \
    "name=Terminator" "category=system" "classification=optional" "profiles=full" "subcategory=terminals" "manager=apt" "packages=terminator" \
    "script=scripts/system/install_terminator.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "flameshot" \
    "name=Flameshot" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=flameshot" \
    "script=scripts/productivity/install_flameshot.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# ULauncher: manager=apt-vendor-repo (PPA propio, no repositorio oficial de
# Ubuntu — ver ADR 0027) en vez de manager=apt como el resto de los
# instaladores apt-simple migrados hasta ahora.
tools_registry_register "ulauncher" \
    "name=ULauncher" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=ulauncher" \
    "script=scripts/productivity/install_ulauncher.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "Development Tools" (ver ADR 0031/0035) —
# subcategory=cli-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "wget" \
    "name=wget" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=wget" \
    "script=scripts/system/install_wget.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "curl" \
    "name=curl" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=curl" \
    "script=scripts/system/install_curl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "git" \
    "name=Git" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=git" \
    "script=scripts/system/install_git.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "build_essential" \
    "name=build-essential" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=build-essential" \
    "script=scripts/system/install_build_essential.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "software_properties_common" \
    "name=software-properties-common" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=software-properties-common" \
    "script=scripts/system/install_software_properties_common.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "apt_transport_https" \
    "name=apt-transport-https" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=apt-transport-https" \
    "script=scripts/system/install_apt_transport_https.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gnupg2" \
    "name=GnuPG" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=gnupg2" \
    "script=scripts/system/install_gnupg2.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Herramientas CLI (Hito 28, 2026-07-21): fzf/thefuck/jq (apt-simple),
# yq (snap oficial de Mike Farah — el paquete apt de Ubuntu es un
# programa DISTINTO e incompatible, ver el propio install_yq.sh).
tools_registry_register "fzf" \
    "name=fzf" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=fzf" \
    "script=scripts/system/install_fzf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "thefuck" \
    "name=thefuck" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=thefuck" \
    "script=scripts/system/install_thefuck.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "jq" \
    "name=jq" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=jq" \
    "script=scripts/system/install_jq.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yq" \
    "name=yq" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=snap" "packages=yq" \
    "script=scripts/system/install_yq.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Instaladores individuales ex "Multimedia Tools" (ver ADR 0031/0035) — ya
# vivían en category=multimedia. subcategory=capture/playback/codecs
# agregadas el 2026-07-22 (antes sin subcategoría), junto con GIMP y OBS
# Studio (movidos aquí desde system/gui-utils el mismo día, ver más abajo).
tools_registry_register "cheese" \
    "name=Cheese" "category=multimedia" "subcategory=capture" "classification=optional" "profiles=desktop,workstation,full,creator" "manager=apt" "packages=cheese" \
    "script=scripts/system/install_cheese.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "v4l_utils" \
    "name=v4l-utils" "category=multimedia" "subcategory=capture" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=v4l-utils" \
    "script=scripts/system/install_v4l_utils.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "ubuntu_restricted_extras" \
    "name=ubuntu-restricted-extras" "category=multimedia" "subcategory=codecs" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=ubuntu-restricted-extras" \
    "script=scripts/system/install_ubuntu_restricted_extras.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vlc" \
    "name=VLC" "category=multimedia" "subcategory=playback" "classification=optional" "profiles=desktop,workstation,full,creator" "manager=apt" "packages=vlc" \
    "script=scripts/system/install_vlc.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "System Utilities" (ver ADR 0031/0035) —
# subcategory=gui-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "meld" \
    "name=Meld" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=meld" \
    "script=scripts/system/install_meld.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "baobab" \
    "name=Baobab" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=baobab" \
    "script=scripts/system/install_baobab.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gparted" \
    "name=GParted" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=gparted" \
    "script=scripts/system/install_gparted.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo Snap (Hito 11): manager=snap en vez de apt, ver scripts/lib/snap.sh.
# requires_manual_validation=yes: snapd no corre sin systemd dentro de los
# contenedores Docker usados por este proyecto, así que ninguno se prueba
# funcionalmente en CI (ver docs/UBUNTU_COMPATIBILITY.md). OBS Studio
# salió de este grupo el 2026-07-20 (migró a su PPA oficial, ver ADR
# 0038); Yazi se sumó en el Hito 16 (terminales nuevas) — 8 miembros hoy:
# DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi. GIMP
# pasó de category=system/gui-utils a category=multimedia/graphics el
# 2026-07-22 (corrección de categorización a pedido del dueño del
# proyecto — es un editor gráfico, no una utilidad de sistema).
tools_registry_register "dbeaver" \
    "name=DBeaver" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=dbeaver-ce" \
    "script=scripts/development/install_dbeaver.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gitkraken" \
    "name=GitKraken" "category=development" "subcategory=git-tools" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=gitkraken" \
    "script=scripts/development/install_gitkraken.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "insomnia" \
    "name=Insomnia" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=insomnia" \
    "script=scripts/development/install_insomnia.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "postman" \
    "name=Postman" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=postman" \
    "script=scripts/development/install_postman.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gimp" \
    "name=GIMP" "category=multimedia" "classification=optional" "profiles=full" "subcategory=graphics" "manager=snap" "packages=gimp" \
    "script=scripts/system/install_gimp.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# OBS Studio: manager=apt-vendor-repo (PPA oficial, ver ADR 0038) — migró
# de Snap (etiquetado "unofficial" por el propio OBS Project). Ya no
# depende de snapd, requires_manual_validation=no. category=multimedia/
# capture desde el 2026-07-22 (antes system/gui-utils — corrección de
# categorización a pedido del dueño del proyecto, junto con GIMP).
tools_registry_register "obs_studio" \
    "name=OBS Studio" "category=multimedia" "classification=optional" "profiles=full" "subcategory=capture" "manager=apt-vendor-repo" "packages=obs-studio" \
    "script=scripts/system/install_obs_studio.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "spotify" \
    "name=Spotify" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=spotify" \
    "script=scripts/productivity/install_spotify.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "zoom" \
    "name=Zoom" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=zoom-client" \
    "script=scripts/productivity/install_zoom.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Mensajería (Hito 25, 2026-07-21): Telegram Desktop (snap oficial, sin
# repo APT propio), Slack (repo APT oficial vía Packagecloud, preferido
# sobre el .deb suelto que también publican), Discord (sin repo APT
# oficial; endpoint estable que siempre resuelve a la última versión, sin
# fijar número de versión como MongoDB Compass). subcategory=communication
# nueva. Zoom se sumó a esta subcategoría el 2026-07-22 (antes sin
# subcategoría — corrección de categorización a pedido del dueño del
# proyecto).
tools_registry_register "telegram_desktop" \
    "name=Telegram Desktop" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=telegram-desktop" \
    "script=scripts/productivity/install_telegram_desktop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "slack" \
    "name=Slack" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=slack-desktop" \
    "script=scripts/productivity/install_slack.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "discord" \
    "name=Discord" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=discord" \
    "script=scripts/productivity/install_discord.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Productividad de escritorio (Hito 26, 2026-07-21): LibreOffice
# (apt-simple, el paquete oficial de Ubuntu ya está razonablemente al
# día; el PPA "Fresh" de TDF es explícitamente bleeding-edge/inestable,
# excepción consciente al criterio de priorizar la fuente más reciente),
# OnlyOffice (repo APT oficial propio), Obsidian (snap oficial
# 'obsidianmd', --classic), KeePassXC (PPA oficial del propio equipo,
# ppa:phoerious/keepassxc). subcategory=office/notes/security nuevas.
tools_registry_register "libreoffice" \
    "name=LibreOffice" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=libreoffice" \
    "script=scripts/productivity/install_libreoffice.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "onlyoffice" \
    "name=OnlyOffice" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=onlyoffice-desktopeditors" \
    "script=scripts/productivity/install_onlyoffice.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "obsidian" \
    "name=Obsidian" "category=productivity" "subcategory=notes" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=obsidian" \
    "script=scripts/productivity/install_obsidian.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "keepassxc" \
    "name=KeePassXC" "category=productivity" "subcategory=security" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=keepassxc" \
    "script=scripts/productivity/install_keepassxc.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Navegadores (Hito 27, 2026-07-21): Brave (repo APT oficial, primer caso
# real de apt_vendor_repo_fetch_file_plain — clave ya lista y archivo
# .sources DEB822 completo, sin línea 'deb [...]' a mano), Chromium
# (snap oficial de Canonical: el paquete chromium-browser de Ubuntu es
# transicional y en la práctica instala este mismo snap).
# subcategory=browsers nueva.
tools_registry_register "brave" \
    "name=Brave" "category=productivity" "subcategory=browsers" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=brave-browser" \
    "script=scripts/productivity/install_brave.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "chromium" \
    "name=Chromium" "category=productivity" "subcategory=browsers" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=chromium" \
    "script=scripts/productivity/install_chromium.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Misceláneos (Hito 29, 2026-07-21): LocalSend (deb-direct desde GitHub
# Releases, URL resuelta dinámicamente), Steam (apt-simple + arquitectura
# i386 habilitada explícitamente en install_tool), Okular (apt-simple).
# subcategory=file-sharing/gaming nuevas.
tools_registry_register "localsend" \
    "name=LocalSend" "category=productivity" "subcategory=file-sharing" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=localsend_app" \
    "script=scripts/productivity/install_localsend.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "steam" \
    "name=Steam" "category=productivity" "subcategory=gaming" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=steam-installer" \
    "script=scripts/productivity/install_steam.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "okular" \
    "name=Okular" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=okular" \
    "script=scripts/productivity/install_okular.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo vendor-repo (Hito 11): manager=apt-vendor-repo, ver
# scripts/lib/apt_vendor_repo.sh. requires_manual_validation=no: los 3
# tienen prueba funcional real en CI (tests/docker/test_*_apt_repo.sh:
# C01/V01/D01), a diferencia del grupo Snap.
tools_registry_register "docker" \
    "name=Docker" "category=development" "subcategory=containers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin" \
    "script=scripts/development/install_docker.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vscode" \
    "name=Visual Studio Code" "category=editors" "subcategory=gui-editors" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=code" \
    "script=scripts/editors/install_vscode.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# VirtualBox (Hito 24, 2026-07-21): repo APT oficial de Oracle (nunca el
# paquete 'virtualbox' de Ubuntu, que suele quedar desactualizado). Primer
# instalador que depende de un módulo de kernel (vboxdrv vía DKMS) —
# requires_manual_validation=yes porque ningún contenedor Docker de este
# proyecto puede cargar un módulo de kernel real; se valida en
# tests/manual/ (Hito 19), no en CI.
tools_registry_register "virtualbox" \
    "name=VirtualBox" "category=development" "subcategory=virtualization" "classification=optional" "profiles=developer,workstation,full,coding" "manager=apt-vendor-repo" \
    "script=scripts/development/install_virtualbox.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "cursor" \
    "name=Cursor AI IDE" "category=ai" "subcategory=ai-ide" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=cursor" \
    "script=scripts/editors/install_cursor.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Antigravity IDE (Hito 16, 2026-07-21, ver ADR 0041): repo APT oficial de
# Google, no el tarball manual que se había investigado originalmente en
# ADR 0037 — distinto de "antigravity" (el CLI 'agy', category=development,
# ver más abajo), son dos productos con mecanismos separados.
tools_registry_register "antigravity_ide" \
    "name=Antigravity IDE" "category=ai" "subcategory=ai-ide" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=antigravity" \
    "script=scripts/editors/install_antigravity_ide.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Grupo Mise (Hito 11): manager=mise, ver scripts/lib/runtime.sh (Hito 8).
# migration_status=migrated aquí significa "usa scripts/lib/installer_cli.sh"
# — la lógica de instalación en sí (scripts/lib/runtime.sh) no cambió,
# solo el dispatcher.
tools_registry_register "kubectl" \
    "name=kubectl" "category=development" "subcategory=containers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=kubectl" \
    "script=scripts/development/install_kubectl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yarn" \
    "name=Yarn" "category=development" "subcategory=package-managers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=yarn" \
    "script=scripts/development/install_yarn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# gh (GitHub CLI): manager=mise igual que kubectl/Yarn, aunque también está
# en el repositorio oficial de Ubuntu (universe) — decisión explícita del
# dueño del proyecto (ver ADR 0033 y ADR 0034, esta última corrige el
# manager=mise-tool propuesto originalmente en 0033 tras confirmar que
# kubectl/Yarn ya resuelven este mismo caso con manager=mise).
tools_registry_register "gh" \
    "name=GitHub CLI" "category=development" "subcategory=git-tools" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=gh" \
    "script=scripts/development/install_gh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo deb-directo (Hito 11): manager=deb-direct, ver
# scripts/lib/deb_direct.sh. Chrome es supported_arch=amd64 (ver ADR
# 0028); MongoDB Compass no publica un .deb multi-arch tampoco pero su
# instalador nunca implementó un chequeo de arquitectura propio (fuera de
# alcance de esta migración, ver docs/UBUNTU_COMPATIBILITY.md).
tools_registry_register "chrome" \
    "name=Google Chrome" "category=productivity" "subcategory=browsers" "classification=required" "profiles=minimal,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=deb-direct" "packages=google-chrome-stable" \
    "script=scripts/productivity/install_chrome.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "mongodb_compass" \
    "name=MongoDB Compass" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=deb-direct" "packages=mongodb-compass" \
    "script=scripts/development/install_mongodb_compass.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo git-clone (Hito 11): manager=git-clone, ver scripts/lib/git_clone.sh.
# 'packages' se omite: no instalan un paquete propio con ese nombre, solo
# 'zsh' como dependencia compartida entre ambos.
tools_registry_register "oh_my_zsh" \
    "name=Oh My Zsh" "category=system" "classification=optional" "profiles=cli,full" "subcategory=shell-personalization" "manager=git-clone" \
    "script=scripts/system/install_oh_my_zsh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Powerlevel10k depende de Oh My Zsh (Hito 17, ver ADR 0042). Primer caso
# real del campo depends_on: si Oh My Zsh no está instalado, install_tool
# rechaza explícitamente en vez de instalarlo por su cuenta.
tools_registry_register "powerlevel10k" \
    "name=Powerlevel10k" "category=system" "classification=optional" "profiles=cli,full" "subcategory=shell-personalization" "manager=git-clone" "depends_on=oh_my_zsh" \
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
    "name=System Updates" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/system/install_system_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "final_update" \
    "name=Final System Update" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/maintenance/install_final_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "kernel" \
    "name=Kernel & Headers" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/system/install_kernel.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated" \
    "kind=maintenance"

# Gestores de archivos de terminal (2026-07-20, subcategory=file-managers
# desde 2026-07-22 — antes vivían junto a los emuladores de terminal reales
# bajo subcategory=terminals, corregido a pedido del dueño del proyecto).
tools_registry_register "nnn" \
    "name=nnn" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=apt" "packages=nnn" \
    "script=scripts/system/install_nnn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "lf" \
    "name=lf" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=apt" "packages=lf" \
    "script=scripts/system/install_lf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yazi" \
    "name=Yazi" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=snap" "packages=yazi" \
    "script=scripts/system/install_yazi.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# manager=apt (mecanismo de fondo): la rama condicional PPA/repo oficial
# según versión de Ubuntu vive en el propio script, ver ADR 0032 — no se
# modela como un campo separado del catálogo.
tools_registry_register "ghostty" \
    "name=Ghostty" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt" "packages=ghostty" \
    "script=scripts/system/install_ghostty.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "wezterm" \
    "name=WezTerm" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt-vendor-repo" "packages=wezterm" \
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
    "name=Claude Code" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_claude_code.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "codex_cli" \
    "name=Codex CLI" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_codex_cli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "opencode" \
    "name=OpenCode" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_opencode.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Antigravity: solo el CLI 'agy' (category=development/ai-cli). El
# IDE/Desktop queda diferido a propósito — sin apt/snap oficial, solo
# tarball manual sin checksum/firma descripta (ver ADR 0037).
tools_registry_register "antigravity" \
    "name=Antigravity CLI" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_antigravity.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Ollama (Hito 28, 2026-07-21): runtime local de LLM, no un asistente de
# código — subcategory=ai-runtime (nueva), distinta de ai-cli/ai-agent.
tools_registry_register "ollama" \
    "name=Ollama" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding" "subcategory=local-models" "manager=curl-script" \
    "script=scripts/development/install_ollama.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# ngrok (Hito 28, 2026-07-21): repo APT oficial propio, distro/codename
# fijo 'bookworm' (mismo patrón que Slack/OnlyOffice).
tools_registry_register "ngrok" \
    "name=ngrok" "category=development" "subcategory=networking" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=ngrok" \
    "script=scripts/development/install_ngrok.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# SoapUI (Hito 29, 2026-07-21): instalador .sh tipo IzPack, mecanismo
# distinto a todo lo demás del catálogo — ver la advertencia de
# incertidumbre en el propio scripts/development/install_soapui.sh.
tools_registry_register "soapui" \
    "name=SoapUI" "category=development" "subcategory=api-clients" "classification=optional" "profiles=desktop,developer,workstation,full,coding" "manager=izpack-installer" \
    "script=scripts/development/install_soapui.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "openclaw" \
    "name=OpenClaw" "category=ai" "classification=optional" "profiles=cli,desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=curl-script" \
    "script=scripts/productivity/install_openclaw.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "hermes_agent" \
    "name=Hermes Agent" "category=ai" "classification=optional" "profiles=cli,desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=curl-script" \
    "script=scripts/productivity/install_hermes_agent.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Claude Desktop: manager=apt-vendor-repo (reutiliza la infraestructura
# existente, mismo patrón que Docker/VS Code/Cursor), no curl-script — sí
# tiene repo APT oficial propio. Cowork (KVM/disco/RAM) no se valida en
# el instalador, ver el propio script.
tools_registry_register "claude_desktop" \
    "name=Claude Desktop" "category=ai" "classification=optional" "profiles=desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=apt-vendor-repo" "packages=claude-desktop" \
    "script=scripts/productivity/install_claude_desktop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"
