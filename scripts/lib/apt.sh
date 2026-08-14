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

# apt_update
# `apt-get update` que NO es fatal si algún repositorio falla.
#
# Motivo (hallazgo de la ejecución real del 2026-08-14, ver
# docs/ROADMAP.md Hito 19): `apt-get update` devuelve un código distinto
# de cero si **cualquier** repositorio del sistema está roto, aunque no
# tenga nada que ver con lo que se está instalando. Como los instaladores
# corren con `set -Eeuo pipefail`, un solo repositorio de terceros mal
# configurado hacía fallar a TODOS los instaladores que pasan por APT: en
# esa corrida, un repositorio roto dejó sin instalar hasta `cmatrix`, que
# viene de los repositorios de Ubuntu y no tenía problema alguno.
#
# Ahora el fallo se reporta de forma visible y se continúa: APT ya sabe
# trabajar con las listas que tenga disponibles, y es preferible instalar
# con una lista algo desactualizada a no poder instalar nada. Quien
# necesite tratar el fallo como fatal puede mirar el código de retorno,
# que se preserva.
apt_update() {
    if sudo apt-get update; then
        return 0
    fi

    local code=$?
    echo "" >&2
    echo "AVISO: 'apt-get update' reportó errores (típicamente un repositorio de" >&2
    echo "terceros roto o sin paquetes para esta versión de Ubuntu). Se continúa" >&2
    echo "con las listas de paquetes disponibles; revisá la salida de arriba para" >&2
    echo "ver qué repositorio conviene corregir o quitar." >&2
    echo "" >&2
    return "${code}"
}

# apt_install_packages <paquete...>
# `apt-get update` (tolerante, ver apt_update) + `apt-get install -y` de
# todos los paquetes dados.
# Los argumentos se preservan como parámetros posicionales normales (sin
# `eval`, sin concatenar a una sola cadena): quien llama puede pasar un
# array expandido (`apt_install_packages "${PKGS[@]}"`) y los espacios en
# un nombre de paquete (si alguna vez los hubiera) se preservarían igual.
apt_install_packages() {
    # El '|| true' es deliberado: un repositorio ajeno roto no debe
    # impedir instalar. Si el paquete pedido realmente no se puede
    # resolver, el 'apt-get install' de abajo falla igual y ese sí corta.
    apt_update || true
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
