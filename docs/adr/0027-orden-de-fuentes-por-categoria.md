# 0027. Orden de fuentes de paquetes por categoría de herramienta (reemplaza ADR 0010)

Fecha: 2026-07-17
Estado: Aceptada

## Contexto

[ADR 0010](0010-orden-de-fuentes-de-paquetes.md) definió un único orden de preferencia lineal (APT oficial → repo del proveedor → instalador oficial → Snap → Flatpak → comunidad) para todas las herramientas por igual. Al auditar compatibilidad con Ubuntu 24.04/26.04 en el Hito 9 (ver `docs/UBUNTU_COMPATIBILITY.md`) y corregir `install_kubectl.sh`/`install_yarn.sh` para usar Mise (ADR 0018, ADR 0017), quedó claro que un orden único no captura bien las diferencias reales entre tipos de herramienta: un runtime/CLI versionable (kubectl, Node, Yarn) se beneficia de un gestor de versiones como Mise de una forma en que un paquete base del sistema operativo (`curl`, `git`) no lo necesita en absoluto, y una aplicación de escritorio propietaria (Cursor, MongoDB Compass) casi nunca está disponible en Mise ni en los repos oficiales de Ubuntu.

El dueño del proyecto definió una política más granular, por categoría de herramienta, en vez de un único orden lineal.

## Decisión

El orden de preferencia de fuentes pasa a decidirse por **categoría de herramienta**, no con una sola lista lineal:

| Categoría | Orden de preferencia |
|---|---|
| CLI/runtime versionable (Node, Python, kubectl, Yarn, pnpm, etc.) | Mise |
| Paquete base del sistema operativo (`curl`, `git`, `build-essential`, utilidades de terminal) | APT (repositorio oficial de Ubuntu) |
| Servicio o software técnico con repositorio propio (Docker, VS Code) | APT oficial del fabricante (repo propio agregado con `signed-by`, nunca `apt-key`) |
| Aplicación gráfica de escritorio sin gestor de versiones propio | APT (Ubuntu) → Flatpak → Snap — revisar en cada caso cuál de las tres tiene la versión más actualizada/mantenida antes de decidir, no asumir un orden ciego |
| Aplicación propietaria sin repositorio APT propio | APT oficial del fabricante (si existe) → `.deb`/AppImage oficial descargado directamente |
| Herramienta solo disponible por fuente comunitaria (PPA no oficial, script de terceros) | Evaluar reputación y mantenimiento activo antes de aceptar; requiere justificación explícita en el instalador |

Esta tabla reemplaza por completo el orden lineal de [ADR 0010](0010-orden-de-fuentes-de-paquetes.md), que queda marcada como reemplazada.

**Alcance de aplicación (Hito 9, Fase B):** esta ADR se aplica de inmediato a los instaladores que el Hito 9 ya está corrigiendo (`install_kubectl.sh`, `install_yarn.sh` — ambos ya siguen esta política: CLI/runtime versionable → Mise) y sirve como criterio para evaluar cualquier otro instalador que se toque en esta fase. **No implica reescribir de inmediato los 30 instaladores existentes** — eso corresponde al Hito 11 (modernización de instaladores), que ya depende de este hito (ver `docs/ROADMAP.md`). Instaladores no tocados en el Hito 9 se re-evalúan contra esta tabla cuando les toque su turno.

## Consecuencias

- `docs/UBUNTU_COMPATIBILITY.md` y `docs/TOOLS.md` referencian esta ADR en vez de la 0010 al justificar la fuente de una herramienta.
- Instaladores de aplicaciones gráficas existentes (GIMP, OBS Studio, Spotify, Zoom, DBeaver, GitKraken, Insomnia, Postman) actualmente fijos a Snap sin comparar contra Flatpak/APT quedan como candidatos a revisión en el Hito 11, no en este hito.
- Instaladores de aplicaciones propietarias (Cursor, MongoDB Compass, Chrome) que ya descargan un `.deb`/AppImage oficial directamente ya cumplen esta política en cuanto a la *fuente*; los problemas de robustez detectados en la auditoría (arquitectura hardcodeada, ausencia de checksum, versión fija) son defectos independientes de esta ADR y se corrigen por su cuenta.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md), [ADR 0010](0010-orden-de-fuentes-de-paquetes.md) (reemplazada), [ADR 0017](0017-mise-instala-yarn-pnpm-directo.md), [ADR 0018](0018-kubectl-via-mise.md).
