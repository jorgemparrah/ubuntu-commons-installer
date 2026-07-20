#!/usr/bin/env bash
# tests/docker/run_snap_functional.sh
#
# Orquesta el ciclo de vida de un contenedor con systemd+snapd reales
# (tests/docker/Dockerfile.snapd, ver
# docs/adr/0039-snapd-en-docker-para-ci-experimental.md): lo arranca en
# segundo plano con los flags que systemd necesita dentro de Docker
# (--privileged, --cgroupns=host, /sys/fs/cgroup montado), espera a que
# snapd esté listo, corre la prueba funcional real adentro vía
# 'docker exec', y para/limpia el contenedor pase lo que pase.
#
# EXPERIMENTAL: mecanismo nuevo, sin historial de estabilidad. No correr
# en esta workstation — solo dentro de CI o un entorno descartable que
# acepte contenedores privilegiados.
#
# Uso:
#   bash tests/docker/run_snap_functional.sh <imagen>
set -Eeuo pipefail

UCI_IMAGE="${1:?Uso: run_snap_functional.sh <imagen>}"
UCI_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UCI_TEST_DIR

UCI_CONTAINER_ID=""

cleanup() {
    if [[ -n "${UCI_CONTAINER_ID}" ]]; then
        docker rm -f "${UCI_CONTAINER_ID}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

echo "Arrancando ${UCI_IMAGE} con systemd (--privileged, --cgroupns=host)..."
UCI_CONTAINER_ID="$(docker run -d --privileged --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    "${UCI_IMAGE}")"

echo "Esperando a que systemd termine de arrancar (máx 60s)..."
UCI_READY=0
for _ in $(seq 1 60); do
    UCI_STATE="$(docker exec "${UCI_CONTAINER_ID}" systemctl is-system-running 2>/dev/null || true)"
    if [[ "${UCI_STATE}" == "running" || "${UCI_STATE}" == "degraded" ]]; then
        UCI_READY=1
        break
    fi
    sleep 1
done
if [[ "${UCI_READY}" -ne 1 ]]; then
    echo "systemd nunca llegó a running/degraded (último estado: '${UCI_STATE}')." >&2
    docker exec "${UCI_CONTAINER_ID}" systemctl list-units --failed 2>&1 || true
    exit 1
fi
echo "systemd listo (estado: ${UCI_STATE})."

echo "Esperando a que snapd esté listo (máx 60s)..."
if ! docker exec "${UCI_CONTAINER_ID}" timeout 60 snap wait system seed.loaded; then
    echo "snapd nunca terminó de inicializar (snap wait system seed.loaded)." >&2
    docker exec "${UCI_CONTAINER_ID}" systemctl status snapd.service 2>&1 || true
    exit 1
fi
echo "snapd listo."

echo "Corriendo la prueba funcional real dentro del contenedor..."
set +e
docker exec --user workstation \
    -w /home/workstation/ubuntu-commons-installer \
    "${UCI_CONTAINER_ID}" \
    bash tests/docker/test_snap_installers_functional.sh
UCI_EXIT_CODE=$?
set -e

exit "${UCI_EXIT_CODE}"
