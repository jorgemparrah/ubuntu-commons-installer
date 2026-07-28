#!/usr/bin/env bash
# scripts/lib/flatpak.sh
#
# Helpers Flatpak compartidos para instaladores (Hito 50, grupo Flatpak —
# ver docs/adr/0045-mecanismo-flatpak-para-apps-sin-fuente-apt-snap-oficial.md).
# Hermano de scripts/lib/apt.sh/snap.sh: mismo rol (centralizar "¿está
# esto realmente instalado?" y las operaciones de instalación/
# desinstalación) para el mecanismo Flatpak.
#
# A diferencia de snapd, Flatpak NO viene instalado por defecto en Ubuntu:
# flatpak_ensure_flathub instala el paquete `flatpak` vía APT si falta y
# registra el remote de Flathub, igual que apt_vendor_repo_ensure_gnupg
# instala `gnupg` cuando falta.
#
# Flatpak puede estar simplemente ausente o no responder. Ese caso se
# distingue explícitamente de "el paquete no está instalado" (mismo
# criterio que scripts/lib/snap.sh, hallazgo original de
# docs/UBUNTU_COMPATIBILITY.md sobre snapd).
#
# 'status' NO intenta distinguir OUTDATED: consultar Flathub por la
# versión más reciente requiere red, lo que violaría que 'status' sea
# liviano y de solo lectura local (ver docs/ARCHITECTURE.md §21, mismo
# criterio ya aplicado a Snap). 'update' sigue existiendo como verbo
# explícito.
#
# Pensado para cargarse con `source`; no declara su propio modo estricto
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). El script
# que lo sourcea es responsable de `set -Eeuo pipefail`.

if [[ "${UCI_FLATPAK_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_FLATPAK_SH_LOADED=1

UCI_FLATPAK_FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

# flatpak_available
# 0 si Flatpak está presente y responde (el binario 'flatpak' existe Y
# 'flatpak --version' no falla); 1 en cualquier otro caso. No distingue
# POR QUÉ no responde — ese detalle no le importa a quien llama, solo que
# 'status' no puede confiar en la respuesta.
flatpak_available() {
    command -v flatpak &> /dev/null && flatpak --version &> /dev/null
}

# flatpak_app_installed <app_id>
# 0 si <app_id> aparece en 'flatpak list --app' (match exacto de línea, no
# de substring: 'org.gnome.Papers' no debe coincidir con
# 'org.gnome.PapersOtraCosa'). Asume que ya se llamó a flatpak_available.
flatpak_app_installed() {
    local app_id="$1"
    flatpak list --app --columns=application 2>/dev/null | grep -qx "${app_id}"
}

# flatpak_ensure_flathub
# Instala el paquete `flatpak` vía APT si falta y registra el remote de
# Flathub a nivel de sistema. '--if-not-exists' hace el registro
# idempotente: si el remote ya está, no falla ni lo duplica.
flatpak_ensure_flathub() {
    if ! command -v flatpak &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y flatpak
    fi

    sudo flatpak remote-add --if-not-exists flathub "${UCI_FLATPAK_FLATHUB_URL}"
}

# flatpak_install_app <app_id>
# '-y' para no colgar un instalador desatendido esperando confirmación.
flatpak_install_app() {
    local app_id="$1"
    sudo flatpak install -y flathub "${app_id}"
}

# flatpak_remove_app <app_id>
flatpak_remove_app() {
    local app_id="$1"
    sudo flatpak uninstall -y "${app_id}"
}

# flatpak_update_app <app_id>
flatpak_update_app() {
    local app_id="$1"
    sudo flatpak update -y "${app_id}"
}
