#!/usr/bin/env bash
# tests/docker/test_docker_apt_repo.sh
#
# Prueba funcional acotada de scripts/development/install_docker.sh (Hito
# 9, Fase B). NO ejecuta el demonio de Docker ni depende de systemd, y NO
# usa Docker-en-Docker privilegiado: solo valida que el mecanismo de
# instalación (detección de arquitectura/codename, clave, repo, apt
# update, disponibilidad e instalación del paquete) funcione, hasta donde
# el paquete lo permita sin arrancar el demonio.
#
# Si Docker Inc. todavía no publica paquetes para el codename de esta
# imagen (riesgo ya documentado en docs/UBUNTU_COMPATIBILITY.md: el
# script no tiene fallback, y no debe agregársele uno inseguro hacia otra
# versión de Ubuntu), esta prueba lo detecta explícitamente y lo reporta
# como LIMITACIÓN DE PROVEEDOR (no como un fallo del script), sin marcar
# el caso como FALLO.
#
# SOLO debe correr dentro de un contenedor Docker desechable.
#
# Uso (desde el host):
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/test_docker_apt_repo.sh
#   docker run --rm ubuntu-workstation-test:26.04 bash tests/docker/test_docker_apt_repo.sh
set -Eeuo pipefail

if [[ ! -f /.dockerenv ]]; then
    echo "Este script agrega un repo APT e intenta instalar paquetes reales." >&2
    echo "Solo debe correr dentro de un contenedor Docker desechable. Abortando." >&2
    exit 1
fi

UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly UCI_TEST_DIR
UCI_REPO_ROOT="$(cd "${UCI_TEST_DIR}/.." && pwd)"
readonly UCI_REPO_ROOT
INSTALL_DOCKER_SH="${UCI_REPO_ROOT}/scripts/development/install_docker.sh"
readonly INSTALL_DOCKER_SH

FAILED=0
check() {
    local description="$1" condition="$2"
    if eval "${condition}"; then
        echo "  OK  - ${description}"
    else
        echo "FALLO - ${description}"
        FAILED=1
    fi
}

echo "== 1. status antes de instalar =="
set +e
OUTPUT="$("${INSTALL_DOCKER_SH}" status 2>&1)"
CODE=$?
set -e
check "'status' reporta NOT_INSTALLED antes de instalar" '[[ "${OUTPUT}" == *"NOT_INSTALLED"* ]]'
check "'status' sale con código distinto de cero antes de instalar" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 2. subcomando inválido =="
set +e
"${INSTALL_DOCKER_SH}" esto-no-existe >/dev/null 2>&1
CODE=$?
set -e
check "subcomando inválido sale con código distinto de cero" '[[ ${CODE} -ne 0 ]]'

echo ""
echo "== 3. detección de arquitectura y codename (esta máquina) =="
DETECTED_ARCH="$(dpkg --print-architecture)"
DETECTED_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
echo "Arquitectura detectada: ${DETECTED_ARCH}"
echo "Codename detectado: ${DETECTED_CODENAME}"
check "se detectó una arquitectura no vacía" '[[ -n "${DETECTED_ARCH}" ]]'
check "se detectó un codename no vacío" '[[ -n "${DETECTED_CODENAME}" ]]'
check "el script usa detección dinámica de arquitectura (dpkg --print-architecture)" 'grep -q "dpkg --print-architecture" "${INSTALL_DOCKER_SH}"'
check "el script usa detección dinámica de codename (VERSION_CODENAME)" 'grep -q "VERSION_CODENAME" "${INSTALL_DOCKER_SH}"'

# Se ignoran los comentarios: este propio archivo (y docs/UBUNTU_COMPATIBILITY.md)
# documentan en prosa qué codenames NO debe usar el script como fallback —
# eso no debe confundirse con código real (hallazgo M5 de
# docs/TECHNICAL_REVIEW.md, mismo criterio ya aplicado en
# tests/test_kernel_hwe_fallback.sh y tests/test_install_nodejs_legacy.sh).
install_docker_code_only() {
    grep -vE '^\s*#' "${INSTALL_DOCKER_SH}"
}
check "el script no tiene un fallback hacia el codename de otra versión de Ubuntu" '! install_docker_code_only | grep -qE "focal|jammy|bionic|xenial"'

echo ""
echo "== 4. install (real, hasta donde el proveedor lo permita) =="
set +e
INSTALL_OUTPUT="$("${INSTALL_DOCKER_SH}" install 2>&1)"
INSTALL_CODE=$?
set -e
echo "${INSTALL_OUTPUT}" | tail -30

echo ""
echo "== 5. la clave y el repo se crean SIEMPRE, incluso si el paquete no está disponible aún =="
check "el keyring quedó en /etc/apt/keyrings/docker.asc (no vacío)" '[[ -s /etc/apt/keyrings/docker.asc ]]'
check "el archivo de repo declara signed-by" 'grep -q "signed-by=/etc/apt/keyrings/docker.asc" /etc/apt/sources.list.d/docker.list'
check "el archivo de repo declara la arquitectura detectada (${DETECTED_ARCH})" 'grep -q "arch=${DETECTED_ARCH}" /etc/apt/sources.list.d/docker.list'
check "el archivo de repo declara el codename detectado (${DETECTED_CODENAME})" 'grep -q "${DETECTED_CODENAME}" /etc/apt/sources.list.d/docker.list'
check "el archivo de repo no depende de apt-key" '! grep -qi "apt-key" /etc/apt/sources.list.d/docker.list'

echo ""
echo "== 6. disponibilidad del paquete docker-ce para este codename =="
CANDIDATE_VERSION="$(apt-cache policy docker-ce 2>/dev/null | grep -m1 'Candidate:' | awk '{print $2}' || true)"
echo "Candidato de docker-ce según apt-cache policy: ${CANDIDATE_VERSION:-<ninguno>}"

if [[ -z "${CANDIDATE_VERSION}" || "${CANDIDATE_VERSION}" == "(none)" ]]; then
    echo ""
    echo "############################################################"
    echo "LIMITACIÓN DE PROVEEDOR (no es un fallo del script): Docker Inc."
    echo "todavía no publica paquetes para el codename '${DETECTED_CODENAME}'"
    echo "(arquitectura ${DETECTED_ARCH}). El repo/clave se agregaron"
    echo "correctamente; 'apt-get install docker-ce' no tiene candidato."
    echo "No se implementa un fallback hacia otra versión de Ubuntu (sería"
    echo "inseguro/incorrecto). Este caso se documenta explícitamente en"
    echo "docs/UBUNTU_COMPATIBILITY.md, no se fuerza como 'compatible'."
    echo "############################################################"
    echo ""
    echo "== Resumen =="
    if [[ "${FAILED}" -eq 0 ]]; then
        echo "TODO OK (con limitación de proveedor documentada arriba): el mecanismo de instalación de Docker es correcto; el paquete no está disponible todavía para este codename."
    else
        echo "Hubo fallos reales en el mecanismo (ver arriba), más allá de la limitación de proveedor."
    fi
    exit "${FAILED}"
fi

echo ""
echo "== 7. el paquete SÍ está disponible: confirmar que 'install' realmente lo instaló =="
check "'install' sale con código 0" '[[ ${INSTALL_CODE} -eq 0 ]]'
check "el paquete 'docker-ce' quedó instalado" 'dpkg -l docker-ce 2>/dev/null | grep -q "^ii"'

OUTPUT="$("${INSTALL_DOCKER_SH}" status 2>&1)"
CODE=$?
check "'status' reporta INSTALLED después de instalar" '[[ "${OUTPUT}" == *"INSTALLED"* ]]'
check "'status' sale con código 0 después de instalar" '[[ ${CODE} -eq 0 ]]'
check "el cliente 'docker' resuelve (sin depender del demonio)" 'command -v docker &>/dev/null'

echo ""
echo "== 8. idempotencia: correr 'install' de nuevo no falla =="
"${INSTALL_DOCKER_SH}" install
SECOND_INSTALL_CODE=$?
check "una segunda corrida de 'install' sigue saliendo con código 0" '[[ ${SECOND_INSTALL_CODE} -eq 0 ]]'

echo ""
echo "== 9. update/reinstall/repair (Hito 11: contrato completo de 6 verbos) =="
"${INSTALL_DOCKER_SH}" update
UPDATE_CODE=$?
check "'update' sale con código 0" '[[ ${UPDATE_CODE} -eq 0 ]]'
"${INSTALL_DOCKER_SH}" reinstall
REINSTALL_CODE=$?
check "'reinstall' sale con código 0" '[[ ${REINSTALL_CODE} -eq 0 ]]'
check "el paquete 'docker-ce' sigue instalado después de 'reinstall'" 'dpkg -l docker-ce 2>/dev/null | grep -q "^ii"'
"${INSTALL_DOCKER_SH}" repair
REPAIR_CODE=$?
check "'repair' sale con código 0" '[[ ${REPAIR_CODE} -eq 0 ]]'
check "el cliente 'docker' sigue resolviendo después de 'repair'" 'command -v docker &>/dev/null'

echo ""
if [[ "${FAILED}" -eq 0 ]]; then
    echo "TODO OK: Docker se instala vía su repo APT oficial, paquete disponible para este codename."
else
    echo "Hubo fallos. Revisar la salida arriba."
fi

exit "${FAILED}"
