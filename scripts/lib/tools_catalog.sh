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
# los 14 instaladores individuales resultantes más sus 3 agrupadores
# delgados. Un agrupador se distingue con el campo no-esquemático
# `kind=group` y `members=<ids separados por coma>` (tools_registry.sh no
# fuerza ningún esquema, ver ADR 0030) — sin esto, un agrupador se vería
# igual que una herramienta real con `packages` de varios elementos, una
# ficción que ADR 0031 decidió evitar.
#
# Agregar el resto de instaladores ya migrados (terminator, flameshot,
# vim) y los de fases futuras del Hito 11 es trabajo posterior, no de esta
# fase.
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
    "name=Terminator" "category=system" "manager=apt" "packages=terminator" \
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

# Instaladores individuales de "Development Tools" (ver ADR 0031)
tools_registry_register "wget" \
    "name=wget" "category=system" "manager=apt" "packages=wget" \
    "script=scripts/system/install_wget.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "curl" \
    "name=curl" "category=system" "manager=apt" "packages=curl" \
    "script=scripts/system/install_curl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "git" \
    "name=Git" "category=system" "manager=apt" "packages=git" \
    "script=scripts/system/install_git.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "build_essential" \
    "name=build-essential" "category=system" "manager=apt" "packages=build-essential" \
    "script=scripts/system/install_build_essential.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "software_properties_common" \
    "name=software-properties-common" "category=system" "manager=apt" "packages=software-properties-common" \
    "script=scripts/system/install_software_properties_common.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "apt_transport_https" \
    "name=apt-transport-https" "category=system" "manager=apt" "packages=apt-transport-https" \
    "script=scripts/system/install_apt_transport_https.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gnupg2" \
    "name=GnuPG" "category=system" "manager=apt" "packages=gnupg2" \
    "script=scripts/system/install_gnupg2.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "development_tools_group" \
    "name=Development Tools (agrupador)" "category=system" "manager=apt" \
    "script=scripts/system/install_development_tools.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=group" "members=wget,curl,git,build_essential,software_properties_common,apt_transport_https,gnupg2"

# Instaladores individuales de "Multimedia Tools" (ver ADR 0031)
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

tools_registry_register "multimedia_group" \
    "name=Multimedia Tools (agrupador)" "category=multimedia" "manager=apt" \
    "script=scripts/system/install_multimedia.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=group" "members=cheese,v4l_utils,ubuntu_restricted_extras,vlc"

# Instaladores individuales de "System Utilities" (ver ADR 0031)
tools_registry_register "meld" \
    "name=Meld" "category=system" "manager=apt" "packages=meld" \
    "script=scripts/system/install_meld.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "baobab" \
    "name=Baobab" "category=system" "manager=apt" "packages=baobab" \
    "script=scripts/system/install_baobab.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gparted" \
    "name=GParted" "category=system" "manager=apt" "packages=gparted" \
    "script=scripts/system/install_gparted.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "system_utils_group" \
    "name=System Utilities (agrupador)" "category=system" "manager=apt" \
    "script=scripts/system/install_system_utils.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=group" "members=meld,baobab,gparted"

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
    "name=GIMP" "category=system" "manager=snap" "packages=gimp" \
    "script=scripts/system/install_gimp.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "obs_studio" \
    "name=OBS Studio" "category=system" "manager=snap" "packages=obs-studio" \
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
