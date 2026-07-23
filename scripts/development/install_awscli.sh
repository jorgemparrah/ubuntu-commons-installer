#!/usr/bin/env bash
# install_awscli.sh
#
# Instalador nuevo (Hito 42, ver docs/ROADMAP.md): agrega AWS CLI v2 al
# catálogo (category=development, subcategory=cloud-cli, junto a Azure
# CLI/Google Cloud CLI). A diferencia de esos dos, AWS no publica un
# repositorio APT oficial propio (confirmado por investigación): el único
# método oficial "siempre la última versión" en Linux es un `.zip`
# estático (URL fija, sin versión en el path — se confirmó en vivo con
# `curl -sI` que responde 200), que trae adentro su PROPIO instalador
# (`aws/install`, un script de AWS, no de este proyecto) — hay que
# descomprimirlo y ejecutarlo. AWS también ofrece un snap oficial
# (`aws-cli --classic`), pero por la jerarquía de fuentes de AGENT.md §15
# el instalador oficial tiene prioridad sobre snap; se prioriza ese.
#
# Mecanismo nuevo (`manager=aws-cli-installer`), no generalizado a una
# biblioteca compartida: caso único en el catálogo (mismo criterio que
# `izpack-installer` para SoapUI — ver ADR 0032, esperar un segundo caso
# real antes de abstraer). Similar en espíritu a `izpack-installer`
# (descargar algo, correr SU PROPIO instalador, verificar el binario
# resultante) pero técnicamente distinto: acá el "instalador propio" es
# un script bash de AWS, no un instalador Java/IzPack con GUI.
#
# El instalador oficial de AWS soporta `--update` para actualizar una
# instalación existente sin reinstalar desde cero (ver 'update_tool').
# `repair` no se implementa (sin detección barata de instalación parcial,
# mismo criterio que otros instaladores de este catálogo).

set -Eeuo pipefail

UCI_AWSCLI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_AWSCLI_SCRIPT_DIR}/../lib/installer_cli.sh"

TOOL_NAME="AWS CLI"
AWSCLI_INSTALL_DIR="/usr/local/aws-cli"
AWSCLI_BIN_DIR="/usr/local/bin"

# awscli_download_url
# URL fija y siempre-última-versión, distinta según arquitectura
# (confirmada en la documentación oficial de AWS).
awscli_download_url() {
    case "$(uname -m)" in
        x86_64)
            echo "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;
        aarch64|arm64)
            echo "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;
        *)
            echo "Arquitectura no soportada por el instalador oficial de AWS CLI: $(uname -m)" >&2
            return 1
            ;;
    esac
}

# awscli_fetch_and_run_installer <argumentos extra para aws/install...>
# Descarga el .zip oficial a un directorio temporal, lo descomprime y
# ejecuta el instalador oficial de AWS que trae adentro. Limpia el
# directorio temporal siempre, incluso si el instalador falla.
awscli_fetch_and_run_installer() {
    local url workdir
    url="$(awscli_download_url)" || return 1
    workdir="$(mktemp -d)"

    if ! curl -fsSL "${url}" -o "${workdir}/awscliv2.zip"; then
        echo "No se pudo descargar ${url}" >&2
        rm -rf "${workdir}"
        return 1
    fi

    if ! unzip -q "${workdir}/awscliv2.zip" -d "${workdir}"; then
        echo "No se pudo descomprimir el instalador de AWS CLI" >&2
        rm -rf "${workdir}"
        return 1
    fi

    if ! sudo "${workdir}/aws/install" --bin-dir "${AWSCLI_BIN_DIR}" --install-dir "${AWSCLI_INSTALL_DIR}" "$@"; then
        echo "El instalador oficial de AWS CLI falló" >&2
        rm -rf "${workdir}"
        return 1
    fi

    rm -rf "${workdir}"
}

# Function to check status
check_status() {
    if ! command -v aws &> /dev/null; then
        echo "NOT_INSTALLED"
        return 1
    fi

    if ! aws --version &> /dev/null; then
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
    awscli_fetch_and_run_installer

    echo "${TOOL_NAME} instalado correctamente."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."
    sudo rm -rf "${AWSCLI_INSTALL_DIR}" "${AWSCLI_BIN_DIR}/aws" "${AWSCLI_BIN_DIR}/aws_completer"
    echo "${TOOL_NAME} desinstalado correctamente."
}

# Function to update
update_tool() {
    if ! command -v aws &> /dev/null; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    awscli_fetch_and_run_installer --update

    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
