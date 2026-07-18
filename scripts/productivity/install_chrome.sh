#!/bin/bash
# install_chrome.sh
#
# El `.deb` oficial de Chrome descargado aquí está fijado a amd64 (ver
# ADR 0028: arquitectura oficialmente soportada). Antes este script lo
# descargaba sin verificar la arquitectura real de la máquina, quedando
# un paquete incompatible en cualquier host no-amd64 (hallazgo de
# docs/UBUNTU_COMPATIBILITY.md). Google no publica un `.deb` directo para
# arm64 — no se inventa esa descarga; en arquitecturas no soportadas se
# rechaza con un error claro (UNSUPPORTED), nunca en silencio.

TOOL_NAME="Google Chrome"
CHROME_SUPPORTED_ARCH="amd64"

# check_architecture_supported
# exit 0 si la arquitectura real de la máquina es la soportada (amd64);
# exit 1 en cualquier otra (ver ADR 0028).
check_architecture_supported() {
    local machine_arch
    machine_arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    [[ "${machine_arch}" == "${CHROME_SUPPORTED_ARCH}" ]]
}

# Function to check status
check_status() {
    if ! check_architecture_supported; then
        echo "UNSUPPORTED"
        return 1
    fi
    if command -v google-chrome &> /dev/null || dpkg -l google-chrome-stable 2>/dev/null | grep -q '^ii'; then
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

    if ! check_architecture_supported; then
        local machine_arch
        machine_arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
        echo "Google Chrome (paquete .deb directo) solo se soporta en '${CHROME_SUPPORTED_ARCH}'; esta máquina es '${machine_arch}' (ver ADR 0028)." >&2
        echo "No se instalará un paquete incompatible." >&2
        return 1
    fi

    # Download Chrome
    echo "Descargando Google Chrome..."
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

    # Install Chrome
    echo "Instalando Google Chrome..."
    sudo apt install -y ./google-chrome-stable_current_amd64.deb

    # Clean up
    rm -f google-chrome-stable_current_amd64.deb

    echo "Google Chrome instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."

    # Remove Chrome
    sudo apt purge -y google-chrome-stable
    sudo apt autoremove -y

    echo "Google Chrome desinstalado correctamente."
}

# Function to reinstall
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Main function
main() {
    case "$1" in
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
