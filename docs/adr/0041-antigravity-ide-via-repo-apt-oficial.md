# 0041. Antigravity IDE se instala vía su repositorio APT oficial (corrige el diferimiento de ADR 0037)

Fecha: 2026-07-21
Estado: Aceptada

## Contexto

[ADR 0037](0037-mecanismo-curl-script-para-clis-de-ia.md) implementó solo el CLI de Antigravity (`agy`, vía `curl-script`) y difirió explícitamente su IDE/Desktop: la investigación original solo había encontrado un tarball manual sin checksum ni firma, lo que no cumplía el estándar de seguridad del proyecto (`AGENT.md` §16).

Al retomar este punto pendiente (Hito 16), una investigación nueva confirma que Google **sí publica un repositorio APT oficial verificable** para Antigravity IDE, con el mismo mecanismo moderno de clave GPG que ya usa el resto del catálogo (`signed-by` + keyring, nunca `apt-key`):

- Repositorio: `https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/` (`antigravity-debian main`).
- Clave: `https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg` (armored, requiere `gpg --dearmor`).
- Paquete: `antigravity`.
- También existe un repositorio RPM equivalente (`us-central1-yum.pkg.dev`), fuera de alcance de este proyecto (Ubuntu/APT únicamente).

El tarball manual sigue existiendo como alternativa en la página oficial, pero ya no es necesario: el repositorio APT es la fuente preferida según la jerarquía de `AGENT.md` §15 (repositorio oficial de proveedor, por encima de instalador/tarball manual).

## Decisión

Se implementa `scripts/editors/install_antigravity_ide.sh`, `manager=apt-vendor-repo` (reutiliza `scripts/lib/apt_vendor_repo.sh` sin cambios, mismo patrón que Docker/VS Code/Cursor/Claude Desktop), `category=editors` — es un editor de código, no una CLI de desarrollo ni un agente de propósito general (ver [ADR 0036](0036-candidatas-de-ia-en-categorias-existentes.md)).

Queda separado de `scripts/development/install_antigravity.sh` (el CLI `agy`, `category=development`/`subcategory=ai-cli`, sin cambios): son dos productos con mecanismos de instalación distintos, aunque coexistan en la misma app de escritorio para quien la usa.

Clasificación `optional` (confirmada en el Hito 16 original para "Antigravity" en general, ver `docs/ROADMAP.md`).

## Consecuencias

- `docs/adr/0037-mecanismo-curl-script-para-clis-de-ia.md` no se reescribe (su decisión de diferir el IDE fue correcta con la información disponible en ese momento); esta ADR documenta que el motivo del diferimiento (falta de mecanismo verificable) dejó de aplicar.
- `docs/ROADMAP.md` (Hito 16) se actualiza: el pendiente de "IDE de Antigravity sin mecanismo verificable" queda resuelto.
- No hay prueba automatizada dedicada para este instalador en esta ronda (`requires_manual_validation=yes`, mismo criterio que `install_claude_desktop.sh`: dominio externo nuevo para este proyecto, sin historial de estabilidad verificado en CI).
- Relacionado: [ADR 0027](0027-orden-de-fuentes-por-categoria.md) (jerarquía de fuentes), [ADR 0036](0036-candidatas-de-ia-en-categorias-existentes.md), [ADR 0037](0037-mecanismo-curl-script-para-clis-de-ia.md).
