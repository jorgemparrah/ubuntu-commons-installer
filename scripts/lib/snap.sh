#!/usr/bin/env bash
# scripts/lib/snap.sh
#
# Helpers Snap compartidos para instaladores (Hito 11, grupo Snap — ver
# docs/ROADMAP.md). Hermano de scripts/lib/apt.sh: mismo rol (centralizar
# "¿está esto realmente instalado?" y las operaciones de instalación/
# desinstalación) para el mecanismo Snap en vez de APT.
#
# Snapd puede estar simplemente ausente (por ejemplo, dentro de un
# contenedor Docker sin systemd — no verificable automáticamente ahí, ver
# docs/UBUNTU_COMPATIBILITY.md) o no responder. Ese caso se distingue
# explícitamente de "el paquete no está instalado": antes de esta
# biblioteca cada instalador Snap repetía la misma comprobación
# (`command -v snap && snap list`) línea por línea.
#
# 'status' NO intenta distinguir OUTDATED: 'snap refresh --list' consulta
# la store de Snap por red, lo que violaría que 'status' debe ser liviano
# y de solo lectura local (ver docs/ARCHITECTURE.md §21, mismo criterio ya
# aplicado a los paquetes meta de ADR 0031). 'update' sigue existiendo como
# verbo explícito (el usuario puede pedirlo aunque 'status' no lo sugiera
# automáticamente).
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_SNAP_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_SNAP_SH_LOADED=1

# snap_available
# 0 si snapd está presente y respondiendo (el binario 'snap' existe Y
# 'snap list' no falla); 1 en cualquier otro caso. No distingue POR QUÉ
# snapd no responde (ausente, demonio caído, etc.) — ese detalle no le
# importa a quien llama, solo que 'status' no puede confiar en la
# respuesta.
snap_available() {
    command -v snap &> /dev/null && snap list &> /dev/null
}

# snap_package_installed <paquete>
# 0 si el paquete aparece en 'snap list' (columna Name exacta); 1 si no.
# Asume que ya se llamó a snap_available (no repite esa comprobación, para
# no encarecer una consulta que quien llama puede querer hacer una sola
# vez para varios paquetes).
snap_package_installed() {
    local package="$1"
    snap list 2>/dev/null | grep -q "^${package} "
}

# snap_install_package <paquete> [flags de 'snap install', ej. --classic]
snap_install_package() {
    local package="$1"
    shift
    sudo snap install "${package}" "$@"
}

# snap_remove_package <paquete>
snap_remove_package() {
    local package="$1"
    sudo snap remove "${package}"
}
