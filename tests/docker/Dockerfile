# tests/docker/Dockerfile
#
# Imagen desechable para probar Ubuntu Workstation de punta a punta,
# incluyendo operaciones que instalan software real o modifican archivos de
# shell (por ejemplo, la migración NVM -> Mise del Hito 7), sin arriesgar la
# máquina de desarrollo real. Ver docs/TESTING.md.
#
# Uso:
#   docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test:24.04 -f tests/docker/Dockerfile .
#   docker build --build-arg UBUNTU_VERSION=26.04 -t ubuntu-workstation-test:26.04 -f tests/docker/Dockerfile .
#   docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/run-all-tests.sh
#   docker run --rm -it ubuntu-workstation-test:24.04 bash   # shell interactiva

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo \
        bash \
        curl \
        wget \
        ca-certificates \
        git \
        nodejs \
        npm \
        findutils \
        procps \
    && rm -rf /var/lib/apt/lists/*

ARG TEST_USER=workstation
RUN useradd -m -s /bin/bash "${TEST_USER}" \
    && echo "${TEST_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${TEST_USER}" \
    && chmod 0440 "/etc/sudoers.d/90-${TEST_USER}"

USER ${TEST_USER}
WORKDIR /home/${TEST_USER}/ubuntu-commons-installer

COPY --chown=${TEST_USER}:${TEST_USER} . /home/${TEST_USER}/ubuntu-commons-installer

CMD ["/bin/bash"]
