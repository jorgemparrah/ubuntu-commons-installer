#!/usr/bin/env bash
# tests/manual/run_manual_group.sh
#
# Hito 19 (ver docs/ROADMAP.md): corre los grupos de pruebas manuales
# dejando **un log por grupo**, para poder validar y reportar de a tandas
# en vez de generar un único log gigante.
#
# Se diferencia de run_all_manual_tests.sh (Hito 18), que corre los 4
# scripts originales en una sola pasada con un log único: este acepta qué
# grupos correr y separa la salida por grupo.
#
# Uso (desde la raíz del repositorio clonado en la VM):
#
#   # Ver los grupos disponibles y qué cubre cada uno:
#   bash tests/manual/run_manual_group.sh --list
#
#   # Un grupo puntual (recomendado: empezar por el más liviano):
#   bash tests/manual/run_manual_group.sh cli
#
#   # Varios grupos en orden:
#   bash tests/manual/run_manual_group.sh cli snap-extra deb-direct
#
#   # Todo lo nuevo del Hito 19 (largo: varios GB de descarga):
#   bash tests/manual/run_manual_group.sh all
#
# Cada grupo deja su propio archivo en
# /tmp/ubuntu-workstation-manual-tests/<grupo>-<timestamp>.log
# y un symlink <grupo>-latest.log a la corrida más reciente. Esos son los
# archivos a compartir para revisar los resultados.
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR

if [[ -f /.dockerenv ]]; then
    echo "Estos scripts instalan software real y están pensados para una VM" >&2
    echo "Ubuntu Desktop, no para un contenedor Docker. Abortando." >&2
    exit 1
fi

# grupo:script:descripción
UCI_GROUPS=(
    "cli:test_manual_cli_and_scripts.sh:6 instaladores livianos (curl-script, archive-direct, git-clone) + el verbo 'configure' de Starship. EL MÁS RÁPIDO Y SEGURO: empezar por acá."
    "snap-extra:test_manual_snap_extra.sh:8 instaladores Snap posteriores al Hito 18 (Bitwarden, Bruno, Chromium, Helix, Krita, Obsidian, Telegram, yq)."
    "apt-vendor:test_manual_apt_vendor_repo.sh:13 instaladores con repositorio APT del proveedor (Brave, Signal, Slack, Element, KeePassXC, OnlyOffice, Syncthing, Inkscape, fastfetch, cloudflared, VSCodium, ngrok, Albert)."
    "deb-direct:test_manual_deb_direct.sh:9 instaladores que bajan un .deb directo (dust, LocalSend, Discord, Beekeeper, DbGate, Hoppscotch, Lutris, Heroic, Orca)."
    "flatpak:test_manual_flatpak_apps.sh:3 instaladores Flatpak (Kooha, Logseq, Papers). La primera app baja el runtime de GNOME (>1 GB)."
    "ai-local:test_manual_ai_local.sh:5 herramientas de IA local (AnythingLLM, Ollama, LM Studio, Open WebUI, OmniRoute). EL MÁS PESADO: varios GB."
    "system-heavy:test_manual_system_heavy.sh:6 instaladores que tocan el sistema (Wireshark, Steam, virt-manager, Tailscale, LibreOffice, SoapUI). VirtualBox solo con --include-virtualbox."
)

usage() {
    echo "Uso: bash tests/manual/run_manual_group.sh <grupo> [<grupo>...]"
    echo "     bash tests/manual/run_manual_group.sh all"
    echo "     bash tests/manual/run_manual_group.sh --list"
    echo ""
    echo "Grupos disponibles:"
    local entry name desc
    for entry in "${UCI_GROUPS[@]}"; do
        name="${entry%%:*}"
        desc="${entry#*:*:}"
        printf "  %-14s %s\n" "${name}" "${desc}"
    done
    echo ""
    echo "Orden sugerido: cli → snap-extra → apt-vendor → deb-direct → flatpak → system-heavy → ai-local"
}

# group_script <nombre>
group_script() {
    local wanted="$1" entry name rest
    for entry in "${UCI_GROUPS[@]}"; do
        name="${entry%%:*}"
        if [[ "${name}" == "${wanted}" ]]; then
            rest="${entry#*:}"
            echo "${rest%%:*}"
            return 0
        fi
    done
    return 1
}

if [[ "$#" -eq 0 ]] || [[ "${1}" == "--help" ]] || [[ "${1}" == "-h" ]]; then
    usage
    exit 0
fi

if [[ "${1}" == "--list" ]]; then
    usage
    exit 0
fi

UCI_REQUESTED=()
if [[ "${1}" == "all" ]]; then
    for entry in "${UCI_GROUPS[@]}"; do
        UCI_REQUESTED+=("${entry%%:*}")
    done
else
    UCI_REQUESTED=("$@")
fi

# Validar TODOS los nombres antes de correr nada: es preferible fallar de
# entrada a descubrir un nombre mal escrito después de media hora de
# descargas.
for group in "${UCI_REQUESTED[@]}"; do
    if ! group_script "${group}" > /dev/null; then
        echo "Grupo desconocido: '${group}'" >&2
        echo "" >&2
        usage >&2
        exit 1
    fi
done

UCI_LOG_DIR="/tmp/ubuntu-workstation-manual-tests"
mkdir -p "${UCI_LOG_DIR}"
UCI_STAMP="$(date +%Y%m%dT%H%M%S)"

echo "Ubuntu Workstation — pruebas manuales por grupo (Hito 19)"
echo "Fecha:  $(date)"
echo "Host:   $(hostname 2>/dev/null || echo desconocido)"
echo "Ubuntu: $(lsb_release -ds 2>/dev/null || echo desconocido)"
echo "Grupos: ${UCI_REQUESTED[*]}"
echo "Logs:   ${UCI_LOG_DIR}/"
echo ""

UCI_FAILED_GROUPS=()
UCI_OK_GROUPS=()

for group in "${UCI_REQUESTED[@]}"; do
    script="$(group_script "${group}")"
    log_file="${UCI_LOG_DIR}/${group}-${UCI_STAMP}.log"
    log_latest="${UCI_LOG_DIR}/${group}-latest.log"

    echo "############################################################"
    echo "# Grupo: ${group}"
    echo "# Script: tests/manual/${script}"
    echo "# Log: ${log_file}"
    echo "############################################################"

    # La salida se ve en vivo Y queda en el log del grupo. El '|| true'
    # es deliberado: un grupo que falla no debe cortar los siguientes,
    # porque el objetivo de esta batería es juntar TODOS los resultados
    # en una sola corrida.
    bash "${UCI_TEST_DIR}/${script}" 2>&1 | tee "${log_file}" || true
    group_code="${PIPESTATUS[0]}"
    ln -sf "${log_file}" "${log_latest}"

    if [[ "${group_code}" -eq 0 ]]; then
        UCI_OK_GROUPS+=("${group}")
        echo ""
        echo ">> Grupo '${group}': SIN FALLOS"
    else
        UCI_FAILED_GROUPS+=("${group}")
        echo ""
        echo ">> Grupo '${group}': HUBO FALLOS (código ${group_code}) — revisar ${log_file}"
    fi
    echo ""
done

echo "############################################################"
echo "# Resumen de la corrida"
echo "############################################################"
echo "Grupos sin fallos: ${#UCI_OK_GROUPS[@]} ${UCI_OK_GROUPS[*]:-}"
echo "Grupos con fallos: ${#UCI_FAILED_GROUPS[@]} ${UCI_FAILED_GROUPS[*]:-}"
echo ""
echo "Logs de esta corrida:"
for group in "${UCI_REQUESTED[@]}"; do
    echo "  ${UCI_LOG_DIR}/${group}-${UCI_STAMP}.log"
done
echo ""
echo "Compartí esos archivos para revisar los resultados."

if [[ "${#UCI_FAILED_GROUPS[@]}" -gt 0 ]]; then
    exit 1
fi
exit 0
