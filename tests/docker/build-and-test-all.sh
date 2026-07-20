#!/usr/bin/env bash
# tests/docker/build-and-test-all.sh
#
# ÚNICO PUNTO DE ENTRADA para correr TODA la batería de pruebas del
# repositorio. Arma las imágenes de prueba (base, con NVM+1 versión, con
# NVM+2 versiones, con NVM+Mise ya preinstalado) para Ubuntu 24.04 y 26.04,
# y corre dentro de cada una
# los casos de prueba funcionales definidos en docs/TEST_CASES.md — esa
# tabla es la fuente de verdad; este script es su ejecución. Si agregas un
# caso nuevo a docs/TEST_CASES.md, agrega también su bloque acá.
#
# Uso (desde la raíz del repositorio, en el host):
#   bash tests/docker/build-and-test-all.sh
#   bash tests/docker/build-and-test-all.sh 24.04       # solo una versión de Ubuntu
#
# Todo lo que hace este script corre DENTRO de contenedores Docker
# desechables (`docker build`/`docker run`); nunca toca el $HOME real de
# la máquina donde se ejecuta.
set -Eeuo pipefail

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
DOCKER_DIR="${UCI_TEST_DIR}/docker"
readonly DOCKER_DIR

cd "${UCI_REPO_ROOT}"

if [[ $# -gt 0 ]]; then
    UBUNTU_VERSIONS=("$@")
else
    UBUNTU_VERSIONS=("24.04" "26.04")
fi
readonly UBUNTU_VERSIONS

# Toda la salida se ve en vivo por terminal Y queda guardada en un log fijo
# y predecible, para poder analizarla después (buscar fallos puntuales,
# adjuntarla a un reporte, etc.) sin tener que recordar una ruta distinta
# cada vez que se corre. UCI_LOG_LATEST siempre apunta a la corrida más
# reciente; UCI_LOG_FILE queda con timestamp para no perder corridas
# anteriores si se necesita compararlas.
UCI_LOG_DIR="/tmp/ubuntu-workstation-tests"
mkdir -p "${UCI_LOG_DIR}"
UCI_LOG_FILE="${UCI_LOG_DIR}/build-and-test-all-$(date +%Y%m%dT%H%M%S).log"
readonly UCI_LOG_FILE
UCI_LOG_LATEST="${UCI_LOG_DIR}/build-and-test-all-latest.log"
readonly UCI_LOG_LATEST

exec > >(tee "${UCI_LOG_FILE}") 2>&1
ln -sf "${UCI_LOG_FILE}" "${UCI_LOG_LATEST}"

echo "Log completo de esta corrida: ${UCI_LOG_FILE}"
echo "(siempre disponible también en: ${UCI_LOG_LATEST}, apunta a la corrida más reciente)"

FAILED=0
declare -a RESULTS=()

section() {
    echo ""
    echo "############################################################"
    echo "# $1"
    echo "############################################################"
}

record() {
    local label="$1" code="$2"
    if [[ "${code}" -eq 0 ]]; then
        RESULTS+=("OK    - ${label}")
    else
        RESULTS+=("FALLÓ - ${label}")
        FAILED=1
    fi
}

# run_case <ids_de_TEST_CASES.md> <tag_de_imagen> <descripcion> <script>
# Corre un caso (o grupo de casos) dentro de un contenedor desechable y
# registra el resultado. <ids_de_TEST_CASES.md> es solo para trazabilidad
# en la salida (por ejemplo "U01-U07" o "M02,M05").
run_case() {
    local ids="$1" tag="$2" description="$3" script="$4"
    section "[${ids}] Ubuntu ${ubuntu_version} — ${description}"
    set +e
    docker run --rm "${tag}" bash "${script}"
    local code=$?
    set -e
    record "[${ids}] Ubuntu ${ubuntu_version} / ${description}" "${code}"
}

for ubuntu_version in "${UBUNTU_VERSIONS[@]}"; do
    base_tag="ubuntu-workstation-test:${ubuntu_version}"
    single_tag="ubuntu-workstation-test-nvm-single:${ubuntu_version}"
    multi_tag="ubuntu-workstation-test-nvm-multi:${ubuntu_version}"
    mise_preexisting_tag="ubuntu-workstation-test-nvm-mise-preexisting:${ubuntu_version}"

    section "Ubuntu ${ubuntu_version} — construyendo imagen base"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${base_tag}" -f "${DOCKER_DIR}/Dockerfile" .

    section "Ubuntu ${ubuntu_version} — construyendo variante NVM (1 versión, alias default = lts/*)"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${single_tag}" -f "${DOCKER_DIR}/Dockerfile.nvm-single" .

    section "Ubuntu ${ubuntu_version} — construyendo variante NVM (2 versiones, alias default = la más vieja)"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${multi_tag}" -f "${DOCKER_DIR}/Dockerfile.nvm-multi" .

    section "Ubuntu ${ubuntu_version} — construyendo variante NVM + Mise ya preinstalado"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${mise_preexisting_tag}" -f "${DOCKER_DIR}/Dockerfile.nvm-mise-preexisting" .

    # Nivel 1 (docs/TEST_CASES.md, U01-U08): sintaxis, ShellCheck,
    # node --check, y todas las suites de tests/*.sh y tests/*.js
    # (router, doctor, backup, backup_move_dir, migrations, status_mapping).
    run_case "U01-U08" "${base_tag}" \
        "batería general (imagen base)" \
        "tests/docker/run-all-tests.sh"

    # Hito 2/7 estabilización: bootstrap interactivo vía Mise, nunca NVM.
    run_case "BOOT01" "${base_tag}" \
        "bootstrap interactivo vía Mise, sin NVM (imagen base)" \
        "tests/docker/test_bootstrap_mise_no_nvm.sh"

    # Nivel 3 (docs/TEST_CASES.md, R01-R06): gestor de runtimes centralizado
    # (scripts/lib/runtime.sh, setup.sh runtime status).
    run_case "R01-R05" "${base_tag}" \
        "gestor de runtimes (Node y Python vía Mise, imagen base)" \
        "tests/docker/test_runtime_status.sh"

    # Nivel 4 (Hito 9, Fase B): kubectl vía Mise, no vía Snap (ADR 0018).
    run_case "K01" "${base_tag}" \
        "kubectl vía Mise, no vía Snap (imagen base)" \
        "tests/docker/test_kubectl_via_mise.sh"

    # Nivel 4 (Hito 9, Fase B): Yarn vía Mise, no vía apt (ADR 0017).
    run_case "Y01" "${base_tag}" \
        "Yarn vía Mise, no vía apt (imagen base)" \
        "tests/docker/test_yarn_via_mise.sh"

    # Nivel 4 (Hito 9, Fase B): Oh My Zsh y Powerlevel10k instalan de
    # verdad el framework/tema, no solo el paquete zsh.
    run_case "Z01" "${base_tag}" \
        "Oh My Zsh y Powerlevel10k instalan el framework/tema real (imagen base)" \
        "tests/docker/test_zsh_personalization.sh"

    # Nivel 4 (Hito 9, Fase B): ULauncher agrega su PPA oficial faltante.
    run_case "L01" "${base_tag}" \
        "ULauncher agrega su PPA oficial antes de instalar (imagen base)" \
        "tests/docker/test_ulauncher_ppa.sh"

    # Nivel 4 (Hito 9, Fase B): Cursor vía su repo APT oficial (signed-by).
    run_case "C01" "${base_tag}" \
        "Cursor vía repo APT oficial, signed-by (imagen base)" \
        "tests/docker/test_cursor_apt_repo.sh"

    # Nivel 4 (Hito 9, Fase B): VS Code vía su repo APT oficial (signed-by).
    run_case "V01" "${base_tag}" \
        "VS Code vía repo APT oficial, signed-by (imagen base)" \
        "tests/docker/test_vscode_apt_repo.sh"

    # Nivel 4 (Hito 9, Fase B): Docker — mecanismo de repo (arch/codename
    # dinámicos), sin exigir que el daemon corra ni Docker-en-Docker.
    run_case "D01" "${base_tag}" \
        "Docker: repo oficial, arquitectura/codename dinámicos (imagen base)" \
        "tests/docker/test_docker_apt_repo.sh"

    # WezTerm: repo APT propio en Fury.io, "flat" (sin codename).
    run_case "W01" "${base_tag}" \
        "WezTerm: repo APT propio en Fury.io, signed-by (imagen base)" \
        "tests/docker/test_wezterm_apt_repo.sh"

    # Nivel 2 (docs/TEST_CASES.md, M01/M02/M05): desde cero, instalando NVM
    # en tiempo de ejecución dentro del propio contenedor.
    run_case "M01,M02,M05,M08" "${base_tag}" \
        "migración NVM->Mise instalando NVM en tiempo de ejecución (imagen base)" \
        "tests/docker/test_nvm_to_mise_apply.sh"

    # Nivel 2 (M03,M05): home reutilizado simple, NVM+1 versión ya en la imagen.
    run_case "M03,M05,M08" "${single_tag}" \
        "migración NVM->Mise con NVM+1 versión preinstalada" \
        "tests/docker/test_nvm_to_mise_prebaked.sh"

    # Nivel 2 (M04,M05): home reutilizado con múltiples versiones, alias
    # default != versión más alta detectada.
    run_case "M04,M05,M08" "${multi_tag}" \
        "migración NVM->Mise con NVM+2 versiones preinstaladas (alias default != versión más alta)" \
        "tests/docker/test_nvm_to_mise_prebaked.sh"

    # Nivel 2 (M06): Mise ya instalado antes de migrar (además de NVM+1 versión).
    run_case "M06" "${mise_preexisting_tag}" \
        "migración NVM->Mise con Mise ya preinstalado" \
        "tests/docker/test_nvm_to_mise_mise_preexisting.sh"

    # Nivel 2 (M07): apply falla a mitad de camino en 5 checkpoints distintos,
    # vía UCI_TEST_FAIL_MIGRATION_AT, y se verifica la recuperación posterior.
    run_case "M07" "${base_tag}" \
        "recuperación ante fallos parciales de la migración (inyección de fallos)" \
        "tests/docker/test_nvm_to_mise_fault_injection.sh"
done

section "Resumen general"
for line in "${RESULTS[@]}"; do
    echo "${line}"
done

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "RESULTADO: TODO PASÓ. Casos cubiertos (ver docs/TEST_CASES.md): U01-U08, I01-I05, I07-I10, I11-I16, BOOT01, M01-M08, R01-R06, K01, Y01, Z01, L01, C01, V01, D01."
else
    echo "RESULTADO: HUBO FALLOS. Revisa las líneas 'FALLÓ' arriba."
fi
echo "Log completo: ${UCI_LOG_FILE} (o ${UCI_LOG_LATEST} para la corrida más reciente)"

exit "${FAILED}"
