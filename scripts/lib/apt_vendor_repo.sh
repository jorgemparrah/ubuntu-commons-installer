#!/usr/bin/env bash
# scripts/lib/apt_vendor_repo.sh
#
# Helpers compartidos para instaladores que agregan su propio repositorio
# APT oficial de proveedor (Hito 11, grupo vendor-repo: Docker, VS Code,
# Cursor). Hermano de scripts/lib/apt.sh/scripts/lib/snap.sh para este
# mecanismo: centraliza la descarga/verificación de la clave GPG y la
# escritura del archivo .list, que los 3 instaladores repetían casi línea
# por línea (comprobación de keyring vacío tras una descarga fallida en
# silencio, mkdir -p del directorio de keyrings) — ver docs/UBUNTU_COMPATIBILITY.md.
#
# No decide DÓNDE va cada keyring/list ni qué paquetes instalar: eso sigue
# siendo responsabilidad de cada instalador. Por ejemplo, Cursor necesita
# escribir su keyring en una ruta específica que el postinst de su propio
# paquete espera (ver scripts/editors/install_cursor.sh) — esta biblioteca
# no le impone ninguna ruta.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_APT_VENDOR_REPO_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_APT_VENDOR_REPO_SH_LOADED=1

# apt_vendor_repo_ensure_gnupg
# 'gpg --dearmor' requiere el paquete gnupg; no se puede asumir presente.
apt_vendor_repo_ensure_gnupg() {
    if ! command -v gpg &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y gnupg
    fi
}

# apt_vendor_repo_fetch_key_dearmored <url> <keyring_path>
# Descarga la clave GPG en <url> y la convierte a formato binario
# ('gpg --dearmor') en <keyring_path>. Verifica explícitamente que el
# archivo resultante no quede vacío: una descarga o conversión fallida en
# silencio dejaría un keyring vacío, y el error real (NO_PUBKEY) recién
# aparecería mucho después, en 'apt update' (hallazgo real de este
# proyecto).
apt_vendor_repo_fetch_key_dearmored() {
    local url="$1" keyring_path="$2"
    local tmp_keyring
    tmp_keyring="$(mktemp)"

    if ! curl -fsSL "${url}" | gpg --dearmor > "${tmp_keyring}"; then
        echo "No se pudo descargar/convertir la clave GPG desde ${url}" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi
    if [[ ! -s "${tmp_keyring}" ]]; then
        echo "El keyring descargado desde ${url} quedó vacío tras la descarga; abortando" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi

    sudo mkdir -p "$(dirname "${keyring_path}")"
    sudo install -D -o root -g root -m 644 "${tmp_keyring}" "${keyring_path}"
    rm -f "${tmp_keyring}"
}

# apt_vendor_repo_fetch_key_plain <url> <keyring_path>
# Para claves que YA vienen listas para usar como 'signed-by' sin pasar
# por 'gpg --dearmor' (ej. la clave de Docker, publicada en formato
# ASCII-armored directamente utilizable).
apt_vendor_repo_fetch_key_plain() {
    local url="$1" keyring_path="$2"

    sudo mkdir -p "$(dirname "${keyring_path}")"
    if ! sudo curl -fsSL "${url}" -o "${keyring_path}"; then
        echo "No se pudo descargar la clave GPG desde ${url}" >&2
        return 1
    fi
    if [[ ! -s "${keyring_path}" ]]; then
        echo "El keyring descargado desde ${url} quedó vacío; abortando" >&2
        return 1
    fi
    sudo chmod a+r "${keyring_path}"
}

# apt_vendor_repo_write_list <list_path> <línea 'deb [...] ...'>
apt_vendor_repo_write_list() {
    local list_path="$1" line="$2"
    echo "${line}" | sudo tee "${list_path}" > /dev/null
}
