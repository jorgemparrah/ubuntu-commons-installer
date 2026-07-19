#!/usr/bin/env bash
# install_mongodb_compass.sh
#
# Riesgo conocido y aceptado (ver docs/UBUNTU_COMPATIBILITY.md): la URL de
# descarga fija una versión y arquitectura exactas
# (mongodb-compass_1.46.8_amd64.deb). MongoDB no publica un alias estable
# tipo "latest" para Compass, así que resolver la versión dinámicamente
# requeriría además scrapear su centro de descargas — fuera de alcance de
# este hito. Mitigación aplicada: la descarga ahora se verifica
# explícitamente (en vez de dejar que un wget fallido produzca un error
# de apt confuso más adelante), y el `.deb` parcial se limpia también si
# la descarga falla.

set -Eeuo pipefail
TOOL_NAME="MongoDB Compass"

# Function to check status
#
# 'dpkg -l | grep' sin anclar podía dar falso positivo: coincide con
# cualquier línea que mencione "mongodb-compass" sin importar el estado
# real del paquete (incluye "config-files" tras un remove sin purgar). Se
# ancla a '^ii <paquete exacto>' (mismo patrón que el resto del proyecto,
# ver docs/UBUNTU_COMPATIBILITY.md).
check_status() {
    if command -v mongodb-compass &> /dev/null || dpkg -l mongodb-compass 2>/dev/null | grep -q '^ii'; then
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

    local deb_name="mongodb-compass_1.46.8_amd64.deb"
    local deb_url="https://downloads.mongodb.com/compass/${deb_name}"

    echo "Descargando MongoDB Compass..."
    if ! wget -O "${deb_name}" "${deb_url}"; then
        echo "No se pudo descargar MongoDB Compass desde ${deb_url}" >&2
        echo "La versión fijada (1.46.8) podría ya no estar publicada; revisar https://www.mongodb.com/try/download/compass" >&2
        rm -f "${deb_name}"
        return 1
    fi

    echo "Instalando MongoDB Compass..."
    if ! sudo apt install -y "./${deb_name}"; then
        rm -f "${deb_name}"
        return 1
    fi

    rm -f "${deb_name}"

    echo "$TOOL_NAME instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove package
    sudo apt purge -y mongodb-compass
    sudo apt autoremove -y
    
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
