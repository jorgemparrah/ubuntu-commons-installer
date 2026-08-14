#!/usr/bin/env bash
# scripts/lib/apt_sources.sh
#
# Detección y limpieza de repositorios APT rotos.
#
# Nace de la primera ejecución real del instalador (2026-08-14, ver
# docs/ROADMAP.md Hito 19): dos repositorios de terceros mal configurados
# —uno con la clave GPG en un formato que APT ignora, otro sin paquetes
# para esta versión de Ubuntu— hicieron que `apt-get update` devolviera
# error de forma permanente. Como todos los instaladores APT dependen de
# ese comando, el instalador completo quedó inutilizable: hasta `cmatrix`,
# que viene de los repositorios de Ubuntu, dejó de poder instalarse.
#
# Arreglar los instaladores culpables evita volver a crear el problema,
# pero no limpia las máquinas donde ya quedó. Esto es lo segundo.
#
# Política de seguridad (AGENT.md §2, §11 y §16): NUNCA se borra un
# archivo de repositorio. Se respalda primero y después se **deshabilita**
# renombrándolo a `.disabled`, extensión que APT no lee. Revertirlo es
# renombrar de vuelta, y el original queda además en el backup.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md).

if [[ "${UCI_APT_SOURCES_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_APT_SOURCES_SH_LOADED=1

UCI_APT_SOURCES_DIR="${UCI_APT_SOURCES_DIR:-/etc/apt/sources.list.d}"
UCI_APT_SOURCES_MAIN="${UCI_APT_SOURCES_MAIN:-/etc/apt/sources.list}"

# apt_sources_update_output
# Corre `apt-get update` y devuelve TODA su salida (stdout+stderr) por
# stdout, sin fallar aunque el comando devuelva error — que es justamente
# el caso que interesa analizar.
apt_sources_update_output() {
    sudo apt-get update 2>&1 || true
}

# apt_sources_broken_uris <archivo_con_la_salida_de_apt>
# Extrae las URIs de los repositorios que fallaron, una por línea, sin
# duplicados.
#
# Se parsean las líneas 'Err:<n> <uri> ...' en vez de los mensajes 'E:'
# porque el prefijo 'Err:' NO se traduce: los mensajes largos sí (en la
# corrida real venían en español, "no tiene un fichero de Publicación"),
# y depender de ellos ataría la detección al idioma del sistema.
apt_sources_broken_uris() {
    local output_file="$1"

    [[ -f "${output_file}" ]] || return 0

    grep -E '^Err:[0-9]+[[:space:]]+' "${output_file}" 2>/dev/null \
        | awk '{print $2}' \
        | grep -E '^[a-z+]+://' \
        | sort -u
}

# apt_sources_files_for_uri <uri>
# Archivos de configuración de APT que declaran esa URI. Puede devolver
# más de uno (o ninguno, si el repositorio vino de otro lado).
apt_sources_files_for_uri() {
    local uri="$1"
    local -a candidates=()

    if [[ -d "${UCI_APT_SOURCES_DIR}" ]]; then
        while IFS= read -r file; do
            candidates+=("${file}")
        done < <(find "${UCI_APT_SOURCES_DIR}" -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null | sort)
    fi
    if [[ -f "${UCI_APT_SOURCES_MAIN}" ]]; then
        candidates+=("${UCI_APT_SOURCES_MAIN}")
    fi

    local file
    for file in "${candidates[@]:-}"; do
        [[ -n "${file}" ]] || continue
        # -F: la URI es un literal, no una expresión regular (trae '/' y
        # puede traer '.', '+' y otros metacaracteres).
        if grep -qF -- "${uri}" "${file}" 2>/dev/null; then
            echo "${file}"
        fi
    done
}

# apt_sources_config_files
# Todos los archivos de configuración de repositorios de APT.
apt_sources_config_files() {
    if [[ -d "${UCI_APT_SOURCES_DIR}" ]]; then
        find "${UCI_APT_SOURCES_DIR}" -maxdepth 1 -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null | sort
    fi
    [[ -f "${UCI_APT_SOURCES_MAIN}" ]] && echo "${UCI_APT_SOURCES_MAIN}"
    return 0
}

# apt_sources_keyring_problems
# Revisión ESTÁTICA (sin red, sin sudo, sin tocar nada) de los keyrings
# referenciados por 'signed-by=' o 'Signed-By:'. Imprime una línea
# 'tipo|archivo_de_repo|keyring|detalle' por problema.
#
# Detecta las dos formas en que un repositorio queda inutilizable en
# silencio, ambas vistas de verdad en la ejecución del 2026-08-14:
#
#   armored-como-gpg : la clave está en ASCII armor pero el archivo se
#                      llama '.gpg'. APT decide el formato por la
#                      extensión, así que la IGNORA ("the file has an
#                      unsupported filetype") y el repositorio pasa a
#                      estar sin firmar. Fue exactamente el caso de ngrok.
#   keyring-ausente  : 'signed-by=' apunta a un archivo que no existe.
#
# Ninguno de los dos da un error entendible hasta que 'apt-get update'
# falla, y ahí el mensaje culpa al repositorio, no al keyring.
apt_sources_keyring_problems() {
    local file keyring
    while IFS= read -r file; do
        [[ -n "${file}" ]] || continue
        while IFS= read -r keyring; do
            [[ -n "${keyring}" ]] || continue

            # 'Signed-By:' puede traer la clave EMBEBIDA en línea en vez de
            # una ruta — es lo que hace 'add-apt-repository' con los PPA de
            # Launchpad, que escriben literalmente
            # 'Signed-By: -----BEGIN PGP PUBLIC KEY BLOCK-----' seguido del
            # bloque indentado. Es una configuración válida y no hay ningún
            # archivo que revisar, así que se ignora.
            #
            # Sin este filtro se reportaba '-----BEGIN' como un "keyring
            # ausente": falso positivo real visto en la máquina del dueño
            # del proyecto, donde los PPA de ULauncher y OBS Studio
            # aparecían como problemas inexistentes.
            if [[ "${keyring}" != /* ]]; then
                continue
            fi

            if [[ ! -e "${keyring}" ]]; then
                echo "keyring-ausente|${file}|${keyring}|el archivo referenciado no existe"
                continue
            fi

            if [[ "${keyring}" == *.gpg ]] && head -c 40 "${keyring}" 2>/dev/null | grep -q "BEGIN PGP PUBLIC KEY"; then
                echo "armored-como-gpg|${file}|${keyring}|clave en ASCII armor con extensión .gpg; APT la ignora (renombrar a .asc o desarmar con 'gpg --dearmor')"
            fi
        done < <(grep -ohE '(signed-by=|Signed-By:[[:space:]]*)[^][:space:]]+' "${file}" 2>/dev/null \
                    | sed -E 's/^(signed-by=|Signed-By:[[:space:]]*)//' | sort -u)
    done < <(apt_sources_config_files)
    return 0
}

# apt_sources_backup_file <archivo> <directorio_de_backup>
# Copia el archivo al backup preservando su ruta absoluta debajo de
# <directorio_de_backup>/system/, para que se vea de dónde salió.
apt_sources_backup_file() {
    local file="$1" backup_dir="$2"
    local dest="${backup_dir}/system${file}"

    sudo mkdir -p "$(dirname "${dest}")"
    sudo cp -a "${file}" "${dest}"
    echo "${dest}"
}

# apt_sources_disable_file <archivo>
# Deshabilita el repositorio renombrando a '<archivo>.disabled'. APT solo
# lee '.list' y '.sources', así que deja de tenerlo en cuenta sin que se
# pierda nada.
#
# El archivo principal /etc/apt/sources.list NUNCA se toca: contiene los
# repositorios base de Ubuntu y deshabilitarlo entero dejaría la máquina
# sin poder instalar nada.
apt_sources_disable_file() {
    local file="$1"

    if [[ "${file}" == "${UCI_APT_SOURCES_MAIN}" ]]; then
        echo "Se omite ${file}: es el archivo principal de APT y deshabilitarlo dejaría el sistema sin repositorios base. Corregilo a mano." >&2
        return 1
    fi

    sudo mv "${file}" "${file}.disabled"
    echo "${file}.disabled"
}
