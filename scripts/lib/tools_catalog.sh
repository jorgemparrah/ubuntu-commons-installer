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
    "name=cmatrix" "description=Efecto visual de terminal estilo Matrix, sin utilidad práctica más allá de lo decorativo" \
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
    "name=Ranger" "description=Gestor de archivos de terminal con vista en columnas al estilo Miller" \
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
    "name=Vim" "description=Editor de texto modal clásico de terminal" "category=editors" "subcategory=terminal-editors" "classification=optional" "profiles=cli,desktop,developer,workstation,full,editor" "manager=apt" "packages=vim" \
    "script=scripts/editors/install_vim.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=legacy"

tools_registry_register "terminator" \
    "name=Terminator" "description=Emulador de terminal con soporte para dividir la ventana en paneles" "category=system" "classification=optional" "profiles=full" "subcategory=terminals" "manager=apt" "packages=terminator" \
    "script=scripts/system/install_terminator.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "flameshot" \
    "name=Flameshot" "description=Herramienta de capturas de pantalla con anotaciones" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=flameshot" \
    "script=scripts/productivity/install_flameshot.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# ULauncher: manager=apt-vendor-repo (PPA propio, no repositorio oficial de
# Ubuntu — ver ADR 0027) en vez de manager=apt como el resto de los
# instaladores apt-simple migrados hasta ahora.
tools_registry_register "ulauncher" \
    "name=ULauncher" "description=Lanzador de aplicaciones tipo Spotlight/Albert para el escritorio" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=ulauncher" \
    "script=scripts/productivity/install_ulauncher.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "Development Tools" (ver ADR 0031/0035) —
# subcategory=cli-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "wget" \
    "name=wget" "description=Cliente de descarga de archivos por HTTP/FTP desde la línea de comandos" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=wget" \
    "script=scripts/system/install_wget.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "curl" \
    "name=curl" "description=Cliente de transferencia de datos por URL desde la línea de comandos" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=curl" \
    "script=scripts/system/install_curl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "git" \
    "name=Git" "description=Sistema de control de versiones distribuido" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=git" \
    "script=scripts/system/install_git.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "build_essential" \
    "name=build-essential" "description=Paquete meta con las herramientas de compilación básicas (gcc, make, etc.)" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=build-essential" \
    "script=scripts/system/install_build_essential.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "software_properties_common" \
    "name=software-properties-common" "description=Utilidades para gestionar repositorios y PPAs de APT" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=software-properties-common" \
    "script=scripts/system/install_software_properties_common.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "apt_transport_https" \
    "name=apt-transport-https" "description=Soporte para que APT descargue paquetes por HTTPS" "category=system" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "subcategory=cli-utils" "manager=apt" "packages=apt-transport-https" \
    "script=scripts/system/install_apt_transport_https.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gnupg2" \
    "name=GnuPG" "description=Herramienta de cifrado y firma digital (OpenPGP)" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=gnupg2" \
    "script=scripts/system/install_gnupg2.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Herramientas CLI (Hito 28, 2026-07-21): fzf/thefuck/jq (apt-simple),
# yq (snap oficial de Mike Farah — el paquete apt de Ubuntu es un
# programa DISTINTO e incompatible, ver el propio install_yq.sh).
tools_registry_register "fzf" \
    "name=fzf" "description=Buscador difuso ("fuzzy finder") de línea de comandos" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=fzf" \
    "script=scripts/system/install_fzf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "thefuck" \
    "name=thefuck" "description=Corrige automáticamente el último comando de terminal mal escrito" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=thefuck" \
    "script=scripts/system/install_thefuck.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "jq" \
    "name=jq" "description=Procesador de JSON en la línea de comandos" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=jq" \
    "script=scripts/system/install_jq.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yq" \
    "name=yq" "description=Procesador de YAML en la línea de comandos (equivalente a jq)" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=snap" "packages=yq" \
    "script=scripts/system/install_yq.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# HTTPie y xh (Hito 38, 2026-07-23): mismo grupo cli-utils. HTTPie
# apt-simple estándar. xh no está en apt/snap ni publica .deb — primer
# caso de manager=tarball-direct (tarball .tar.gz de GitHub Releases,
# ver la advertencia real documentada en el propio install_xh.sh).
tools_registry_register "httpie" \
    "name=HTTPie" "description=Cliente HTTP de línea de comandos con salida legible y coloreada" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=httpie" \
    "script=scripts/system/install_httpie.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "xh" \
    "name=xh" "description=Cliente HTTP de línea de comandos, reimplementación de HTTPie en Rust" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=archive-direct" \
    "script=scripts/system/install_xh.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# dust, duf, procs, zoxide, btop, tealdeer (Hito 39, 2026-07-23): mismo
# grupo cli-utils. dust vía deb-direct (paquete du-dust, sin chocar con
# el paquete "dust" de Debian, un juego infantil sin relación). procs
# vía archive-direct (segundo caso real de este mecanismo, ver
# install_procs.sh — .zip en vez de .tar.gz). duf/btop/zoxide/tealdeer
# apt-simple estándar; tealdeer instala el binario `tldr` (no confundir
# con el paquete `tldr` de Ubuntu, el cliente Haskell del mismo
# proyecto, deliberadamente NO usado).
tools_registry_register "dust" \
    "name=dust" "description=Reemplazo de 'du' que muestra el uso de disco en forma de árbol" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=deb-direct" "packages=du-dust" \
    "script=scripts/system/install_dust.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "duf" \
    "name=duf" "description=Reemplazo de 'df' con una salida más legible del uso de discos" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=duf" \
    "script=scripts/system/install_duf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "procs" \
    "name=procs" "description=Reemplazo de 'ps' para listar procesos con salida más legible" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=archive-direct" \
    "script=scripts/system/install_procs.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "zoxide" \
    "name=zoxide" "description=Reemplazo inteligente de 'cd' que aprende las rutas usadas con frecuencia" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=zoxide" \
    "script=scripts/system/install_zoxide.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "btop" \
    "name=btop" "description=Monitor de recursos del sistema (CPU/memoria/red/procesos) en la terminal" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=btop" \
    "script=scripts/system/install_btop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "tealdeer" \
    "name=tealdeer" "description=Cliente rápido (en Rust) de tldr: páginas de ayuda de comandos simplificadas" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=tealdeer" \
    "script=scripts/system/install_tealdeer.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "Multimedia Tools" (ver ADR 0031/0035) — ya
# vivían en category=multimedia. subcategory=capture/playback/codecs
# agregadas el 2026-07-22 (antes sin subcategoría), junto con GIMP y OBS
# Studio (movidos aquí desde system/gui-utils el mismo día, ver más abajo).
tools_registry_register "cheese" \
    "name=Cheese" "description=Aplicación de cámara web para tomar fotos y video" "category=multimedia" "subcategory=capture" "classification=optional" "profiles=desktop,workstation,full,creator" "manager=apt" "packages=cheese" \
    "script=scripts/system/install_cheese.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "v4l_utils" \
    "name=v4l-utils" "description=Utilidades de línea de comandos para dispositivos de video (Video4Linux)" "category=multimedia" "subcategory=capture" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=v4l-utils" \
    "script=scripts/system/install_v4l_utils.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "ubuntu_restricted_extras" \
    "name=ubuntu-restricted-extras" "description=Paquete meta con códecs multimedia y fuentes de uso restringido" "category=multimedia" "subcategory=codecs" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=ubuntu-restricted-extras" \
    "script=scripts/system/install_ubuntu_restricted_extras.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vlc" \
    "name=VLC" "description=Reproductor multimedia universal" "category=multimedia" "subcategory=playback" "classification=optional" "profiles=desktop,workstation,full,creator" "manager=apt" "packages=vlc" \
    "script=scripts/system/install_vlc.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Instaladores individuales ex "System Utilities" (ver ADR 0031/0035) —
# subcategory=gui-utils, ya no tienen agrupador (eliminado en ADR 0035)
tools_registry_register "meld" \
    "name=Meld" "description=Herramienta gráfica de comparación y fusión de archivos/carpetas" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=meld" \
    "script=scripts/system/install_meld.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "baobab" \
    "name=Baobab" "description=Analizador gráfico de uso de disco" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=baobab" \
    "script=scripts/system/install_baobab.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "gparted" \
    "name=GParted" "description=Editor gráfico de particiones de disco" "category=system" "classification=optional" "profiles=full" "subcategory=gui-utils" "manager=apt" "packages=gparted" \
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
    "name=DBeaver" "description=Cliente gráfico universal de bases de datos SQL/NoSQL" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=dbeaver-ce" \
    "script=scripts/development/install_dbeaver.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gitkraken" \
    "name=GitKraken" "description=Cliente gráfico de Git" "category=development" "subcategory=git-tools" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=gitkraken" \
    "script=scripts/development/install_gitkraken.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "insomnia" \
    "name=Insomnia" "description=Cliente gráfico para probar APIs REST/GraphQL" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=insomnia" \
    "script=scripts/development/install_insomnia.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "postman" \
    "name=Postman" "description=Cliente gráfico para probar y documentar APIs" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=postman" \
    "script=scripts/development/install_postman.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "gimp" \
    "name=GIMP" "description=Editor de imágenes raster (equivalente libre a Photoshop)" "category=multimedia" "classification=optional" "profiles=full" "subcategory=graphics" "manager=snap" "packages=gimp" \
    "script=scripts/system/install_gimp.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Inkscape y Krita (Hito 35, 2026-07-22): mismo grupo multimedia/graphics
# que GIMP (complementarios, no reemplazos — Inkscape es vectorial,
# Krita es pintura digital). Inkscape vía PPA oficial del propio equipo
# (ppa:inkscape.dev/stable, confirmado activo); Krita vía snap oficial de
# la Krita Foundation (cuenta verificada), sin --classic.
tools_registry_register "inkscape" \
    "name=Inkscape" "description=Editor de gráficos vectoriales" "category=multimedia" "classification=optional" "profiles=full" "subcategory=graphics" "manager=apt-vendor-repo" "packages=inkscape" \
    "script=scripts/system/install_inkscape.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "krita" \
    "name=Krita" "description=Aplicación de pintura digital e ilustración" "category=multimedia" "classification=optional" "profiles=full" "subcategory=graphics" "manager=snap" "packages=krita" \
    "script=scripts/system/install_krita.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# OBS Studio: manager=apt-vendor-repo (PPA oficial, ver ADR 0038) — migró
# de Snap (etiquetado "unofficial" por el propio OBS Project). Ya no
# depende de snapd, requires_manual_validation=no. category=multimedia/
# capture desde el 2026-07-22 (antes system/gui-utils — corrección de
# categorización a pedido del dueño del proyecto, junto con GIMP).
tools_registry_register "obs_studio" \
    "name=OBS Studio" "description=Software de grabación de pantalla y transmisión en vivo" "category=multimedia" "classification=optional" "profiles=full" "subcategory=capture" "manager=apt-vendor-repo" "packages=obs-studio" \
    "script=scripts/system/install_obs_studio.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "spotify" \
    "name=Spotify" "description=Cliente de streaming de música" "category=productivity" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=spotify" \
    "script=scripts/productivity/install_spotify.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "zoom" \
    "name=Zoom" "description=Cliente de videoconferencias" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=zoom-client" \
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
    "name=Telegram Desktop" "description=Cliente de escritorio de Telegram" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=telegram-desktop" \
    "script=scripts/productivity/install_telegram_desktop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "slack" \
    "name=Slack" "description=Cliente de escritorio de Slack" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=slack-desktop" \
    "script=scripts/productivity/install_slack.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "discord" \
    "name=Discord" "description=Cliente de escritorio de Discord" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=discord" \
    "script=scripts/productivity/install_discord.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Element y Signal Desktop (Hito 36, 2026-07-22): mismo grupo
# communication. Element vía apt-vendor-repo (clave ya lista +
# apt_vendor_repo_write_list, distro fija 'default'). Signal Desktop vía
# apt-vendor-repo combinando ambos sub-mecanismos (clave dearmorada +
# .sources ya armado) — ver la advertencia real documentada en el propio
# install_signal_desktop.sh sobre la ruta exacta del keyring.
tools_registry_register "element" \
    "name=Element" "description=Cliente de escritorio oficial del protocolo de mensajería Matrix" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=element-desktop" \
    "script=scripts/productivity/install_element.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "signal_desktop" \
    "name=Signal Desktop" "description=Cliente de escritorio de Signal Messenger" "category=productivity" "subcategory=communication" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=signal-desktop" \
    "script=scripts/productivity/install_signal_desktop.sh" \
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
    "name=LibreOffice" "description=Suite ofimática libre (procesador de texto, hoja de cálculo, presentaciones)" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=libreoffice" \
    "script=scripts/productivity/install_libreoffice.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "onlyoffice" \
    "name=OnlyOffice" "description=Suite ofimática con alta compatibilidad de formato con Microsoft Office" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=onlyoffice-desktopeditors" \
    "script=scripts/productivity/install_onlyoffice.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "obsidian" \
    "name=Obsidian" "description=Aplicación de notas en Markdown con vinculación entre notas (grafo de conocimiento)" "category=productivity" "subcategory=notes" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=obsidian" \
    "script=scripts/productivity/install_obsidian.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Joplin (Hito 36, 2026-07-22): mismo grupo notes que Obsidian —
# alternativa 100% FOSS (AGPL-3.0). manager=curl-script, pero
# check_status/uninstall propios (no la convención ~/.local/bin del
# resto del grupo): el script oficial instala en ~/.joplin/Joplin.AppImage,
# sin symlink en el PATH.
tools_registry_register "joplin" \
    "name=Joplin" "description=Aplicación de notas en Markdown 100% libre, alternativa a Obsidian" "category=productivity" "subcategory=notes" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=curl-script" \
    "script=scripts/productivity/install_joplin.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "keepassxc" \
    "name=KeePassXC" "description=Gestor de contraseñas libre con cifrado local" "category=productivity" "subcategory=security" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=keepassxc" \
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
    "name=Brave" "description=Navegador basado en Chromium con bloqueo de rastreadores integrado" "category=productivity" "subcategory=browsers" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=brave-browser" \
    "script=scripts/productivity/install_brave.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "chromium" \
    "name=Chromium" "description=Navegador de código abierto, base de Google Chrome" "category=productivity" "subcategory=browsers" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=chromium" \
    "script=scripts/productivity/install_chromium.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Misceláneos (Hito 29, 2026-07-21): LocalSend (deb-direct desde GitHub
# Releases, URL resuelta dinámicamente), Steam (apt-simple + arquitectura
# i386 habilitada explícitamente en install_tool), Okular (apt-simple).
# subcategory=file-sharing/gaming nuevas.
tools_registry_register "localsend" \
    "name=LocalSend" "description=Envío de archivos entre dispositivos en la misma red local, sin nube" "category=productivity" "subcategory=file-sharing" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=localsend_app" \
    "script=scripts/productivity/install_localsend.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "steam" \
    "name=Steam" "description=Plataforma de distribución de videojuegos de Valve" "category=productivity" "subcategory=gaming" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=steam-installer" \
    "script=scripts/productivity/install_steam.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Lutris y Heroic Games Launcher (Hito 37, 2026-07-22): mismo grupo
# gaming que Steam. Ambos vía deb-direct + github_release.sh (Lutris
# preferido sobre su propio PPA oficial porque la documentación de
# lutris.net recomienda el .deb de GitHub Releases; ambos verificados
# contra el release real, sin el problema de releases mixtos ya visto
# con Hoppscotch/DbGate).
tools_registry_register "lutris" \
    "name=Lutris" "description=Gestor de bibliotecas de juegos multi-plataforma (Wine/Proton/emuladores)" "category=productivity" "subcategory=gaming" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=lutris" \
    "script=scripts/productivity/install_lutris.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "heroic" \
    "name=Heroic Games Launcher" "description=Launcher libre para juegos de Epic Games Store, GOG y Amazon Games" "category=productivity" "subcategory=gaming" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=deb-direct" "packages=heroic" \
    "script=scripts/productivity/install_heroic.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "okular" \
    "name=Okular" "description=Visor y editor de documentos/PDF de KDE" "category=productivity" "subcategory=office" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=okular" \
    "script=scripts/productivity/install_okular.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo vendor-repo (Hito 11): manager=apt-vendor-repo, ver
# scripts/lib/apt_vendor_repo.sh. requires_manual_validation=no: los 3
# tienen prueba funcional real en CI (tests/docker/test_*_apt_repo.sh:
# C01/V01/D01), a diferencia del grupo Snap.
tools_registry_register "docker" \
    "name=Docker" "description=Motor de contenedores para empaquetar y ejecutar aplicaciones" "category=development" "subcategory=containers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin" \
    "script=scripts/development/install_docker.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "vscode" \
    "name=Visual Studio Code" "description=Editor de código de Microsoft con soporte de extensiones" "category=editors" "subcategory=gui-editors" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=code" \
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
    "name=VirtualBox" "description=Software de virtualización de máquinas virtuales de Oracle" "category=development" "subcategory=virtualization" "classification=optional" "profiles=developer,workstation,full,coding" "manager=apt-vendor-repo" \
    "script=scripts/development/install_virtualbox.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "cursor" \
    "name=Cursor AI IDE" "description=Editor de código basado en VS Code con asistencia de IA integrada" "category=ai" "subcategory=ai-ide" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=cursor" \
    "script=scripts/editors/install_cursor.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Antigravity IDE (Hito 16, 2026-07-21, ver ADR 0041): repo APT oficial de
# Google, no el tarball manual que se había investigado originalmente en
# ADR 0037 — distinto de "antigravity" (el CLI 'agy', category=development,
# ver más abajo), son dos productos con mecanismos separados.
tools_registry_register "antigravity_ide" \
    "name=Antigravity IDE" "description=IDE de Google con asistencia de IA integrada" "category=ai" "subcategory=ai-ide" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=antigravity" \
    "script=scripts/editors/install_antigravity_ide.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Grupo Mise (Hito 11): manager=mise, ver scripts/lib/runtime.sh (Hito 8).
# migration_status=migrated aquí significa "usa scripts/lib/installer_cli.sh"
# — la lógica de instalación en sí (scripts/lib/runtime.sh) no cambió,
# solo el dispatcher.
tools_registry_register "kubectl" \
    "name=kubectl" "description=Cliente de línea de comandos para administrar clústeres de Kubernetes" "category=development" "subcategory=containers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=kubectl" \
    "script=scripts/development/install_kubectl.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yarn" \
    "name=Yarn" "description=Gestor de paquetes para proyectos Node.js" "category=development" "subcategory=package-managers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=yarn" \
    "script=scripts/development/install_yarn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# pnpm: manager=mise igual que Yarn (Hito 42, ver ADR 0017, que ya
# contemplaba pnpm sin haberlo implementado hasta ahora).
tools_registry_register "pnpm" \
    "name=pnpm" "description=Gestor de paquetes para proyectos Node.js, alternativa rápida a npm/Yarn" "category=development" "subcategory=package-managers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=pnpm" \
    "script=scripts/development/install_pnpm.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# gh (GitHub CLI): manager=mise igual que kubectl/Yarn, aunque también está
# en el repositorio oficial de Ubuntu (universe) — decisión explícita del
# dueño del proyecto (ver ADR 0033 y ADR 0034, esta última corrige el
# manager=mise-tool propuesto originalmente en 0033 tras confirmar que
# kubectl/Yarn ya resuelven este mismo caso con manager=mise).
tools_registry_register "gh" \
    "name=GitHub CLI" "description=Cliente de línea de comandos oficial de GitHub" "category=development" "subcategory=git-tools" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=mise" "packages=gh" \
    "script=scripts/development/install_gh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo deb-directo (Hito 11): manager=deb-direct, ver
# scripts/lib/deb_direct.sh. Chrome es supported_arch=amd64 (ver ADR
# 0028); MongoDB Compass no publica un .deb multi-arch tampoco pero su
# instalador nunca implementó un chequeo de arquitectura propio (fuera de
# alcance de esta migración, ver docs/UBUNTU_COMPATIBILITY.md).
tools_registry_register "chrome" \
    "name=Google Chrome" "description=Navegador web de Google" "category=productivity" "subcategory=browsers" "classification=required" "profiles=minimal,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=deb-direct" "packages=google-chrome-stable" \
    "script=scripts/productivity/install_chrome.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "mongodb_compass" \
    "name=MongoDB Compass" "description=Cliente gráfico oficial para explorar y consultar bases de datos MongoDB" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=deb-direct" "packages=mongodb-compass" \
    "script=scripts/development/install_mongodb_compass.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo git-clone (Hito 11): manager=git-clone, ver scripts/lib/git_clone.sh.
# 'packages' se omite: no instalan un paquete propio con ese nombre, solo
# 'zsh' como dependencia compartida entre ambos.
tools_registry_register "oh_my_zsh" \
    "name=Oh My Zsh" "description=Framework de configuración y temas para el shell Zsh" "category=system" "classification=optional" "profiles=cli,full" "subcategory=shell-personalization" "manager=git-clone" \
    "script=scripts/system/install_oh_my_zsh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Powerlevel10k depende de Oh My Zsh (Hito 17, ver ADR 0042). Primer caso
# real del campo depends_on: si Oh My Zsh no está instalado, install_tool
# rechaza explícitamente en vez de instalarlo por su cuenta.
tools_registry_register "powerlevel10k" \
    "name=Powerlevel10k" "description=Tema visual rápido y personalizable para el prompt de Zsh" "category=system" "classification=optional" "profiles=cli,full" "subcategory=shell-personalization" "manager=git-clone" "depends_on=oh_my_zsh" \
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
    "name=System Updates" "description=Actualización de los paquetes del sistema vía APT" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/system/install_system_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "final_update" \
    "name=Final System Update" "description=Actualización final y limpieza de paquetes huérfanos, al cierre del aprovisionamiento" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/maintenance/install_final_update.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated" \
    "kind=maintenance"

tools_registry_register "kernel" \
    "name=Kernel & Headers" "description=Gestión del kernel de Linux y sus headers (incluye HWE)" "category=maintenance" "classification=required" "profiles=minimal,cli,desktop,developer,workstation,full,creator,productivity,coding,editor" "manager=apt" \
    "script=scripts/system/install_kernel.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated" \
    "kind=maintenance"

# Gestores de archivos de terminal (2026-07-20, subcategory=file-managers
# desde 2026-07-22 — antes vivían junto a los emuladores de terminal reales
# bajo subcategory=terminals, corregido a pedido del dueño del proyecto).
tools_registry_register "nnn" \
    "name=nnn" "description=Gestor de archivos de terminal minimalista y muy rápido" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=apt" "packages=nnn" \
    "script=scripts/system/install_nnn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "lf" \
    "name=lf" "description=Gestor de archivos de terminal inspirado en ranger, escrito en Go" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=apt" "packages=lf" \
    "script=scripts/system/install_lf.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "yazi" \
    "name=Yazi" "description=Gestor de archivos de terminal moderno con vista previa, escrito en Rust" "category=system" "classification=optional" "profiles=cli,full" "subcategory=file-managers" "manager=snap" "packages=yazi" \
    "script=scripts/system/install_yazi.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# manager=apt (mecanismo de fondo): la rama condicional PPA/repo oficial
# según versión de Ubuntu vive en el propio script, ver ADR 0032 — no se
# modela como un campo separado del catálogo.
tools_registry_register "ghostty" \
    "name=Ghostty" "description=Emulador de terminal moderno acelerado por GPU" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt" "packages=ghostty" \
    "script=scripts/system/install_ghostty.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "wezterm" \
    "name=WezTerm" "description=Emulador de terminal acelerado por GPU con multiplexor integrado" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt-vendor-repo" "packages=wezterm" \
    "script=scripts/system/install_wezterm.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Kitty y Alacritty (Hito 40, 2026-07-23): mismo grupo terminals que
# Ghostty/Terminator/WezTerm. Ambos apt-simple: el instalador oficial de
# Kitty (freshest, pero deja el binario sin symlink/desktop) y el PPA
# histórico de Alacritty (mmstick76, descontinuado desde 2021, sin
# soporte para 24.04+) quedan descartados, ver advertencias reales en
# cada script.
tools_registry_register "kitty" \
    "name=Kitty" "description=Emulador de terminal acelerado por GPU" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt" "packages=kitty" \
    "script=scripts/system/install_kitty.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "alacritty" \
    "name=Alacritty" "description=Emulador de terminal minimalista acelerado por GPU" "category=system" "classification=optional" "profiles=cli,full" "subcategory=terminals" "manager=apt" "packages=alacritty" \
    "script=scripts/system/install_alacritty.sh" \
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
    "name=Claude Code" "description=CLI de asistencia de código con IA de Anthropic" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_claude_code.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "codex_cli" \
    "name=Codex CLI" "description=CLI de asistencia de código con IA de OpenAI" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_codex_cli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "opencode" \
    "name=OpenCode" "description=CLI de asistencia de código con IA, de código abierto" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_opencode.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Antigravity: solo el CLI 'agy' (category=development/ai-cli). El
# IDE/Desktop queda diferido a propósito — sin apt/snap oficial, solo
# tarball manual sin checksum/firma descripta (ver ADR 0037).
tools_registry_register "antigravity" \
    "name=Antigravity CLI" "description=CLI de asistencia de código con IA de Google (comando 'agy')" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding,ai-cli" "subcategory=ai-cli" "manager=curl-script" \
    "script=scripts/development/install_antigravity.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Ollama (Hito 28, 2026-07-21): runtime local de LLM, no un asistente de
# código — subcategory=ai-runtime (nueva), distinta de ai-cli/ai-agent.
tools_registry_register "ollama" \
    "name=Ollama" "description=Runtime para correr modelos de lenguaje (LLM) de forma local" "category=ai" "classification=optional" "profiles=cli,developer,workstation,full,coding" "subcategory=local-models" "manager=curl-script" \
    "script=scripts/development/install_ollama.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# ngrok (Hito 28, 2026-07-21): repo APT oficial propio, distro/codename
# fijo 'bookworm' (mismo patrón que Slack/OnlyOffice).
# Recategorizado de category=development a category=system en el Hito 46
# (ver docs/ROADMAP.md): el alcance de subcategory=networking se amplía
# de "solo túneles de desarrollo" a redes/túneles en general (WireGuard,
# OpenVPN, Tailscale, Cloudflare Tunnel) — ngrok encaja mejor ahí que en
# development. El script permanece en scripts/development/install_ngrok.sh
# (no se mueve de directorio, mismo criterio ya usado con GIMP/OBS Studio
# al recategorizar a category=multimedia sin mover sus scripts).
tools_registry_register "ngrok" \
    "name=ngrok" "description=Túneles seguros para exponer servicios locales a internet" "category=system" "subcategory=networking" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=ngrok" \
    "script=scripts/development/install_ngrok.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# SoapUI (Hito 29, 2026-07-21): instalador .sh tipo IzPack, mecanismo
# distinto a todo lo demás del catálogo — ver la advertencia de
# incertidumbre en el propio scripts/development/install_soapui.sh.
tools_registry_register "soapui" \
    "name=SoapUI" "description=Herramienta de pruebas de servicios web SOAP/REST" "category=development" "subcategory=api-clients" "classification=optional" "profiles=desktop,developer,workstation,full,coding" "manager=izpack-installer" \
    "script=scripts/development/install_soapui.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Bruno y Hoppscotch (Hito 31, 2026-07-22): mismo grupo api-clients que
# Insomnia/Postman/SoapUI. Bruno vía snap oficial del propio autor
# (manager=snap, --classic). Hoppscotch vía deb-direct con resolución
# sobre la lista de releases (no solo 'releases/latest' — ver la
# advertencia real documentada en el propio install_hoppscotch.sh).
tools_registry_register "bruno" \
    "name=Bruno" "description=Cliente API git-native, local-first, alternativa a Postman/Insomnia" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=snap" "packages=bruno" \
    "script=scripts/development/install_bruno.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "hoppscotch" \
    "name=Hoppscotch" "description=Cliente API 100% libre y self-hosteable, alternativa a Postman" "category=development" "subcategory=api-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=deb-direct" "packages=hoppscotch" \
    "script=scripts/development/install_hoppscotch.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Beekeeper Studio y DbGate (Hito 32, 2026-07-22): mismo grupo db-clients
# que DBeaver/MongoDB Compass. Ambos vía deb-direct + github_release.sh
# (ver advertencias de mecanismo real documentadas en cada script).
tools_registry_register "beekeeper_studio" \
    "name=Beekeeper Studio" "description=Cliente SQL multi-motor, alternativa libre a DBeaver" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=deb-direct" "packages=beekeeper-studio" \
    "script=scripts/development/install_beekeeper_studio.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "dbgate" \
    "name=DbGate" "description=Cliente SQL/NoSQL multi-motor, alternativa libre a DBeaver" "category=development" "subcategory=db-clients" "classification=optional" "profiles=developer,workstation,full,coding" "manager=deb-direct" "packages=dbgate" \
    "script=scripts/development/install_dbgate.sh" \
    "supported_os=24.04,26.04" "supported_arch=amd64" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Podman, Lazygit y virt-manager (Hito 33, 2026-07-22): Podman en
# subcategory=containers (mismo grupo que Docker/kubectl, sin
# podman-docker para no chocar con Docker ya instalado); Lazygit en
# subcategory=git-tools (mismo grupo que GitHub CLI/GitKraken, el PPA
# histórico está descontinuado); virt-manager en subcategory=virtualization
# (mismo grupo que VirtualBox, apt-simple con múltiples paquetes y dos
# grupos del sistema, libvirt/kvm).
tools_registry_register "podman" \
    "name=Podman" "description=Motor de contenedores sin daemon y sin privilegios de root, alternativa a Docker" "category=development" "subcategory=containers" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt" "packages=podman" \
    "script=scripts/development/install_podman.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "lazygit" \
    "name=Lazygit" "description=Interfaz de terminal (TUI) para operar Git de forma visual" "category=development" "subcategory=git-tools" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt" "packages=lazygit" \
    "script=scripts/development/install_lazygit.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "virt_manager" \
    "name=virt-manager" "description=Interfaz gráfica para administrar máquinas virtuales QEMU/KVM" "category=development" "subcategory=virtualization" "classification=optional" "profiles=developer,workstation,full,coding" "manager=apt" "packages=virt-manager,qemu-kvm,libvirt-daemon-system,libvirt-clients,bridge-utils,cpu-checker" \
    "script=scripts/development/install_virt_manager.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# VSCodium y Neovim (Hito 34, 2026-07-22): VSCodium en subcategory=gui-editors
# (mismo grupo que VS Code, apt-vendor-repo con clave/`.sources` ya
# listos, mismo mecanismo que Brave/ngrok); Neovim en
# subcategory=terminal-editors (mismo grupo que Vim, apt-simple —
# complemento, no reemplazo).
tools_registry_register "vscodium" \
    "name=VSCodium" "description=Build de Visual Studio Code sin telemetría ni marca de Microsoft" "category=editors" "subcategory=gui-editors" "classification=optional" "profiles=desktop,developer,workstation,full,editor" "manager=apt-vendor-repo" "packages=codium" \
    "script=scripts/editors/install_vscodium.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "neovim" \
    "name=Neovim" "description=Fork moderno de Vim con soporte nativo de LSP" "category=editors" "subcategory=terminal-editors" "classification=optional" "profiles=cli,desktop,developer,workstation,full,editor" "manager=apt" "packages=neovim" \
    "script=scripts/editors/install_neovim.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "openclaw" \
    "name=OpenClaw" "description=Agente de IA de propósito general para el escritorio" "category=ai" "classification=optional" "profiles=cli,desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=curl-script" \
    "script=scripts/productivity/install_openclaw.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "hermes_agent" \
    "name=Hermes Agent" "description=Agente de IA de propósito general para el escritorio" "category=ai" "classification=optional" "profiles=cli,desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=curl-script" \
    "script=scripts/productivity/install_hermes_agent.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Claude Desktop: manager=apt-vendor-repo (reutiliza la infraestructura
# existente, mismo patrón que Docker/VS Code/Cursor), no curl-script — sí
# tiene repo APT oficial propio. Cowork (KVM/disco/RAM) no se valida en
# el instalador, ver el propio script.
tools_registry_register "claude_desktop" \
    "name=Claude Desktop" "description=Aplicación de escritorio de Claude (incluye el modo Cowork)" "category=ai" "classification=optional" "profiles=desktop,workstation,full,productivity" "subcategory=ai-assistants" "manager=apt-vendor-repo" "packages=claude-desktop" \
    "script=scripts/productivity/install_claude_desktop.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

# Grupo CLIs de nube/IaC (Hito 42, ver docs/ROADMAP.md): Terraform/OpenTofu
# (subcategory=iac) y AWS CLI/Azure CLI/Google Cloud CLI
# (subcategory=cloud-cli). Terraform se incluye pese a su licencia BUSL
# 1.1 desde 2023 (no aprobada por la OSI, pero de uso gratuito permitido
# salvo para competir con HashiCorp) — ver el encabezado de
# install_terraform.sh, mismo precedente que Obsidian/Discord/Slack/Steam
# en este catálogo. AWS CLI usa un mecanismo nuevo de un solo caso
# (manager=aws-cli-installer, ver install_awscli.sh): no tiene repo APT
# oficial propio, solo un .zip con su propio instalador embebido.
tools_registry_register "terraform" \
    "name=Terraform" "description=Herramienta de infraestructura como código de HashiCorp (licencia BUSL, no FOSS desde 2023)" "category=development" "subcategory=iac" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=terraform" \
    "script=scripts/development/install_terraform.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "opentofu" \
    "name=OpenTofu" "description=Fork FOSS de Terraform (MPL-2.0), mantenido por la Linux Foundation" "category=development" "subcategory=iac" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=tofu" \
    "script=scripts/development/install_opentofu.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "awscli" \
    "name=AWS CLI" "description=Cliente de línea de comandos oficial de Amazon Web Services" "category=development" "subcategory=cloud-cli" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=aws-cli-installer" \
    "script=scripts/development/install_awscli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "azure_cli" \
    "name=Azure CLI" "description=Cliente de línea de comandos oficial de Microsoft Azure" "category=development" "subcategory=cloud-cli" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=azure-cli" \
    "script=scripts/development/install_azure_cli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "google_cloud_cli" \
    "name=Google Cloud CLI" "description=Cliente de línea de comandos oficial de Google Cloud Platform" "category=development" "subcategory=cloud-cli" "classification=optional" "profiles=cli,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=google-cloud-cli" \
    "script=scripts/development/install_google_cloud_cli.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo multimedia de línea de comandos (Hito 43, ver docs/ROADMAP.md):
# ImageMagick y FFmpeg. Nueva subcategory=conversion, distinta de
# capture/codecs/graphics/playback ya existentes en category=multimedia.
tools_registry_register "imagemagick" \
    "name=ImageMagick" "description=Suite de manipulación de imágenes por línea de comandos" "category=multimedia" "subcategory=conversion" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=imagemagick" \
    "script=scripts/system/install_imagemagick.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "ffmpeg" \
    "name=FFmpeg" "description=Conversión y procesamiento de audio y video por línea de comandos" "category=multimedia" "subcategory=conversion" "classification=optional" "profiles=cli,desktop,workstation,full,creator" "manager=apt" "packages=ffmpeg" \
    "script=scripts/system/install_ffmpeg.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo seguridad/sincronización/transferencia (Hito 44, ver
# docs/ROADMAP.md): Bitwarden (subcategory=security, mismo grupo que
# KeePassXC), Syncthing y FileZilla (subcategory=file-sharing, mismo
# grupo que LocalSend).
tools_registry_register "bitwarden" \
    "name=Bitwarden" "description=Gestor de contraseñas en la nube con cliente de escritorio libre" "category=productivity" "subcategory=security" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=snap" "packages=bitwarden" \
    "script=scripts/productivity/install_bitwarden.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "syncthing" \
    "name=Syncthing" "description=Sincronización de archivos P2P entre dispositivos, sin nube" "category=productivity" "subcategory=file-sharing" "classification=optional" "profiles=cli,desktop,workstation,full,productivity" "manager=apt-vendor-repo" "packages=syncthing" \
    "script=scripts/productivity/install_syncthing.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "filezilla" \
    "name=FileZilla" "description=Cliente de transferencia de archivos FTP/SFTP" "category=productivity" "subcategory=file-sharing" "classification=optional" "profiles=desktop,workstation,full,productivity" "manager=apt" "packages=filezilla" \
    "script=scripts/productivity/install_filezilla.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

# Grupo CLI moderna: archivos y compresión (Hito 45, ver
# docs/ROADMAP.md): ripgrep, fd, bat, eza, tree, unzip/zip, rsync.
# subcategory=cli-utils, mismo grupo que duf/btop/zoxide/tealdeer.
tools_registry_register "ripgrep" \
    "name=ripgrep" "description=Búsqueda de texto recursiva, mucho más rápida que grep" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=ripgrep" \
    "script=scripts/system/install_ripgrep.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "fd" \
    "name=fd" "description=Reemplazo simple y rápido de find" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=fd-find" \
    "script=scripts/system/install_fd.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "bat" \
    "name=bat" "description=Reemplazo de cat con resaltado de sintaxis y números de línea" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=bat" \
    "script=scripts/system/install_bat.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "eza" \
    "name=eza" "description=Reemplazo moderno de ls, con colores y soporte de Git" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt-vendor-repo" "packages=eza" \
    "script=scripts/system/install_eza.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "tree" \
    "name=tree" "description=Listado de directorios en forma de árbol" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=tree" \
    "script=scripts/system/install_tree.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "zip_utils" \
    "name=unzip/zip" "description=Utilidades estándar de compresión y descompresión ZIP" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=unzip,zip" \
    "script=scripts/system/install_zip_utils.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "rsync" \
    "name=rsync" "description=Sincronización y transferencia eficiente de archivos" "category=system" "classification=optional" "profiles=cli,full" "subcategory=cli-utils" "manager=apt" "packages=rsync" \
    "script=scripts/system/install_rsync.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

# Grupo redes y túneles (Hito 46, ver docs/ROADMAP.md): WireGuard,
# OpenVPN, Tailscale, Cloudflare Tunnel. subcategory=networking, mismo
# grupo que ngrok (recategorizado en este mismo Hito de
# category=development a category=system, ver la nota junto a su
# entrada).
tools_registry_register "wireguard" \
    "name=WireGuard" "description=VPN moderna integrada en el kernel de Linux" "category=system" "subcategory=networking" "classification=optional" "profiles=cli,desktop,developer,workstation,full,coding" "manager=apt" "packages=wireguard" \
    "script=scripts/system/install_wireguard.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "openvpn" \
    "name=OpenVPN" "description=VPN tradicional basada en TLS" "category=system" "subcategory=networking" "classification=optional" "profiles=cli,desktop,developer,workstation,full,coding" "manager=apt" "packages=openvpn" \
    "script=scripts/system/install_openvpn.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "tailscale" \
    "name=Tailscale" "description=Mesh VPN basada en WireGuard, con coordinación centralizada" "category=system" "subcategory=networking" "classification=optional" "profiles=cli,desktop,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=tailscale" \
    "script=scripts/system/install_tailscale.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "cloudflared" \
    "name=Cloudflare Tunnel" "description=Túneles salientes sin abrir puertos, vía la red de Cloudflare" "category=system" "subcategory=networking" "classification=optional" "profiles=cli,desktop,developer,workstation,full,coding" "manager=apt-vendor-repo" "packages=cloudflared" \
    "script=scripts/system/install_cloudflared.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

# Grupo extras de terminal, visuales y decorativos (Hito 47, ver
# docs/ROADMAP.md): mismo grupo que cmatrix (subcategory=extras).
tools_registry_register "fortune" \
    "name=fortune" "description=Frases y galletas de la fortuna aleatorias en la terminal" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=fortune-mod" \
    "script=scripts/system/install_fortune.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "cowsay" \
    "name=cowsay" "description=Arte ASCII de una vaca (u otros personajes) diciendo una frase" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=cowsay" \
    "script=scripts/system/install_cowsay.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "lolcat" \
    "name=lolcat" "description=Colorea con un arcoíris la salida de otros comandos en la terminal" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=lolcat" \
    "script=scripts/system/install_lolcat.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "figlet" \
    "name=figlet" "description=Arte ASCII de texto grande a partir de una frase" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=figlet" \
    "script=scripts/system/install_figlet.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "toilet" \
    "name=toilet" "description=Arte ASCII de texto grande con más efectos y colores que figlet" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=toilet" \
    "script=scripts/system/install_toilet.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "xeyes" \
    "name=xeyes" "description=Un par de ojos que siguen el cursor del mouse por la pantalla" "category=system" "subcategory=extras" "classification=optional" "profiles=desktop,full" "manager=apt" "packages=x11-apps" \
    "script=scripts/system/install_xeyes.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=yes" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "cbonsai" \
    "name=cbonsai" "description=Árbol bonsai ASCII generado y animado en la terminal" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt" "packages=cbonsai" \
    "script=scripts/system/install_cbonsai.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=no" "migration_status=migrated"

tools_registry_register "fastfetch" \
    "name=fastfetch" "description=Información del sistema con arte ASCII, sucesor activo de neofetch" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=apt-vendor-repo" "packages=fastfetch" \
    "script=scripts/system/install_fastfetch.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "pipes_sh" \
    "name=pipes.sh" "description=Salvapantallas de terminal de tuberías animadas" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=git-clone" \
    "script=scripts/system/install_pipes_sh.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"

tools_registry_register "pokemon_colorscripts" \
    "name=pokemon-colorscripts" "description=Arte ASCII de Pokémon coloreado en la terminal" "category=system" "subcategory=extras" "classification=optional" "profiles=cli,full" "manager=git-clone" \
    "script=scripts/system/install_pokemon_colorscripts.sh" \
    "supported_os=24.04,26.04" "supported_arch=any" \
    "requires_gui=no" "requires_manual_validation=yes" "migration_status=migrated"
