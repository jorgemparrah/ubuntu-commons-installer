#!/usr/bin/env bash
# scripts/lib/nerd_font.sh
#
# Helper compartido para instalar la Nerd Font MesloLGS NF (Hito 54, ver
# docs/ROADMAP.md). Hermano de apt.sh/snap.sh/flatpak.sh/git_clone.sh,
# pero para un paso de CONFIGURACIÓN post-instalación (el 7° verbo
# `configure` de ADR 0042), no para instalar una herramienta.
#
# Dos consumidores reales desde el inicio — `install_powerlevel10k.sh` y
# `install_starship.sh` — con lógica idéntica: por eso se extrae la
# biblioteca de entrada en vez de duplicar y esperar (criterio de ADR
# 0032, mismo caso que flatpak.sh, que también nació con dos casos).
#
# Por qué MesloLGS NF y no otra: es la fuente que el propio proyecto
# Powerlevel10k recomienda oficialmente y publica en su repositorio de
# medios (`romkatv/powerlevel10k-media`). Starship no impone una fuente
# concreta —solo pide "una Nerd Font"— así que reutilizar la misma evita
# instalar dos familias distintas para el mismo fin.
#
# Alcance deliberado: instala la fuente y refresca el cache. NO configura
# ningún emulador de terminal para que la use — ver la nota extensa en
# `nerd_font_terminal_hint`.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El
# script que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_NERD_FONT_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_NERD_FONT_SH_LOADED=1

UCI_NERD_FONT_BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

# Los cuatro estilos que documenta oficialmente Powerlevel10k. Se
# instalan los cuatro: con solo Regular, la terminal sintetiza negrita e
# itálica deformando los glifos de los íconos.
UCI_NERD_FONT_FILES=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

# nerd_font_dir <home_dir>
# Ruta estándar de fuentes por usuario (XDG). No se instala a nivel de
# sistema (/usr/local/share/fonts): una fuente para el prompt del shell
# es preferencia del usuario, no configuración de la máquina, y así no
# requiere sudo.
nerd_font_dir() {
    local home_dir="$1"
    echo "${home_dir}/.local/share/fonts"
}

# nerd_font_installed <home_dir>
# 0 si los CUATRO archivos están presentes. Se exige el set completo a
# propósito: una instalación a medias (por ejemplo, una descarga cortada)
# debe poder repararse volviendo a correr `configure`, no darse por
# buena.
nerd_font_installed() {
    local home_dir="$1"
    local dir file
    dir="$(nerd_font_dir "${home_dir}")"

    for file in "${UCI_NERD_FONT_FILES[@]}"; do
        [[ -f "${dir}/${file}" ]] || return 1
    done
    return 0
}

# nerd_font_install <home_dir>
# Descarga los cuatro estilos y refresca el cache de fuentes.
# Idempotente: si ya están los cuatro, no descarga nada (mismo criterio
# que configure_tool() de Flameshot, que no duplica el atajo si ya
# existe).
#
# Cada archivo se descarga a un temporal y recién ahí se mueve a su
# destino: evita dejar un .ttf parcial si la descarga se corta a mitad
# de camino (mismo patrón en dos pasos que
# apt_vendor_repo_fetch_file_plain).
nerd_font_install() {
    local home_dir="$1"
    local dir file url tmp_file

    if nerd_font_installed "${home_dir}"; then
        echo "MesloLGS NF ya está instalada; no se vuelve a descargar."
        return 0
    fi

    dir="$(nerd_font_dir "${home_dir}")"
    mkdir -p "${dir}"

    for file in "${UCI_NERD_FONT_FILES[@]}"; do
        if [[ -f "${dir}/${file}" ]]; then
            continue
        fi

        # El nombre lleva espacios: se codifican para la URL, pero el
        # archivo en disco conserva el nombre original (fontconfig
        # identifica la familia por los metadatos del .ttf, no por el
        # nombre, pero mantenerlo igual al oficial evita confusión).
        url="${UCI_NERD_FONT_BASE_URL}/${file// /%20}"
        tmp_file="$(mktemp)"

        if ! curl -fsSL "${url}" -o "${tmp_file}"; then
            echo "No se pudo descargar la fuente desde ${url}" >&2
            rm -f "${tmp_file}"
            return 1
        fi
        if [[ ! -s "${tmp_file}" ]]; then
            echo "La fuente descargada desde ${url} quedó vacía; abortando" >&2
            rm -f "${tmp_file}"
            return 1
        fi

        mv "${tmp_file}" "${dir}/${file}"
        chmod 644 "${dir}/${file}"
    done

    # Sin refrescar el cache, las aplicaciones ya abiertas (y a veces las
    # nuevas) no ven la fuente. Se guarda con 'command -v': en un
    # contenedor mínimo puede no estar fontconfig, y eso no debe hacer
    # fallar la instalación de los archivos, que ya ocurrió.
    if command -v fc-cache &> /dev/null; then
        fc-cache -f "${dir}" > /dev/null
    else
        echo "Advertencia: 'fc-cache' no está disponible; la fuente quedó instalada pero el cache no se refrescó." >&2
    fi
}

# nerd_font_uninstall <home_dir>
# Elimina solo los archivos que este proyecto instaló, nunca el
# directorio de fuentes completo (puede tener fuentes del usuario).
nerd_font_uninstall() {
    local home_dir="$1"
    local dir file
    dir="$(nerd_font_dir "${home_dir}")"

    for file in "${UCI_NERD_FONT_FILES[@]}"; do
        rm -f "${dir}/${file}"
    done

    if command -v fc-cache &> /dev/null; then
        fc-cache -f "${dir}" > /dev/null 2>&1 || true
    fi
}

# nerd_font_terminal_hint
# Mensaje que explica el paso manual que queda.
#
# Configurar el emulador de terminal para que USE la fuente queda
# deliberadamente FUERA DE ALCANCE, misma decisión que tomó Flameshot
# (Hito 17): allí se automatizó solo lo que tenía una API estándar
# (`gsettings` para el atajo de GNOME) y no se tocó la configuración de
# aplicaciones de terceros. Acá no existe un equivalente: cada terminal
# del catálogo guarda su fuente en un formato propio —Terminator en
# `~/.config/terminator/config` (INI), Ghostty y Alacritty en archivos
# propios (TOML/KDL), WezTerm en Lua, GNOME Terminal en dconf, Kitty en
# `kitty.conf`— y varios ni siquiera se instalan necesariamente en la
# misma máquina. Automatizar eso significaría parsear y reescribir la
# configuración de hasta ocho aplicaciones de terceros, con alto riesgo
# de romper ajustes del usuario (AGENT.md §17: la configuración le
# pertenece al usuario) y beneficio marginal frente a un cambio manual
# de una sola vez.
nerd_font_terminal_hint() {
    echo "Falta un paso manual: configurá tu emulador de terminal para usar la fuente 'MesloLGS NF'."
    echo "Cada terminal guarda esa preferencia en su propio formato, así que este instalador no la toca (ver scripts/lib/nerd_font.sh)."
}
