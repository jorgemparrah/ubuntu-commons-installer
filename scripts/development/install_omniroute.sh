#!/usr/bin/env bash
# install_omniroute.sh
#
# Instalador nuevo (Hito 56, ver docs/ROADMAP.md): agrega OmniRoute al
# catálogo. **Primer y único caso del mecanismo `npm-mise`** (ver
# docs/adr/0047-mecanismo-npm-mise-para-omniroute.md): paquete npm global
# instalado sobre un Node FIJADO POR MISE, no el del sistema. Reutiliza
# scripts/lib/runtime.sh sin modificarlo, igual que `pip-mise`.
#
# ── Por qué no el Node del sistema ──────────────────────────────────
# El paquete declara en npm `engines: node >=22.0.0 <23 || >=24.0.0 <27`
# (confirmado en vivo contra el registry). O sea: Node 22 o 24/25/26, y
# explícitamente NO 23. Depender del Node de Ubuntu haría que el
# resultado dependiera de qué versión traiga cada release, que además
# difiere entre 24.04 y 26.04. Mise ya es el único gestor de runtimes del
# proyecto (ADR 0002) y su catálogo en runtime.sh ya contempla Node, así
# que se fija la versión. Se usa Node 24: LTS vigente (Krypton,
# verificado en vivo contra nodejs.org) y dentro del rango permitido.
#
# Se evaluó y descartó la imagen Docker oficial, por el mismo criterio ya
# decidido para Open WebUI (ADR 0046): implicaría gestionar un servicio de
# larga duración, algo que este catálogo no hace.
#
# ── Qué es y qué NO es ──────────────────────────────────────────────
# Gateway de IA: expone un endpoint local compatible con OpenAI y enruta
# hacia muchos proveedores (en su mayoría remotos), con fallback por
# cuota, caché y observabilidad. NO corre inferencia local — por eso
# subcategory=ai-gateway y no `local-models` (la de Ollama): lo único
# local es el endpoint. Ver la ADR para el razonamiento completo.
#
# Este instalador NO arranca el servicio: deja disponible el comando
# `omniroute` y lo informa. Administrar el proceso queda fuera del
# alcance de este catálogo, que instala software y no gestiona servicios.
#
# Licencia MIT (verificada en el repo y en el package.json publicado).
# Verificado en vivo lo que pedía el objetivo del Hito: el proyecto
# declara "no billing system" y "zero telemetry by default".

set -Eeuo pipefail

TOOL_NAME="OmniRoute"
UCI_OMNIROUTE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/runtime.sh
source "${UCI_OMNIROUTE_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/installer_cli.sh
source "${UCI_OMNIROUTE_SCRIPT_DIR}/../lib/installer_cli.sh"

UCI_OMNIROUTE_PACKAGE="omniroute"
UCI_OMNIROUTE_NODE="24"
UCI_OMNIROUTE_PORT="20128"

# omniroute_npm <argumentos de npm...>
# Corre npm con el Node fijado por Mise, nunca el del sistema.
omniroute_npm() {
    runtime_cmd "${HOME}" exec "node@${UCI_OMNIROUTE_NODE}" -- npm "$@"
}

# Function to check status
# UNKNOWN (no NOT_INSTALLED) si Mise no está: sin Mise no se puede saber
# si el paquete está instalado, y afirmar "no instalado" sería inventar.
# Mismo criterio que snap/flatpak/pip-mise.
check_status() {
    if ! runtime_mise_available "${HOME}"; then
        echo "UNKNOWN"
        return 1
    fi

    if omniroute_npm ls -g --depth=0 "${UCI_OMNIROUTE_PACKAGE}" &> /dev/null; then
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

    if ! runtime_install "${HOME}" node "${UCI_OMNIROUTE_NODE}"; then
        echo "No se pudo instalar Node ${UCI_OMNIROUTE_NODE} vía Mise" >&2
        return 1
    fi

    if ! omniroute_npm install -g "${UCI_OMNIROUTE_PACKAGE}"; then
        echo "No se pudo instalar ${TOOL_NAME} vía npm" >&2
        return 1
    fi

    # Sin 'reshim', el ejecutable del paquete global no queda expuesto en
    # el PATH.
    runtime_cmd "${HOME}" reshim

    echo "${TOOL_NAME} instalado correctamente. Arráncalo con 'omniroute' (dashboard en http://localhost:${UCI_OMNIROUTE_PORT}, API compatible con OpenAI en http://localhost:${UCI_OMNIROUTE_PORT}/v1); este instalador no gestiona el servicio."
}

# Function to uninstall
# Conserva la configuración y los datos locales (claves de proveedores,
# base de datos): AGENT.md §2 y §11.
uninstall_tool() {
    echo "Desinstalando ${TOOL_NAME}..."

    if runtime_mise_available "${HOME}"; then
        omniroute_npm uninstall -g "${UCI_OMNIROUTE_PACKAGE}" || true
        runtime_cmd "${HOME}" reshim || true
    fi

    echo "${TOOL_NAME} desinstalado correctamente. La configuración y los datos locales (si existen) se conservaron."
}

# Function to update
# 'npm install -g' ya trae la última versión publicada, así que update e
# install comparten el mismo comando; lo que cambia es que update exige
# que Mise ya esté disponible en vez de instalarlo.
update_tool() {
    if ! runtime_mise_available "${HOME}"; then
        echo "${TOOL_NAME} no está instalado; usa 'install' en vez de 'update'." >&2
        return 1
    fi

    echo "Actualizando ${TOOL_NAME}..."
    if ! omniroute_npm install -g "${UCI_OMNIROUTE_PACKAGE}"; then
        echo "No se pudo actualizar ${TOOL_NAME}" >&2
        return 1
    fi
    runtime_cmd "${HOME}" reshim
    echo "${TOOL_NAME} actualizado correctamente."
}

installer_run_cli "$@"
