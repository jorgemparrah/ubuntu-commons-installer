# Architecture Decision Records (ADR)

Esta carpeta contiene decisiones de arquitectura pequeñas y de un solo tema, en vez de un único archivo `DECISIONS.md` gigante.

## Convención

- Una decisión por archivo: `NNNN-slug-corto.md`, numeradas secuencialmente, nunca se reutiliza un número.
- El estado es uno de: `Propuesta`, `Aceptada`, `Reemplazada por NNNN`, `Obsoleta`.
- Cada ADR debe ser breve. Si una decisión crece hasta cubrir varios temas no relacionados, se separa en nuevas ADRs en vez de expandir una sola.
- Reemplazar una decisión significa agregar una ADR nueva y marcar el estado de la anterior como `Reemplazada por NNNN` — nunca se edita la historia para borrarla.

## Plantilla

```markdown
# NNNN. Título

Fecha: AAAA-MM-DD
Estado: Propuesta | Aceptada | Reemplazada por NNNN | Obsoleta

## Contexto

Qué fuerzas/restricciones llevaron a esta decisión.

## Decisión

Qué se decidió.

## Consecuencias

Qué se vuelve más fácil o más difícil como resultado. Trabajo futuro que esto genera.
```

## Índice

Las ADR 0001–0014 se derivaron de los hallazgos de la evaluación inicial del repositorio (2026-07-13; el informe original ya no se mantiene como archivo aparte, ver `AGENT.md` sección 5). La ADR 0015 documenta una decisión posterior sobre el idioma de la documentación. Las ADR 0016–0021 documentan decisiones tomadas al revisar el inventario de herramientas con el dueño del proyecto (2026-07-15, ver `docs/TOOLS.md`). La ADR 0022 surgió al implementar el Hito 2 (Bootstrap).

| ID | Título | Estado |
|---|---|---|
| [0001](0001-bootstrap-bash-sin-node.md) | `setup.sh` como router de comandos Bash, independiente de Node | Aceptada |
| [0002](0002-mise-como-unico-gestor-runtime.md) | Mise como único gestor de runtimes | Aceptada |
| [0003](0003-migracion-nvm-sin-borrado-directo.md) | La limpieza de NVM se hace por migración versionada, nunca por borrado directo | Aceptada |
| [0004](0004-idempotencia-instalado-igual-skip.md) | Una herramienta instalada se omite por defecto, no se reinstala | Aceptada |
| [0005](0005-gestor-de-backups-centralizado.md) | Gestor de backups centralizado antes de implementar migraciones | Aceptada |
| [0006](0006-framework-de-migraciones-versionado.md) | Framework de migraciones versionado | Aceptada |
| [0007](0007-bloques-gestionados-en-archivos-de-shell.md) | Los archivos de shell solo se editan mediante bloques marcados | Aceptada |
| [0008](0008-bash-estricto-en-scripts-nuevos.md) | Modo estricto de Bash en scripts nuevos y migrados | Aceptada |
| [0009](0009-postergar-arquitectura-de-plugins.md) | Postergar una arquitectura de plugins/metadata declarativa | Aceptada |
| [0010](0010-orden-de-fuentes-de-paquetes.md) | Orden de prioridad de fuentes de paquetes | Reemplazada por 0027 |
| [0011](0011-alcance-diferido-para-el-primer-hito.md) | Alcance explícitamente diferido para los primeros hitos | Aceptada |
| [0012](0012-modelo-de-estado-enriquecido.md) | Modelo de estado enriquecido para `status` | Aceptada |
| [0013](0013-separar-mantenimiento-de-instaladores.md) | Separar acciones de mantenimiento de sistema de los instaladores de aplicaciones | Aceptada |
| [0014](0014-gate-de-calidad-ci.md) | Agregar un gate de calidad automatizado (CI) no destructivo | Aceptada |
| [0015](0015-idioma-de-la-documentacion.md) | La documentación del proyecto se escribe en español | Aceptada |
| [0016](0016-politica-de-versiones-node-mise.md) | Política de versiones de Node instaladas por Mise | Aceptada |
| [0017](0017-mise-instala-yarn-pnpm-directo.md) | Mise instala Yarn y pnpm directamente, sin Corepack | Aceptada |
| [0018](0018-kubectl-via-mise.md) | kubectl se gestiona vía Mise, no vía Snap | Aceptada |
| [0019](0019-flameshot-atajo-printscreen.md) | Flameshot se confirma como herramienta de captura, con atajo en PrintScreen | Aceptada |
| [0020](0020-alcance-fuera-nvidia-dotfiles-agentes.md) | NVIDIA/CUDA y los dotfiles de agentes de IA quedan fuera de alcance | Aceptada |
| [0021](0021-reutilizar-personalizacion-shell-en-home.md) | Reutilizar/respaldar la personalización de Oh My Zsh y Powerlevel10k al reutilizar `/home` | Aceptada |
| [0022](0022-modo-estricto-en-bibliotecas-sourceadas.md) | Las bibliotecas pensadas para `source` no declaran su propio modo estricto | Aceptada |
| [0023](0023-variable-uci-home-dir-para-pruebas.md) | `UCI_HOME_DIR` como home lógico, simulable para pruebas | Aceptada |
| [0024](0024-alcance-migracion-nvm-a-mise.md) | La migración NVM→Mise preserva lo detectado, no aplica la política de versiones por defecto | Aceptada |
| [0025](0025-metodo-instalacion-oficial-de-mise.md) | Mise se instala con su script oficial (`https://mise.run`), verificando después | Aceptada |
| [0026](0026-adelantar-hito-10-ci-antes-que-hito-9.md) | Adelantar el Hito 10 (CI) antes que el Hito 9, y su alcance real | Aceptada |
| [0027](0027-orden-de-fuentes-por-categoria.md) | Orden de fuentes de paquetes por categoría de herramienta (reemplaza 0010) | Aceptada |
| [0028](0028-arquitectura-soportada-amd64.md) | Arquitectura oficialmente soportada: amd64 | Aceptada |
| [0029](0029-contrato-completo-de-instalador-referencia.md) | `install_vim.sh` es el contrato de referencia; el Hito 11 migra el resto hacia él | Aceptada |
| [0030](0030-registro-central-de-metadata-de-instaladores.md) | Registro central de metadata de instaladores (catálogo Bash, sin YAML/JSON) | Aceptada |
| [0031](0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md) | Separar los instaladores multi-paquete en instaladores individuales, con un agrupador delgado | Aceptada |
| [0032](0032-mecanismo-condicional-por-version-de-ubuntu.md) | Mecanismo de instalación condicional por versión de Ubuntu (Ghostty) | Aceptada |
