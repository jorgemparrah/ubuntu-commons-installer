# 0026. Adelantar el Hito 10 (CI) antes que el Hito 9 (Ubuntu 26), y su alcance real

Fecha: 2026-07-17
Estado: Aceptada

## Contexto

El roadmap original declaraba el Hito 10 (Gate de calidad automatizado / CI) dependiente del Hito 9 (Compatibilidad con Ubuntu 26): la idea era revisar primero cada instalador para Ubuntu 26 y solo después automatizar la validación. Durante el cierre de las brechas del Hito 7 (M06, M07, ruta legada de `install_nodejs.sh`), la batería completa de `tests/docker/build-and-test-all.sh` (8 combinaciones de imagen × Ubuntu 24.04/26.04, instalando NVM/Node/Mise reales) resultó demasiado lenta y costosa para seguir corriéndose en la máquina de desarrollo local en cada iteración. Se decidió moverla a GitHub Actions.

Esto adelanta de hecho el entregable central del Hito 10 (un workflow de CI) sin haber completado el Hito 9. Además, el criterio de aceptación original del Hito 10 ("El CI no ejecuta instaladores reales contra un sistema; solo valida sintaxis y estilo") ya no describe lo que este CI hace: el job `docker-matrix` sí instala NVM/Mise/Node reales, igual que `build-and-test-all.sh` en local.

## Decisión

1. **Reordenar el roadmap:** el Hito 10 deja de depender del Hito 9. Su nueva dependencia es la Migración NVM (Hito 7), porque lo que este CI valida en profundidad es esa migración. El Hito 9 (revisión de cada instalador para Ubuntu 26) sigue siendo un trabajo pendiente y legítimo, pero es ortogonal a tener infraestructura de CI — de hecho, la matriz de este CI ya cubre Ubuntu 24.04 y 26.04 por igual, lo que le da al futuro Hito 9 un lugar natural donde correr sus propias verificaciones.
2. **Redefinir el alcance real del Hito 10:** el CI tiene dos niveles, igual que `docs/TESTING.md`:
   - `lint`: sintaxis y estilo (`bash -n`, ShellCheck, `node --check`) — corre directo en el runner de GitHub Actions, sin Docker, porque el runner ya es una VM desechable.
   - `docker-matrix`: la batería completa de Nivel 2 (instala software real), corriendo dentro de contenedores Docker desechables **dentro del runner desechable** — nunca contra un sistema persistente. Es "no destructivo" en el mismo sentido que ya lo es `build-and-test-all.sh`: nada de lo que instala sobrevive a la ejecución.
3. La matriz de `docker-matrix` (`.github/workflows/ci.yml`) refleja exactamente `docs/TEST_CASES.md`: 4 variantes de imagen × 2 versiones de Ubuntu = 8 jobs paralelos, más el job `lint`. `docs/TEST_CASES.md` sigue siendo la fuente de verdad; si se agrega un caso nuevo ahí, hay que agregar su entrada tanto en `tests/docker/build-and-test-all.sh` (para seguir pudiendo depurar en local) como en `.github/workflows/ci.yml`.

## Consecuencias

- El Hito 10 se marca `Done` en `docs/ROADMAP.md`, con este cambio de alcance documentado en su propia sección (ver "Redefinición de alcance" del Hito 10).
- El Hito 9 permanece `Blocked` (sin cambios en su propio contenido), solo cambia quién depende de quién.
- Cada job de la matriz construye su propia imagen base y variante desde cero (sin compartir cache de capas entre jobs) — simple y explícito, a costa de reconstruir la imagen base 4 veces por versión de Ubuntu. Si el tiempo total de CI se vuelve un problema, una futura ADR puede introducir un job previo que construya y publique las imágenes base (por ejemplo a GitHub Container Registry) para que los jobs de variante las reutilicen — no se implementa ahora para evitar una abstracción prematura.
- La duplicación de la matriz entre `docs/TEST_CASES.md`, `tests/docker/build-and-test-all.sh` y `.github/workflows/ci.yml` es una duplicación ya existente en el proyecto (los primeros dos ya se mantenían sincronizados a mano); se acepta el mismo costo de mantenimiento para el tercero.
