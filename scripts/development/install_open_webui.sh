#!/usr/bin/env bash
# install_open_webui.sh
#
# Instalador nuevo (Hito 53, ver docs/ROADMAP.md): agrega Open WebUI al
# catálogo (category=ai, subcategory=local-models, mismo grupo que
# Ollama). **Primer y único caso del mecanismo `pip-mise`** (ver
# docs/adr/0046-mecanismos-para-interfaces-locales-de-ia.md): paquete de
# Python instalado con pip sobre un intérprete FIJADO POR MISE, no el del
# sistema. Reutiliza scripts/lib/runtime.sh sin modificarlo.
#
# ── Por qué no el Python del sistema ────────────────────────────────
# PyPI declara `requires_python: >=3.11,<3.13.0a1` (confirmado en vivo
# contra la API). Ubuntu 24.04 trae Python 3.12.3 (cumple), pero 26.04
# traerá 3.13+ (NO cumple). Un pip contra el intérprete del sistema
# andaría hoy y se rompería en la otra versión soportada. Mise ya es el
# único gestor de runtimes del proyecto (ADR 0002) y su catálogo en
# runtime.sh ya contempla Python, así que fijar el intérprete da un
# comportamiento idéntico en ambas. Se usa 3.11, la versión que la
# documentación oficial recomienda explícitamente.
#
# Se evaluó y descartó Docker (el método que el propio proyecto más
# promociona): introduciría gestionar un servicio de larga duración
# (`--restart always`), algo que este catálogo nunca hizo. Decisión
# explícita del dueño del proyecto.
#
# ── Este instalador NO arranca el servicio ──────────────────────────
# Open WebUI es un servicio web (dashboard local), no una app de
# escritorio. El instalador deja disponible el comando `open-webui serve`
# y lo informa; administrar el proceso queda fuera del alcance de este
# catálogo, que instala software y no gestiona servicios.
#
# Licencia: "Open WebUI License" (BSD-3-Clause + cláusula que prohíbe
# alterar el branding, con excepción hasta 50 usuarios finales). NO
# restringe el uso local — verificado leyendo el LICENSE real. Ya no es
# MIT, como suponía el objetivo del Hito.

set -Eeuo pipefail

TOOL_NAME="Open WebUI"
UCI_OPEN_WEBUI_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_OPEN_WEBUI_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OPEN_WEBUI_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_OPEN_WEBUI_PACKAGE="open-webui"
UCI_OPEN_WEBUI_PYTHON="3.11"

# open_webui_pip <argumentos de pip...>
# Corre pip con el Python fijado por Mise, nunca el del sistema.
open_webui_pip() {
    runtime_cmd "${HOME}" exec "python@${UCI_OPEN_WEBUI_PYTHON}" -- pip "$@"
}

# Function to check status
check_status() {
    if ! runtime_mise_available "${HOME}"; then
        echo "UNKNOWN"
        return 1
    fi

    if open_webui_pip show "${UCI_OPEN_WEBUI_PACKAGE}" &> /dev/null; then
        echo "INSTALLED"
        return 0
    fi

    echo "NOT_INSTALLED"
    return 1
}

# Function to install
install_tool() {
    echo "Instalando ${TOOL_NAME}..."

    if ! runtime_ensure_mise "${HOME}"; then
        echo "No se pudo instalar Mise" >&2
        return 1
    fi

    if ! runtime_install "${HOME}" python "${UCI_OPEN_WEBUI_PYTHON}"; then
        echo "No se pudo instalar Python ${UCI_OPEN_WEBUI_PYTHON} vía Mise" >&2
        return 1
    fi

    if ! open_webui_pip install --upgrade "${UCI_OPEN_WEBUI_PACKAGE}"; then
        echo "No se pudo instalar ${TOOL_NAME} vía pip" >&2
        return 1
    fi

    # Sin 'reshim', el ejecutable de consola que instala pip dentro del
    # Python de Mise no queda expuesto en el PATH.
    runtime_cmd "${HOME}" reshim

    echo "${TOOL_NAME} instalado correctamente. Arráncalo con 'open-webui serve' (queda escuchando en http://localhost:8080); este instalador no gestiona el servicio."
}

# Function to uninstall
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if runtime_mise_available "${HOME}"; then
        open_webui_pip uninstall -y "${UCI_OPEN_WEBUI_PACKAGE}" || true
        runtime_cmd "${HOME}" reshim || true
    fi

    echo "${TOOL_NAME} desinstalado correctamente. Los datos en ~/.open-webui (si existen) se conservaron."
}

# Function to update
update_tool() {
    if ! runtime_mise_available "${HOME}"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    if ! open_webui_pip install --upgrade "${UCI_OPEN_WEBUI_PACKAGE}"; then
        echo "No se pudo actualizar ${TOOL_NAME}" >&2
        return 1
    fi
    runtime_cmd "${HOME}" reshim
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
