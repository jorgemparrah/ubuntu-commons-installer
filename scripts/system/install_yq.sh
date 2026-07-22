#!/usr/bin/env bash
# install_yq.sh
#
# Instalador nuevo (Hito 28, ver docs/ROADMAP.md): agrega yq al catálogo.
# Usa el dispatcher compartido y los helpers Snap compartidos
# (scripts/lib/snap.sh) — mismo mecanismo que Spotify/Chromium.
#
# CUIDADO, investigado explícitamente: existen dos programas distintos
# llamados 'yq'. El paquete `yq` de los repositorios oficiales de Ubuntu
# es el de Kislyuk en Python (github.com/kislyuk/yq, wrapper de jq para
# YAML) — NO es el de Mike Farah (github.com/mikefarah/yq, Go,
# procesador standalone, sintaxis tipo jq, el más popular hoy y
# casi seguro el que se espera acá). El PPA histórico de terceros que
# empaquetaba el de Mike Farah (ppa:rmescandon/yq) está descontinuado.
# Mike Farah publica un snap oficial verificado (cuenta `mikefarah` en
# Snap Store) — se usa ese, nunca el paquete apt de Ubuntu (instalaría el
# programa equivocado). Sin `--classic`.

set -Eeuo pipefail

UCI_YQ_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/snap.sh
source "${UCI_YQ_SCRIPT_DIR}/../lib/snap.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_YQ_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="yq"
SNAP_PACKAGE="yq"

# Function to check status
check_status() {
    if ! snap_available; then
        echo "UNKNOWN"
        return 1
    fi

    if snap_package_installed "${SNAP_PACKAGE}"; then
        echo "INSTALLED"
        return 0
    fi

    echo "NOT_INSTALLED"
    return 1
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."
    snap_install_package "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    snap_remove_package "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    echo "Actualizando ${TOOL_NAME}..."
    sudo snap refresh "${SNAP_PACKAGE}"
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
