#!/usr/bin/env bash
# scripts/diagnostics/doctor.sh
#
# Diagnóstico de solo lectura de la workstation. Nunca modifica el sistema.
# Ver docs/ROADMAP.md (Hito 4: Doctor), AGENT.md sección 10 y el apéndice de
# rutas de home retenido en docs/adr/0003-migracion-nvm-sin-borrado-directo.md.
#
# Pensado para cargarse con `source`; no declara `set -Eeuo pipefail`
# (ver docs/adr/0022-modo-estricto-en-bibliotecas-sourceadas.md). Cada
# comando externo que se ejecuta aquí es de solo lectura (status/--version/
# info), nunca de escritura.

if [[ "${UCI_DOCTOR_SH_LOADED:-0}" == "1" ]]; then
    return 0
fi
UCI_DOCTOR_SH_LOADED=1

UCI_DOCTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_DOCTOR_SCRIPT_DIR
UCI_DOCTOR_REPO_ROOT="$(cd "${UCI_DOCTOR_SCRIPT_DIR}/../.." && pwd)"
readonly UCI_DOCTOR_REPO_ROOT
# shellcheck source=../lib/logging.sh
source "${UCI_DOCTOR_SCRIPT_DIR}/../lib/logging.sh"
# shellcheck source=../lib/runtime.sh
source "${UCI_DOCTOR_SCRIPT_DIR}/../lib/runtime.sh"
# shellcheck source=../lib/tools_catalog.sh
source "${UCI_DOCTOR_SCRIPT_DIR}/../lib/tools_catalog.sh"

# Rutas que pueden ya existir en un /home reutilizado.
# Ver docs/adr/0003-migracion-nvm-sin-borrado-directo.md (apéndice).
UCI_DOCTOR_HOME_PATHS=(
    ".nvm"
    ".config/mise"
    ".local/share/mise"
    ".npm"
    ".cache"
    ".bashrc"
    ".zshrc"
    ".profile"
    ".gitconfig"
    ".ssh"
    ".config/Code"
    ".config/Cursor"
    ".docker"
)
readonly UCI_DOCTOR_HOME_PATHS

doctor_line() {
    printf '%-28s %s\n' "$1" "$2"
}

doctor_detect_os() {
    if [[ -r /etc/os-release ]]; then
        local pretty_name
        pretty_name="$(. /etc/os-release; echo "${PRETTY_NAME:-}")"
        if [[ -n "${pretty_name}" ]]; then
            echo "${pretty_name}"
            return 0
        fi
    fi
    echo "$(uname -s) $(uname -r)"
    return 0
}

doctor_detect_arch() {
    uname -m
}

doctor_detect_shell() {
    echo "${SHELL:-desconocido}"
}

# doctor_check_mise <home_dir>
# Igual que doctor_check_command, pero resuelve el binario de Mise con
# runtime_resolve_mise_bin (ruta canónica ~/.local/bin/mise o PATH) en vez
# de solo 'command -v mise'. Antes de esto, doctor.sh y scripts/lib/runtime.sh
# podían contradecirse sobre si Mise está instalado en la misma máquina
# (ver docs/TECHNICAL_REVIEW.md, hallazgo A3).
doctor_check_mise() {
    local home_dir="$1"
    local mise_bin
    if ! mise_bin="$(runtime_resolve_mise_bin "${home_dir}")"; then
        doctor_line "Mise:" "no instalado"
        return 0
    fi

    local version_output=""
    version_output="$("${mise_bin}" --version 2>&1 | head -n1 || true)"

    if [[ -n "${version_output}" ]]; then
        doctor_line "Mise:" "instalado (${version_output}, ${mise_bin})"
    else
        doctor_line "Mise:" "instalado (${mise_bin})"
    fi
}

# doctor_check_command <etiqueta> <comando> [args de versión...]
# Imprime "instalado (versión)" o "no instalado". Nunca hace que el reporte
# se detenga si el comando no existe o su flag de versión no es soportado.
doctor_check_command() {
    local label="$1" bin="$2"
    shift 2

    if ! command -v "${bin}" >/dev/null 2>&1; then
        doctor_line "${label}:" "no instalado"
        return 0
    fi

    local version_output=""
    if [[ $# -gt 0 ]]; then
        version_output="$("${bin}" "$@" 2>&1 | head -n1 || true)"
    fi

    if [[ -n "${version_output}" ]]; then
        doctor_line "${label}:" "instalado (${version_output})"
    else
        doctor_line "${label}:" "instalado"
    fi
    return 0
}

# doctor_detect_node_source <home_dir>
doctor_detect_node_source() {
    local home_dir="$1"
    local node_path
    node_path="$(command -v node 2>/dev/null || true)"

    if [[ -z "${node_path}" ]]; then
        echo "no instalado"
        return 0
    fi

    local version
    version="$(node --version 2>/dev/null || true)"

    local source="desconocida"
    case "${node_path}" in
        "${home_dir}"/.nvm/*)
            source="nvm"
            ;;
        "${home_dir}"/.local/share/mise/*|"${home_dir}"/.config/mise/*)
            source="mise"
            ;;
        /snap/*)
            source="snap"
            ;;
        /usr/*)
            source="apt/sistema"
            ;;
    esac

    echo "instalado (${version:-versión desconocida}) vía ${source} (${node_path})"
    return 0
}

doctor_check_docker_daemon() {
    if ! command -v docker >/dev/null 2>&1; then
        echo "no instalado"
        return 0
    fi

    local version
    version="$(docker --version 2>/dev/null || true)"

    if docker info >/dev/null 2>&1; then
        echo "instalado (${version:-versión desconocida}) - demonio: activo"
    else
        echo "instalado (${version:-versión desconocida}) - demonio: inactivo o inaccesible"
    fi
    return 0
}

# Solo reporta cantidad de archivos de clave; nunca lee ni imprime su
# contenido (ver AGENT.md sección 16, Seguridad).
# doctor_check_ssh <home_dir>
doctor_check_ssh() {
    local home_dir="$1"
    local ssh_dir="${home_dir}/.ssh"

    if [[ ! -d "${ssh_dir}" ]]; then
        echo "no existe ${ssh_dir}"
        return 0
    fi

    local key_count
    key_count="$(find "${ssh_dir}" -maxdepth 1 -type f \( -name 'id_*' -o -name '*.pub' \) 2>/dev/null | wc -l || true)"
    echo "${ssh_dir} existe (${key_count} archivo(s) de clave detectado(s), no se leyó su contenido)"
    return 0
}

# doctor_check_home_reuse_indicators <home_dir> <verbose:0|1>
doctor_check_home_reuse_indicators() {
    local home_dir="$1" verbose="$2"
    local present=0
    local total=${#UCI_DOCTOR_HOME_PATHS[@]}
    local details=()

    local rel_path
    for rel_path in "${UCI_DOCTOR_HOME_PATHS[@]}"; do
        if [[ -e "${home_dir}/${rel_path}" ]]; then
            present=$((present + 1))
            details+=("  ✓ ${home_dir}/${rel_path}")
        else
            details+=("  ✗ ${home_dir}/${rel_path}")
        fi
    done

    doctor_line "Indicadores de home retenido:" "${present}/${total} rutas presentes"

    if [[ "${verbose}" == "1" ]]; then
        local line
        for line in "${details[@]}"; do
            echo "${line}"
        done
    fi
    return 0
}

# doctor_check_path
# Hito 12 (Framework de validación, ver docs/ROADMAP.md): detecta entradas
# vacías/duplicadas en PATH y confirma que el bin de Mise (~/.local/bin)
# esté presente — sin eso, ningún runtime/CLI instalado vía Mise se resuelve
# aunque runtime.sh lo detecte por su ruta canónica.
# doctor_check_path <home_dir>
doctor_check_path() {
    local home_dir="$1"
    local -a parts
    IFS=':' read -ra parts <<< "${PATH:-}"

    local empty=0 dup=0
    local -A seen=()
    local part
    for part in "${parts[@]}"; do
        if [[ -z "${part}" ]]; then
            empty=$((empty + 1))
            continue
        fi
        if [[ -n "${seen[${part}]:-}" ]]; then
            dup=$((dup + 1))
        else
            seen["${part}"]=1
        fi
    done

    local mise_bin_dir="${home_dir}/.local/bin"
    local mise_in_path="no"
    if [[ ":${PATH:-}:" == *":${mise_bin_dir}:"* ]]; then
        mise_in_path="sí"
    fi

    doctor_line "PATH:" "${#parts[@]} entrada(s), ${empty} vacía(s), ${dup} duplicada(s), Mise (${mise_bin_dir}) en PATH: ${mise_in_path}"
    return 0
}

# doctor_check_executables
# Hito 12: recorre tools_catalog.sh y confirma que cada script registrado
# exista Y tenga el bit +x — el mismo tipo de bug real detectado en la
# migración de terminales nuevas (5 instaladores quedaron sin +x, lo que
# rompe setup.js porque invoca los scripts directamente sin `bash`, ver
# docs/ARCHITECTURE.md). No instala ni modifica nada, solo `-f`/`-x`.
# doctor_check_executables <repo_root> <verbose:0|1>
doctor_check_executables() {
    local repo_root="$1" verbose="$2"
    local total=0 ok=0
    local -a broken=()

    local id script_field script_path
    while IFS= read -r id; do
        [[ -z "${id}" ]] && continue
        total=$((total + 1))
        script_field="$(tools_registry_field "${id}" "script")"
        script_path="${repo_root}/${script_field}"

        if [[ -f "${script_path}" && -x "${script_path}" ]]; then
            ok=$((ok + 1))
        else
            broken+=("${id} (${script_field})")
        fi
    done < <(tools_registry_ids)

    doctor_line "Ejecutables (catálogo):" "${ok}/${total} scripts existen y son ejecutables"

    if [[ "${verbose}" == "1" && ${#broken[@]} -gt 0 ]]; then
        local entry
        for entry in "${broken[@]}"; do
            echo "  ✗ ${entry}"
        done
    fi
    return 0
}

# doctor_check_shared_dependencies
# Hito 12: confirma la presencia de dependencias que varios
# scripts/lib/*.sh dan por sentadas sin chequear ellos mismos (curl para
# descargar claves/paquetes/.deb, gpg para dearmorar claves de
# repositorios de proveedor, add-apt-repository para PPAs). No instala
# nada; si falta alguna, solo se reporta — instalarlas es responsabilidad
# de los instaladores que las necesiten (ver AGENT.md sección 15).
doctor_check_shared_dependencies() {
    local -a missing=()
    local bin
    for bin in curl gpg add-apt-repository; do
        if ! command -v "${bin}" >/dev/null 2>&1; then
            missing+=("${bin}")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        doctor_line "Dependencias compartidas:" "curl/gpg/add-apt-repository presentes"
    else
        doctor_line "Dependencias compartidas:" "faltan: ${missing[*]}"
    fi
    return 0
}

# doctor_check_broken_symlinks <home_dir> <verbose:0|1>
# Hito 12: detecta symlinks rotos (dangling) en $HOME, relevante al
# reutilizar un /home existente (ADR 0021: dotfiles/config previa puede
# apuntar a rutas que ya no existen). Limitado a profundidad 4 y excluye
# directorios pesados/no relevantes (.cache, .npm, node_modules) para que
# 'doctor' siga siendo liviano en un $HOME real, no solo en el vacío de
# pruebas.
doctor_check_broken_symlinks() {
    local home_dir="$1" verbose="$2"
    local broken_list=""
    broken_list="$(find "${home_dir}" -maxdepth 4 \
        \( -path "${home_dir}/.cache" -o -path "${home_dir}/.npm" -o -name node_modules \) -prune -o \
        -xtype l -print 2>/dev/null || true)"

    local count=0
    if [[ -n "${broken_list}" ]]; then
        count="$(printf '%s\n' "${broken_list}" | grep -c .)"
    fi

    doctor_line "Symlinks rotos en \$HOME:" "${count} detectado(s) (profundidad ≤4, sin .cache/.npm/node_modules)"

    if [[ "${verbose}" == "1" && "${count}" -gt 0 ]]; then
        local link_path
        while IFS= read -r link_path; do
            [[ -z "${link_path}" ]] && continue
            echo "  ✗ ${link_path}"
        done <<< "${broken_list}"
    fi
    return 0
}

# doctor_run <home_dir> [--verbose|-v]
# Nunca modifica el sistema. Retorna != 0 solo por una opción inválida
# (error de invocación), nunca porque falte alguna herramienta.
doctor_run() {
    local home_dir="$1"
    shift

    local verbose=0
    local arg
    for arg in "$@"; do
        case "${arg}" in
            --verbose|-v)
                verbose=1
                ;;
            *)
                log_error "Opción desconocida para 'doctor': '${arg}'"
                return 1
                ;;
        esac
    done

    echo "Ubuntu Workstation - Doctor"
    echo "=========================="
    doctor_line "Home usado por Doctor:" "${home_dir}"
    doctor_line "Sistema operativo:" "$(doctor_detect_os)"
    doctor_line "Arquitectura:" "$(doctor_detect_arch)"
    doctor_line "Shell activo:" "$(doctor_detect_shell)"
    echo ""
    doctor_check_command "apt" apt-get --version
    doctor_check_command "snap" snap --version
    doctor_check_command "Git" git --version
    doctor_line "Docker:" "$(doctor_check_docker_daemon)"
    doctor_line "Node.js:" "$(doctor_detect_node_source "${home_dir}")"
    doctor_check_mise "${home_dir}"
    doctor_check_command "AWS CLI" aws --version
    doctor_check_command "kubectl" kubectl version --client
    doctor_check_command "Helm" helm version --short
    echo ""
    doctor_line "SSH:" "$(doctor_check_ssh "${home_dir}")"
    doctor_check_home_reuse_indicators "${home_dir}" "${verbose}"

    if [[ "${verbose}" == "1" && -d "${home_dir}/.nvm/versions/node" ]]; then
        echo ""
        echo "Versiones de Node instaladas vía NVM:"
        find "${home_dir}/.nvm/versions/node" -maxdepth 1 -mindepth 1 -type d -printf '  %f\n' 2>/dev/null || true
    fi

    echo ""
    echo "-- Framework de validación (Hito 12) --"
    doctor_check_path "${home_dir}"
    doctor_check_executables "${UCI_DOCTOR_REPO_ROOT}" "${verbose}"
    doctor_check_shared_dependencies
    doctor_check_broken_symlinks "${home_dir}" "${verbose}"
    echo ""
    echo "Versiones de runtime (Mise):"
    runtime_status_all "${home_dir}"

    return 0
}
