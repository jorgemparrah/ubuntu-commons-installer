#!/usr/bin/env bash
# install_soapui.sh
#
# Instalador nuevo (Hito 29, ver docs/ROADMAP.md): agrega SoapUI
# (open source) al catálogo. Mecanismo distinto a todo lo demás en este
# proyecto: SmartBear distribuye un instalador `.sh` tipo IzPack (bundle
# gráfico/interactivo empaquetado como script autoextraíble), no un
# `.deb` ni un script `curl | sh` de una sola pasada. La URL de descarga
# no tiene alias "latest" (versión embebida en el nombre del archivo) —
# se resuelve dinámicamente contra el último release de GitHub
# (SmartBear/soapui) vía scripts/lib/github_release.sh, mismo criterio
# que install_localsend.sh.
#
# ADVERTENCIA DE INCERTIDUMBRE, documentada a propósito: se confirmó que
# el instalador soporta un flag `-q` para modo silencioso (comunidad de
# SmartBear), pero NO se confirmó con una instalación real: (a) el
# directorio exacto donde queda instalado con `-q` (varía según la
# configuración por defecto del bundle IzPack, no controlable desde acá
# sin un archivo de respuestas que tampoco se confirmó), ni (b) si `-q`
# alcanza para una instalación 100% no interactiva en todas las
# versiones. `check_status`/`install_tool` buscan en las ubicaciones más
# típicas de este tipo de instalador (`$HOME/SoapUI-*`, `/opt/SoapUI-*`)
# en vez de asumir una ruta fija. `requires_manual_validation=yes` en
# tools_catalog.sh por este motivo — validar de verdad en tests/manual/
# (Hito 19) antes de confiar en este instalador sin supervisión.

set -Eeuo pipefail

UCI_SOAPUI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/github_release.sh
source "${UCI_SOAPUI_SCRIPT_DIR}/../lib/github_release.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_SOAPUI_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="SoapUI"
SOAPUI_REPO="SmartBear/soapui"

# soapui_installed_bin
# Busca el binario en las ubicaciones típicas de un instalador IzPack
# corrido con -q. Devuelve la ruta encontrada; código ≠0 si ninguna.
soapui_installed_bin() {
    local candidate
    for candidate in "${HOME}"/SoapUI-*/bin/soapui.sh /opt/SoapUI-*/bin/soapui.sh; do
        if [[ -x "${candidate}" ]]; then
            echo "${candidate}"
            return 0
        fi
    done
    return 1
}

# Function to check status
check_status() {
    if ! soapui_installed_bin &> /dev/null; then
        echo "NOT_INSTALLED"
        return 1
    fi

    echo "INSTALLED"
    return 0
}

# Function to install
install_tool() {
    local current_status
    current_status="$(check_status 2>/dev/null)" || true
    if [[ "${current_status}" == "INSTALLED" ]]; then
        echo "${TOOL_NAME} ya parece estar instalado ($(soapui_installed_bin)); usa 'uninstall' primero si querés reinstalar." >&2
        return 1
    fi

    local installer_url
    if ! installer_url="$(github_release_asset_url "${SOAPUI_REPO}" 'SoapUI-x64-.*\.sh"')"; then
        echo "No se pudo resolver la URL del instalador oficial; revisar https://github.com/${SOAPUI_REPO}/releases" >&2
        return 1
    fi

    local tmp_installer
    tmp_installer="$(mktemp)"
    echo "Descargando el instalador oficial de ${TOOL_NAME} (${installer_url})..."
    if ! curl -fsSL "${installer_url}" -o "${tmp_installer}"; then
        echo "No se pudo descargar el instalador desde ${installer_url}" >&2
        rm -f "${tmp_installer}"
        return 1
    fi
    if [[ ! -s "${tmp_installer}" ]]; then
        echo "El instalador descargado quedó vacío; abortando" >&2
        rm -f "${tmp_installer}"
        return 1
    fi
    chmod +x "${tmp_installer}"

    echo "Corriendo el instalador oficial en modo silencioso (-q)..."
    "${tmp_installer}" -q
    local install_exit_code=$?
    rm -f "${tmp_installer}"

    if [[ ${install_exit_code} -ne 0 ]] || ! soapui_installed_bin &> /dev/null; then
        echo "La instalación no dejó un binario resoluble en las ubicaciones esperadas — el instalador IzPack de ${TOOL_NAME} puede requerir pasos adicionales no automatizados limpiamente en este instalador; validar manualmente (ver tests/manual/, Hito 19)." >&2
        return 1
    fi

    echo "${TOOL_NAME} instalado correctamente en $(dirname "$(dirname "$(soapui_installed_bin)")")."
}

# Function to uninstall
uninstall_tool() {
    local bin_path
    if ! bin_path="$(soapui_installed_bin)"; then
        echo "${TOOL_NAME} no está instalado." >&2
        return 0
    fi

    echo "Desinstalando ${TOOL_NAME}..."
    rm -rf "$(dirname "$(dirname "${bin_path}")")"
    echo "${TOOL_NAME} desinstalado correctamente."
}

installer_run_cli "$@"
