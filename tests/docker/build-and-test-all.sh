#!/usr/bin/env bash
# tests/docker/build-and-test-all.sh
#
# Arma todas las imágenes de prueba (base, con NVM+1 versión, con NVM+2
# versiones) para Ubuntu 24.04 y 26.04, y corre la batería de pruebas
# correspondiente en cada una dentro de contenedores desechables. Ver
# docs/TESTING.md.
#
# Uso (desde la raíz del repositorio, en el host):
#   bash tests/docker/build-and-test-all.sh
#   bash tests/docker/build-and-test-all.sh 24.04       # solo una versión de Ubuntu
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

for ubuntu_version in "${UBUNTU_VERSIONS[@]}"; do
    base_tag="ubuntu-workstation-test:${ubuntu_version}"
    single_tag="ubuntu-workstation-test-nvm-single:${ubuntu_version}"
    multi_tag="ubuntu-workstation-test-nvm-multi:${ubuntu_version}"

    section "Ubuntu ${ubuntu_version} — construyendo imagen base"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${base_tag}" -f "${DOCKER_DIR}/Dockerfile" .

    section "Ubuntu ${ubuntu_version} — construyendo variante NVM (1 versión)"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${single_tag}" -f "${DOCKER_DIR}/Dockerfile.nvm-single" .

    section "Ubuntu ${ubuntu_version} — construyendo variante NVM (2 versiones)"
    docker build --build-arg "UBUNTU_VERSION=${ubuntu_version}" -t "${multi_tag}" -f "${DOCKER_DIR}/Dockerfile.nvm-multi" .

    section "Ubuntu ${ubuntu_version} — batería general (imagen base)"
    set +e
    docker run --rm "${base_tag}" bash tests/docker/run-all-tests.sh
    code=$?
    set -e
    record "Ubuntu ${ubuntu_version} / imagen base / run-all-tests.sh" "${code}"

    section "Ubuntu ${ubuntu_version} — migración NVM->Mise instalando NVM en tiempo de ejecución (imagen base)"
    set +e
    docker run --rm "${base_tag}" bash tests/docker/test_nvm_to_mise_apply.sh
    code=$?
    set -e
    record "Ubuntu ${ubuntu_version} / imagen base / test_nvm_to_mise_apply.sh" "${code}"

    section "Ubuntu ${ubuntu_version} — migración NVM->Mise con NVM+1 versión preinstalada"
    set +e
    docker run --rm "${single_tag}" bash tests/docker/test_nvm_to_mise_prebaked.sh
    code=$?
    set -e
    record "Ubuntu ${ubuntu_version} / nvm-single / test_nvm_to_mise_prebaked.sh" "${code}"

    section "Ubuntu ${ubuntu_version} — migración NVM->Mise con NVM+2 versiones preinstaladas (alias default != versión más alta)"
    set +e
    docker run --rm "${multi_tag}" bash tests/docker/test_nvm_to_mise_prebaked.sh
    code=$?
    set -e
    record "Ubuntu ${ubuntu_version} / nvm-multi / test_nvm_to_mise_prebaked.sh" "${code}"
done

section "Resumen general"
for line in "${RESULTS[@]}"; do
    echo "${line}"
done

exit "${FAILED}"
