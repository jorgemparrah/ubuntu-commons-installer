#!/usr/bin/env bash
# install_lmstudio.sh
#
# Instalador nuevo (Hito 53, ver docs/ROADMAP.md): agrega LM Studio al
# catálogo (category=ai, subcategory=local-models, mismo grupo que
# Ollama). **Primer y único caso del mecanismo `appimage-direct`** (ver
# docs/adr/0046-mecanismos-para-interfaces-locales-de-ia.md): AppImage
# descargado de una URL estable del proveedor, sin script oficial de por
# medio (a diferencia de Joplin/AnythingLLM, que sí publican uno).
#
# ── Licencia: código cerrado ────────────────────────────────────────
# LM Studio es gratuito pero **NO es de código abierto**, a diferencia
# del resto de este grupo (Ollama, Open WebUI, AnythingLLM). Su inclusión
# fue consultada y aprobada explícitamente por el dueño del proyecto, con
# el precedente ya establecido de otras herramientas no-FOSS del catálogo
# (Obsidian, Discord, Slack, Steam, Terraform, Vagrant).
#
# ── URL estable, sin resolver versión ───────────────────────────────
# `lmstudio.ai/download/latest/linux/x64?format=AppImage` responde 200 y
# redirige al `.AppImage` versionado (confirmado en vivo). No hace falta
# consultar una API de releases para resolver la última versión — mismo
# patrón que el endpoint estable de Discord o el `.zip` de AWS CLI.
#
# El AppImage se instala en `~/.local/share/lmstudio/` y se le crea un
# `.desktop`: sin eso quedaría un archivo suelto sin integración con el
# escritorio (mismo motivo por el que se rechazó el instalador oficial de
# Kitty en el Hito 40). Requiere `libfuse2`, que Ubuntu 24.04+ ya no trae
# por defecto y los AppImage necesitan — se instala vía APT, mismo
# criterio que `apt_vendor_repo_ensure_gnupg`/`flatpak_ensure_flathub`.

set -Eeuo pipefail

UCI_LMSTUDIO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/apt.sh
source "${UCI_LMSTUDIO_SCRIPT_DIR}/../lib/apt.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_LMSTUDIO_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="LM Studio"
UCI_LMSTUDIO_URL="https://lmstudio.ai/download/latest/linux/x64?format=AppImage"
UCI_LMSTUDIO_DIR="${HOME}/.local/share/lmstudio"
UCI_LMSTUDIO_APPIMAGE="${UCI_LMSTUDIO_DIR}/LM-Studio.AppImage"
UCI_LMSTUDIO_DESKTOP="${HOME}/.local/share/applications/lmstudio.desktop"

# lmstudio_download_appimage
# Descarga a un temporal y recién ahí lo instala en su ruta final: evita
# dejar un AppImage parcial si la descarga se corta a mitad de camino
# (mismo patrón en dos pasos que apt_vendor_repo_fetch_file_plain).
lmstudio_download_appimage() {
    local tmp_file
    tmp_file="$(mktemp)"

    if ! curl -fsSL "${UCI_LMSTUDIO_URL}" -o "${tmp_file}"; then
        echo "No se pudo descargar ${TOOL_NAME} desde ${UCI_LMSTUDIO_URL}" >&2
        rm -f "${tmp_file}"
        return 1
    fi
    if [[ ! -s "${tmp_file}" ]]; then
        echo "El AppImage descargado quedó vacío; abortando" >&2
        rm -f "${tmp_file}"
        return 1
    fi

    mkdir -p "${UCI_LMSTUDIO_DIR}"
    mv "${tmp_file}" "${UCI_LMSTUDIO_APPIMAGE}"
    chmod +x "${UCI_LMSTUDIO_APPIMAGE}"
}

# lmstudio_write_desktop_entry
lmstudio_write_desktop_entry() {
    mkdir -p "$(dirname "${UCI_LMSTUDIO_DESKTOP}")"
    cat > "${UCI_LMSTUDIO_DESKTOP}" <<EOF
[Desktop Entry]
Type=Application
Name=LM Studio
Comment=Interfaz de escritorio para ejecutar modelos de lenguaje locales
Exec=${UCI_LMSTUDIO_APPIMAGE}
Icon=lmstudio
Terminal=false
Categories=Development;Utility;
EOF
}

# Function to check status
check_status() {
    if [[ ! -e "${UCI_LMSTUDIO_APPIMAGE}" ]]; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if [[ ! -x "${UCI_LMSTUDIO_APPIMAGE}" ]] || [[ ! -f "${UCI_LMSTUDIO_DESKTOP}" ]]; then
        echo "BROKEN"
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
        echo "${TOOL_NAME} ya está instalado; usa 'update' en vez de 'install'." >&2
        return 1
    fi
    if [[ "${current_status}" == "BROKEN" ]]; then
        echo "${TOOL_NAME} está en estado BROKEN; usa 'repair' en vez de 'install'." >&2
        return 1
    fi

    echo "Instalando ${TOOL_NAME}..."

    apt_install_packages libfuse2
    lmstudio_download_appimage
    lmstudio_write_desktop_entry

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    rm -rf "${UCI_LMSTUDIO_DIR}"
    rm -f "${UCI_LMSTUDIO_DESKTOP}"

    # No se purga libfuse2: otros AppImage del sistema pueden depender de
    # él. Tampoco se tocan los modelos descargados en ~/.lmstudio (datos
    # del usuario, AGENT.md §2).
    echo "${TOOL_NAME} desinstalado correctamente. libfuse2 y los modelos en ~/.lmstudio se conservaron."
}

# Function to update
update_tool() {
    if [[ ! -e "${UCI_LMSTUDIO_APPIMAGE}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    lmstudio_download_appimage
    echo "${TOOL_NAME} actualizado correctamente."
}

# Function to repair (para el estado BROKEN: AppImage sin permiso de
# ejecución, o .desktop faltante)
repair_tool() {
    if [[ ! -e "${UCI_LMSTUDIO_APPIMAGE}" ]]; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'repair'." >&2
        return 1
    fi

    echo "Reparando ${TOOL_NAME}..."
    chmod +x "${UCI_LMSTUDIO_APPIMAGE}"
    lmstudio_write_desktop_entry
    echo "${TOOL_NAME} reparado."
}

installer_run_cli "$@"
