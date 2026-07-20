#!/usr/bin/env bash
# scripts/lib/deb_direct.sh
#
# Helpers compartidos para instaladores que descargan un `.deb` directo
# (Hito 11, grupo deb-directo: Google Chrome, MongoDB Compass) en vez de
# agregar un repositorio APT. Hermano de scripts/lib/apt.sh/snap.sh/
# apt_vendor_repo.sh para este mecanismo: centraliza la descarga con
# verificación explícita de que el archivo no quedó vacío/parcial (un
# 'wget' fallido en silencio dejaba un `.deb` corrupto, y el error real
# solo aparecía después, al intentar instalarlo con 'apt install').
#
# La instalación del `.deb` ya descargado se hace con
# 'apt_install_packages "./archivo.deb"' (scripts/lib/apt.sh): 'apt-get
# install' acepta una ruta de archivo local como argumento igual que un
# nombre de paquete, así que no hace falta un helper de instalación
# separado.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_DEB_DIRECT_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_DEB_DIRECT_SH_LOADED=1

# deb_direct_download <url> <ruta_destino>
# 'wget -O' la <url> a <ruta_destino>. Verifica explícitamente que el
# archivo resultante no quede vacío tras una descarga fallida en
# silencio; limpia el archivo parcial en cualquier caso de error, para no
# dejar un `.deb` corrupto que confunda a una corrida posterior.
deb_direct_download() {
    local url="$1" dest="$2"

    if ! wget -O "${dest}" "${url}"; then
        echo "No se pudo descargar ${url}" >&2
        rm -f "${dest}"
        return 1
    fi
    if [[ ! -s "${dest}" ]]; then
        echo "La descarga de ${url} quedó vacía; abortando" >&2
        rm -f "${dest}"
        return 1
    fi
}
