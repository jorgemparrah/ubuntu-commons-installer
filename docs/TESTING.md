# TESTING.md

# Cómo probar Ubuntu Workstation

Este documento explica cómo validar el repositorio sin arriesgar la máquina de desarrollo real, especialmente para lo que instala software real o modifica archivos de shell (por ejemplo, la migración NVM → Mise del Hito 7).

## Niveles de prueba

1. **Sintaxis y pruebas unitarias/de contrato** (`bash -n`, ShellCheck, `tests/*.sh`, `tests/*.js`): seguras en cualquier máquina, incluida la de desarrollo. No instalan nada ni tocan `$HOME` real — usan `UCI_HOME_DIR` apuntando a un directorio temporal (ver `docs/adr/0023-variable-uci-home-dir-para-pruebas.md`).
2. **Pruebas que instalan software real o modifican `$HOME` de verdad** (por ejemplo, instalar NVM y correr `setup.sh migrate` para probar la migración a Mise): **solo dentro de un contenedor Docker desechable** (ver más abajo). Nunca contra el `$HOME` real de una máquina de desarrollo.
3. **Validación final en una máquina o VM real** (Ubuntu 24.04 / 26.04, con `/home` reutilizado si aplica): el objetivo final del proyecto, pero no un requisito para cada cambio pequeño.

## Nivel 1 — Sintaxis y pruebas unitarias

Desde la raíz del repositorio:

```bash
bash -n setup.sh
find scripts -type f -name '*.sh' -exec bash -n {} \;

# ShellCheck si está disponible (no se instala automáticamente)
shellcheck setup.sh scripts/lib/*.sh scripts/bootstrap/*.sh scripts/diagnostics/*.sh scripts/migrations/*.sh

node --check setup.js
node --check scripts/lib/status_contract.js

bash tests/test_router.sh
bash tests/test_doctor.sh
bash tests/test_backup.sh
bash tests/test_migrations.sh
node tests/test_status_mapping.js
```

## Nivel 2 — Contenedor Docker desechable

`tests/docker/Dockerfile` construye una imagen de Ubuntu (24.04 o 26.04) con un usuario no root con `sudo` sin contraseña, y el repositorio copiado adentro. Todo lo que pase ahí se pierde al borrar el contenedor: es seguro instalar NVM, Mise, Docker, lo que sea.

### Construir la imagen

```bash
# Ubuntu 24.04 (default)
docker build --build-arg UBUNTU_VERSION=24.04 -t ubuntu-workstation-test:24.04 -f tests/docker/Dockerfile .

# Ubuntu 26.04
docker build --build-arg UBUNTU_VERSION=26.04 -t ubuntu-workstation-test:26.04 -f tests/docker/Dockerfile .
```

Si la etiqueta `ubuntu:26.04` todavía no existe en Docker Hub al momento de correr esto, el build de 26.04 fallará al descargar la imagen base — no es un problema del Dockerfile, hay que esperar a que Canonical/Docker publiquen esa etiqueta o usar una imagen equivalente mientras tanto.

### Correr toda la batería de pruebas dentro del contenedor

```bash
docker run --rm ubuntu-workstation-test:24.04 bash tests/docker/run-all-tests.sh
docker run --rm ubuntu-workstation-test:26.04 bash tests/docker/run-all-tests.sh
```

### Shell interactiva para explorar/depurar

```bash
docker run --rm -it ubuntu-workstation-test:24.04 bash
```

Dentro del contenedor, el repositorio vive en `~/ubuntu-commons-installer` (el nombre del repo, aunque el proyecto se llame internamente Ubuntu Workstation — ver `docs/adr/0015-idioma-de-la-documentacion.md` y el `AGENT.md`).

### Probar la migración NVM → Mise (Hito 7) de punta a punta

Dentro de una sesión interactiva del contenedor:

```bash
cd ~/ubuntu-commons-installer

# 1. Simular un home con NVM ya instalado (como si fuera una instalación previa)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc
nvm install --lts

# 2. Confirmar el estado "antes" (debería mostrar Node vía nvm, sin Mise)
./setup.sh doctor --verbose

# 3. Ver qué haría la migración sin aplicar nada
./setup.sh migrate --list
./setup.sh migrate --dry-run

# 4. Aplicar de verdad (SOLO dentro del contenedor)
./setup.sh migrate

# 5. Confirmar el resultado
./setup.sh doctor --verbose
./setup.sh migrate --list   # la migración debería aparecer como "hecha"

# 6. Correr la migración de nuevo: no debería reaplicarse
./setup.sh migrate
```

Si algo sale mal, no hay nada que limpiar: se borra el contenedor (`exit`, y el `--rm` lo elimina) y se empieza de nuevo con `docker run`.

## Qué no reemplaza esto

Los contenedores Docker no tienen systemd por defecto, así que servicios como el demonio de Docker-dentro-de-Docker, algunos paquetes que dependen de systemd, o el comportamiento real de GNOME/atajos de teclado (Flameshot, `xdg-desktop-portal`, etc.) no se pueden validar ahí. Para eso sigue haciendo falta una VM o máquina real con escritorio, como se documenta en `docs/ROADMAP.md` y `docs/adr/0003-migracion-nvm-sin-borrado-directo.md`.
