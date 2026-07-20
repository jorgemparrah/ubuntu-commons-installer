# 0039. snapd en Docker para CI (experimental)

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

Desde el cierre del Hito 9, los 8 instaladores Snap del catálogo (DBeaver, GitKraken, Insomnia, Postman, GIMP, Spotify, Zoom, Yazi) quedaron marcados `no verificable automáticamente`: `snapd` no corre sin `systemd`, y los contenedores de `tests/docker/Dockerfile` no lo tienen (corren un proceso suelto como PID 1, no un init real). La única evidencia era una prueba simulada (`tests/test_snap_installers_contract.sh`/`tests/test_snap_installers_full_contract.sh`, mocks de `snap`) más una pauta de validación manual en Ubuntu 26.04 Desktop real, documentada pero nunca ejecutada.

El dueño del proyecto pidió investigar si es posible correr `snapd` dentro de Docker para agregar cobertura automática en CI. La investigación confirma que es **técnicamente posible pero no oficialmente soportado**: requiere levantar `systemd` como PID 1 dentro del contenedor (`--privileged`, `--cgroupns=host`, `/sys/fs/cgroup` montado), un patrón documentado por proyectos de la comunidad (por ejemplo `ogra1/snapd-docker`), no por Canonical/Snapcraft. `--privileged` afloja significativamente el aislamiento del contenedor frente al resto de la matriz de CI de este proyecto.

Se le explicó este costo al dueño del proyecto antes de decidir (minutos de CI adicionales por instalar 8 apps GUI reales contra el Snap Store real, contenedores privilegiados, riesgo de fragilidad al no ser un mecanismo oficial) — decidió proceder aceptando ese costo.

## Decisión

Se agrega un mecanismo experimental, separado de la matriz principal de CI:

- `tests/docker/Dockerfile.snapd` — variante de la imagen base con `systemd`/`systemd-sysv`/`snapd`/`squashfuse` instalados, `CMD ["/sbin/init"]` (systemd real como PID 1) en vez de un shell suelto.
- `tests/docker/run_snap_functional.sh` — arranca el contenedor en segundo plano con los flags que `systemd` necesita, espera a que `systemctl is-system-running` llegue a `running`/`degraded` y a que `snap wait system seed.loaded` confirme que `snapd` terminó de inicializar, corre la prueba real vía `docker exec`, y para/limpia el contenedor siempre (éxito o error).
- `tests/docker/test_snap_installers_functional.sh` — instala y desinstala de verdad, contra el Snap Store real, cada uno de los 8 snaps del catálogo, verificando `status` antes/después de cada paso.
- Job nuevo en CI, `snap-functional-experimental`, **separado** de `docker-matrix` (no puede compartir su Dockerfile/mecanismo de ejecución: `docker-matrix` usa `docker run --rm <img> <cmd>` sin systemd) y marcado **`continue-on-error: true`** a propósito — un mecanismo nuevo y no oficialmente soportado no debe poder bloquear el resto de CI ni el merge de trabajo no relacionado con Snap mientras no demuestre estabilidad sostenida.

Este mecanismo **no reemplaza** la pauta de validación manual en Ubuntu 26.04 Desktop real (`docs/TEST_CASES.md`): la clasificación `no verificable automáticamente` de los 8 instaladores en `docs/UBUNTU_COMPATIBILITY.md` se mantiene sin cambios hasta que este job experimental corra de forma estable durante un período razonable — recién ahí correspondería reevaluar si sustituye o complementa esa pauta.

## Consecuencias

- Costo real de CI: cada corrida de este job instala 8 apps GUI reales (algunas pesadas, por ejemplo GIMP) contra la red real — más lento y con más consumo de ancho de banda/almacenamiento que el resto de la matriz.
- Riesgo de fragilidad: es un patrón no soportado oficialmente; puede romperse con cambios en la imagen base de Ubuntu, en `snapd`, o en el entorno de GitHub Actions, sin aviso previo — deuda de mantenimiento distinta a la del resto de la matriz (estable desde el Hito 10).
- `continue-on-error: true` significa que un fallo en este job se reporta pero no bloquea el merge — hay que seguir revisando su resultado manualmente en vez de asumir que "CI en verde" ya lo cubre.
- Relacionado: [ADR 0026](0026-adelantar-hito-10-ci-antes-que-hito-9.md) (gate de calidad de CI), Hito 9 (`docs/ROADMAP.md`, cierre administrativo con esta validación pendiente).
