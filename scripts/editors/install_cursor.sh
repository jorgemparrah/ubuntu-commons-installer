#!/usr/bin/env bash
# install_cursor.sh
#
# Cursor tiene un repositorio APT oficial (downloads.cursor.com/aptrepo),
# con el mecanismo moderno de clave GPG (signed-by + keyring, nunca
# apt-key) y soporte para amd64 y arm64. Antes este script descargaba un
# AppImage fijado a x86_64 sin checksum (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md); el repo oficial resuelve ambos problemas
# de una vez (arquitectura declarada explícitamente, clave y paquete
# verificados por apt) — ver ADR 0027 (categoría "servicio/software
# técnico con repositorio propio -> APT oficial del fabricante").
#
# El propio paquete 'cursor' gestiona, en su postinst, su propia entrada
# de repositorio con signed-by=/usr/share/keyrings/anysphere.gpg
# (encontrado al validar en CI: si nuestra entrada manual usa una ruta de
# keyring distinta, apt detecta 'Conflicting values set for option
# Signed-By' para la misma URL/suite y se niega a leer la lista de
# fuentes en CUALQUIER operación posterior, incluido 'apt update' fuera
# de este script). Por eso la clave se escribe directamente en esa misma
# ruta que el paquete espera, en vez de una ruta propia — así, aunque el
# postinst repita la misma entrada, coincide exactamente y no hay
# conflicto.

set -Eeuo pipefail
TOOL_NAME="Cursor AI IDE"
CURSOR_KEYRING=/usr/share/keyrings/anysphere.gpg
CURSOR_REPO_LIST=/etc/apt/sources.list.d/cursor.list

# Function to check status
check_status() {
    # 'dpkg -s' sigue devolviendo éxito (código 0) para un paquete recién
    # removido con 'apt remove' (queda en estado "config-files"
    # remanente) — encontrado al validar en CI, reportaba INSTALLED
    # incluso después de desinstalar. 'dpkg -l' con el flag "ii" (install
    # ok installed) sí distingue ese caso, igual que el resto de los
    # instaladores del proyecto.
    if command -v cursor &> /dev/null || dpkg -l cursor 2>/dev/null | grep -q '^ii'; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# Function to install
install_tool() {
    echo "Instalando $TOOL_NAME..."

    # gpg --dearmor requiere el paquete gnupg; no se puede asumir presente
    # (encontrado al validar en CI: sin gnupg, el pipe no falla de forma
    # visible y deja un keyring vacío en silencio, causando un error de
    # firma NO_PUBKEY recién al hacer 'apt update' — ver docs/UBUNTU_COMPATIBILITY.md).
    if ! command -v gpg &> /dev/null; then
        sudo apt update
        sudo apt install -y gnupg
    fi

    sudo mkdir -p "$(dirname "${CURSOR_KEYRING}")"

    # Descarga y convierte la clave GPG de Cursor, en la misma ruta que usa
    # el propio paquete (ver nota arriba). Se verifica explícitamente que
    # el keyring no quede vacío (un curl o gpg fallido en silencio dejaría
    # un archivo vacío, y el error real -NO_PUBKEY- solo aparecería más
    # tarde, en 'apt update' — mismo hallazgo aplicado a install_vscode.sh).
    local tmp_keyring
    tmp_keyring="$(mktemp)"
    if ! curl -fsSL https://downloads.cursor.com/keys/anysphere.asc | gpg --dearmor > "${tmp_keyring}"; then
        echo "No se pudo descargar/convertir la clave GPG de Cursor" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi
    if [[ ! -s "${tmp_keyring}" ]]; then
        echo "El keyring de Cursor quedó vacío tras la descarga; abortando" >&2
        rm -f "${tmp_keyring}"
        return 1
    fi
    sudo install -D -o root -g root -m 644 "${tmp_keyring}" "${CURSOR_KEYRING}"
    rm -f "${tmp_keyring}"

    # Añade el repositorio de Cursor
    echo "deb [arch=amd64,arm64 signed-by=${CURSOR_KEYRING}] https://downloads.cursor.com/aptrepo stable main" | sudo tee "${CURSOR_REPO_LIST}" > /dev/null

    # Actualiza e instala
    sudo apt update
    sudo apt install -y cursor

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    sudo apt purge -y cursor
    sudo apt autoremove -y
    sudo rm -f "${CURSOR_REPO_LIST}"
    sudo rm -f "${CURSOR_KEYRING}"

    # Limpia también cualquier entrada que el propio paquete pudo haber
    # agregado con un nombre de archivo distinto al nuestro (se confirmó en
    # CI: crea /etc/apt/sources.list.d/cursor.sources en formato Deb822).
    sudo rm -f /etc/apt/sources.list.d/anysphere.list
    sudo rm -f /etc/apt/sources.list.d/cursor.sources

    echo "$TOOL_NAME desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Main function
main() {
    case "${1:-}" in
        "status")
            check_status
            ;;
        "install")
            install_tool
            ;;
        "uninstall")
            uninstall_tool
            ;;
        "reinstall")
            reinstall_tool
            ;;
        *)
            echo "Uso: $0 {status|install|uninstall|reinstall}"
            exit 1
            ;;
    esac
}

main "$@"
