#!/usr/bin/env bash
# repair_apt_sources.sh
#
# Detecta y deshabilita repositorios APT rotos (ver
# scripts/lib/apt_sources.sh para el contexto y la política de seguridad).
#
# Un repositorio de terceros roto hace que `apt-get update` devuelva error
# de forma permanente, y eso degradaba a TODOS los instaladores APT del
# proyecto. Los instaladores ya no fallan por eso, pero mientras el
# repositorio siga ahí cada instalación arrastra ruido y no ve paquetes
# nuevos de ese origen. Esto lo limpia.
#
# SEGURO POR DEFECTO: sin argumentos solo REPORTA, no toca nada. Para
# actuar hay que pedirlo explícitamente con '--apply', y en ese caso cada
# archivo se respalda antes de deshabilitarse. Nunca se borra nada.
#
# Uso:
#   scripts/maintenance/repair_apt_sources.sh              # solo reporta
#   scripts/maintenance/repair_apt_sources.sh --apply      # respalda y deshabilita
#
# Revertir: renombrar el '.disabled' de vuelta, o recuperar la copia del
# backup (la ruta exacta se imprime al deshabilitar).

set -Eeuo pipefail

UCI_REPAIR_APT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/logging.sh
source "${UCI_REPAIR_APT_SCRIPT_DIR}/../lib/logging.sh"
# shellcheck source=../lib/apt_sources.sh
source "${UCI_REPAIR_APT_SCRIPT_DIR}/../lib/apt_sources.sh"

UCI_APPLY=0
for arg in "$@"; do
    case "${arg}" in
        --apply)
            UCI_APPLY=1
            ;;
        --help|-h)
            echo "Uso: $(basename "$0") [--apply]"
            echo ""
            echo "Sin argumentos: reporta los repositorios APT rotos, sin tocar nada."
            echo "Con --apply:    respalda y deshabilita cada uno (renombra a .disabled)."
            exit 0
            ;;
        *)
            log_error "Argumento desconocido: '${arg}'. Usá --help."
            exit 1
            ;;
    esac
done

log_info "Consultando el estado de los repositorios APT..."
UCI_UPDATE_LOG="$(mktemp)"
trap 'rm -f "${UCI_UPDATE_LOG}"' EXIT
apt_sources_update_output > "${UCI_UPDATE_LOG}"

UCI_BROKEN_URIS=()
while IFS= read -r uri; do
    [[ -n "${uri}" ]] && UCI_BROKEN_URIS+=("${uri}")
done < <(apt_sources_broken_uris "${UCI_UPDATE_LOG}")

if [[ "${#UCI_BROKEN_URIS[@]}" -eq 0 ]]; then
    log_success "No hay repositorios APT rotos: 'apt-get update' no reportó ningún 'Err:'."
    exit 0
fi

log_warn "Repositorios APT con problemas: ${#UCI_BROKEN_URIS[@]}"
echo ""

# Sesión de backup con timestamp, bajo la misma raíz que el resto del
# proyecto (AGENT.md §11). Se crea recién si hay algo que respaldar.
UCI_BACKUP_DIR=""
if [[ "${UCI_APPLY}" -eq 1 ]]; then
    UCI_BACKUP_DIR="${HOME}/.local/state/ubuntu-workstation/backups/apt-sources-$(date +%Y%m%dT%H%M%S)"
    mkdir -p "${UCI_BACKUP_DIR}"
    log_info "Sesión de backup: ${UCI_BACKUP_DIR}"
    echo ""
fi

UCI_DISABLED=0
UCI_UNMAPPED=0

for uri in "${UCI_BROKEN_URIS[@]}"; do
    echo "  Repositorio roto: ${uri}"

    # Motivo, tal como lo reportó APT (útil para decidir si conviene
    # arreglarlo en vez de deshabilitarlo).
    reason="$(grep -A2 -F -- "${uri}" "${UCI_UPDATE_LOG}" 2>/dev/null | grep -vE '^(Err|Obj|Des|Ign|Hit|Get):' | head -1 | sed 's/^[[:space:]]*//' || true)"
    [[ -n "${reason}" ]] && echo "    Motivo: ${reason}"

    files=()
    while IFS= read -r f; do
        [[ -n "${f}" ]] && files+=("${f}")
    done < <(apt_sources_files_for_uri "${uri}")

    if [[ "${#files[@]}" -eq 0 ]]; then
        echo "    No se encontró qué archivo lo declara; hay que revisarlo a mano."
        UCI_UNMAPPED=$((UCI_UNMAPPED + 1))
        echo ""
        continue
    fi

    for file in "${files[@]}"; do
        if [[ "${UCI_APPLY}" -eq 0 ]]; then
            echo "    Declarado en: ${file}"
            echo "    [reporte] con --apply se respaldaría y se deshabilitaría."
            continue
        fi

        backup_path="$(apt_sources_backup_file "${file}" "${UCI_BACKUP_DIR}")"
        echo "    Respaldado en: ${backup_path}"
        if disabled_path="$(apt_sources_disable_file "${file}")"; then
            echo "    Deshabilitado: ${disabled_path}"
            UCI_DISABLED=$((UCI_DISABLED + 1))
        fi
    done
    echo ""
done

echo "== Resumen =="
echo "Repositorios rotos detectados: ${#UCI_BROKEN_URIS[@]}"
if [[ "${UCI_APPLY}" -eq 1 ]]; then
    echo "Archivos deshabilitados: ${UCI_DISABLED}"
    [[ "${UCI_UNMAPPED}" -gt 0 ]] && echo "Sin archivo identificable (revisar a mano): ${UCI_UNMAPPED}"
    echo "Backup: ${UCI_BACKUP_DIR}"
    echo ""
    log_info "Verificando que 'apt-get update' quede limpio..."
    UCI_VERIFY_LOG="$(mktemp)"
    apt_sources_update_output > "${UCI_VERIFY_LOG}"
    remaining="$(apt_sources_broken_uris "${UCI_VERIFY_LOG}" | wc -l)"
    rm -f "${UCI_VERIFY_LOG}"
    if [[ "${remaining}" -eq 0 ]]; then
        log_success "'apt-get update' ya no reporta repositorios rotos."
    else
        log_warn "Todavía quedan ${remaining} repositorio(s) con problemas; revisá la salida de arriba."
    fi
else
    echo ""
    log_info "No se modificó nada. Para respaldar y deshabilitar estos repositorios:"
    echo "  ./setup.sh repair-apt --apply"
fi
