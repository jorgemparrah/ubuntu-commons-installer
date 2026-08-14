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
        apt_update || true
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

# apt_vendor_repo_fetch_file_plain <url> <dest_path>
# Descarga <url> a un archivo temporal (nunca directo a <dest_path>) y
# recién si el contenido no quedó vacío lo instala de forma atómica con
# 'sudo install' — mismo patrón en dos pasos que
# apt_vendor_repo_fetch_key_dearmored (descargar a un temporal propio,
# verificar, e instalar recién ahí), en vez de escribir directo al
# destino final vía 'curl -o': evita dejar un archivo parcial en
# <dest_path> si la descarga se corta a mitad de camino, y hace que el
# paso de instalación sea el único que toca la ruta real del sistema
# (mismo criterio ya aplicado en tests/test_virtualbox_installer.sh:
# mockear ese paso, no la descarga en sí). Sirve tanto para claves ya
# listas para 'signed-by' (ver apt_vendor_repo_fetch_key_plain, debajo)
# como para archivos de repositorio completos en formato DEB822
# (`.sources`) que un proveedor publica ya armados, sin que este proyecto
# deba construir una línea 'deb [...]' a mano (primer caso real: Brave,
# Hito 27, ver scripts/productivity/install_brave.sh).
apt_vendor_repo_fetch_file_plain() {
    local url="$1" dest_path="$2"
    local tmp_file
    tmp_file="$(mktemp)"

    if ! curl -fsSL "${url}" -o "${tmp_file}"; then
        echo "No se pudo descargar ${url}" >&2
        rm -f "${tmp_file}"
        return 1
    fi
    if [[ ! -s "${tmp_file}" ]]; then
        echo "El archivo descargado desde ${url} quedó vacío; abortando" >&2
        rm -f "${tmp_file}"
        return 1
    fi

    sudo mkdir -p "$(dirname "${dest_path}")"
    sudo install -D -o root -g root -m 644 "${tmp_file}" "${dest_path}"
    rm -f "${tmp_file}"
}

# apt_vendor_repo_fetch_key_plain <url> <keyring_path>
# Para claves que YA vienen listas para usar como 'signed-by' sin pasar
# por 'gpg --dearmor' (ej. la clave de Docker, publicada en formato
# ASCII-armored directamente utilizable).
apt_vendor_repo_fetch_key_plain() {
    apt_vendor_repo_fetch_file_plain "$1" "$2"
}

# apt_vendor_repo_write_list <list_path> <línea 'deb [...] ...'>
apt_vendor_repo_write_list() {
    local list_path="$1" line="$2"
    echo "${line}" | sudo tee "${list_path}" > /dev/null
}

# apt_vendor_repo_suite_available <repo_url> <suite>
# ¿El proveedor publica realmente esa suite/release? Devuelve 0 si el
# archivo Release responde, 1 si no.
#
# Existe por un hallazgo de la primera ejecución real (2026-08-14, ver
# docs/ROADMAP.md Hito 19): en Ubuntu 26.04 el instalador de Azure CLI
# escribía un repositorio con 'Suites: resolute', pero Microsoft todavía
# no publica para ese release. El resultado era un 404 permanente que
# hacía fallar 'apt-get update' para TODO el sistema, degradando a todos
# los demás instaladores — un proveedor rezagado rompía la máquina entera.
#
# Comprobar antes de escribir el archivo permite fallar limpio y no dejar
# nada roto atrás. Soporta tanto repositorios normales (dists/<suite>/)
# como repositorios planos (suite "/").
apt_vendor_repo_suite_available() {
    local repo_url="$1" suite="$2"
    local base="${repo_url%/}"
    local release_url

    if [[ "${suite}" == "/" ]]; then
        release_url="${base}/Release"
    else
        release_url="${base}/dists/${suite}/Release"
    fi

    curl -fsS --head --max-time 20 "${release_url}" > /dev/null 2>&1
}
