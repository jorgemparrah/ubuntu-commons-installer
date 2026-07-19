#!/usr/bin/env bash
# scripts/lib/apt.sh
#
# Helpers APT compartidos para instaladores (Hito 11, Fase 1 — ver
# docs/ROADMAP.md y docs/adr/0029-contrato-completo-de-instalador-referencia.md).
# Centraliza la pregunta "¿está este paquete realmente instalado?" en un
# solo lugar. Antes, varios instaladores respondían esa pregunta de forma
# distinta y frágil:
#   - `dpkg -s "$pkg"` devuelve éxito incluso para un paquete que quedó en
#     estado residual "config-files" tras un `apt remove` sin purgar (ver
#     docs/UBUNTU_COMPATIBILITY.md, docs/TECHNICAL_REVIEW.md hallazgo A1).
#   - `dpkg -l | grep -q "patrón.*paquete"` sobre la lista COMPLETA de
#     paquetes instalados: si `grep -q` encuentra la coincidencia temprano
#     y cierra su entrada mientras `dpkg -l` todavía escribe, el productor
#     recibe SIGPIPE — bajo `pipefail`, eso hace que el pipeline completo
#     devuelva un código de salida ≠0 aunque la coincidencia sí se haya
#     encontrado (bug real encontrado en scripts/development/install_docker.sh).
#
# Este módulo evita ambos: consulta `dpkg -l` para el paquete puntual
# (una o pocas líneas de salida, nunca la lista completa) y exige el
# estado exacto `ii` (instalado y configurado), nunca un estado residual
# como `rc` (removido, configuración remanente).
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_APT_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_APT_SH_LOADED=1

# apt_package_installed <paquete>
# 0 si el paquete está realmente instalado (dpkg -l reporta estado `ii`
# para ESE paquete exacto); 1 en cualquier otro caso (no instalado, estado
# residual `rc`, o dpkg no lo conoce). No falla el proceso si dpkg no
# encuentra el paquete: esa consulta en sí puede salir con código ≠0
# ("no packages found matching"), así que su stderr se descarta y su
# resultado se interpreta como "no instalado", nunca como un error fatal.
apt_package_installed() {
    local package="$1"
    dpkg -l "${package}" 2>/dev/null | grep -q '^ii'
}

# apt_all_packages_installed <paquete...>
# 0 solo si TODOS los paquetes dados están instalados (ver
# apt_package_installed). Se detiene en el primero que falte.
apt_all_packages_installed() {
    local package
    for package in "$@"; do
        apt_package_installed "${package}" || return 1
    done
    return 0
}

# apt_install_packages <paquete...>
# `apt-get update` + `apt-get install -y` de todos los paquetes dados.
# Los argumentos se preservan como parámetros posicionales normales (sin
# `eval`, sin concatenar a una sola cadena): quien llama puede pasar un
# array expandido (`apt_install_packages "${PKGS[@]}"`) y los espacios en
# un nombre de paquete (si alguna vez los hubiera) se preservarían igual.
apt_install_packages() {
    sudo apt-get update
    sudo apt-get install -y "$@"
}

# apt_purge_packages <paquete...>
# `apt-get purge` (no `remove`) + `autoremove`, para no dejar el paquete
# en el estado residual `rc` que motivó este módulo. `apt_package_installed`
# ya lo reportaría igual como "no instalado" tras un `remove` simple, pero
# `purge` además limpia los archivos de configuración reales en disco.
apt_purge_packages() {
    sudo apt-get purge -y "$@"
    sudo apt-get autoremove -y
}
