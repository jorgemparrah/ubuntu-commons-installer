#!/usr/bin/env bash
# install_docker.sh

set -Eeuo pipefail
TOOL_NAME="Docker"

# Function to check status
#
# 'dpkg -l' SIN paquete filtra por grep sobre cientos de líneas reales: si
# 'grep -q' encuentra la coincidencia temprano, cierra su entrada y
# 'dpkg -l' recibe SIGPIPE mientras aún escribe — bajo 'pipefail' (modo
# estricto agregado en este mismo hito), eso hace que el pipeline completo
# devuelva código de salida ≠0 aunque la coincidencia sí se haya
# encontrado (encontrado en CI: nunca aparece con el 'dpkg' mockeado de los
# tests simulados, que solo imprime una línea). Se consulta 'dpkg -l' solo
# para el paquete exacto (una línea de salida, sin ese riesgo), mismo
# patrón que el resto de los instaladores del proyecto.
check_status() {
    if command -v docker &> /dev/null && dpkg -l docker-ce 2>/dev/null | grep -q "^ii"; then
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
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    sudo apt-get update
    
    # Install Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group. Se usa 'id -un' en vez de "${USER}": esa
    # variable de entorno no está garantizada (encontrado en CI: ausente en
    # el contenedor Docker de prueba), y bajo 'set -u' referenciarla sin
    # estar definida aborta el script ("USER: unbound variable").
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$(id -un)"
    
    echo "Docker instalado correctamente. Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    
    # Remove Docker packages ('purge', no solo 'remove', para no dejar
    # basura de configuración en /etc/docker/ tras desinstalar — mismo
    # criterio que Cursor/VS Code/Chrome, ver docs/TECHNICAL_REVIEW.md,
    # hallazgo M8).
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo apt-get autoremove -y

    # Remove Docker repository
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /etc/apt/keyrings/docker.asc

    # Remove Docker group (if no other users are in it). Match exacto de
    # nombre de grupo, no una coincidencia de substring (evita un falso
    # positivo con un grupo hipotético "docker-foo").
    if groups | grep -qw docker; then
        sudo gpasswd -d "$(id -un)" docker
    fi
    
    echo "Docker desinstalado correctamente."
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
