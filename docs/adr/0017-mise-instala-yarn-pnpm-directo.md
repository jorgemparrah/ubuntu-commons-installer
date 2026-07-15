# 0017. Mise instala Yarn y pnpm directamente, sin Corepack

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

`install_yarn.sh` instala Yarn de forma independiente. Con Mise como único gestor de runtimes ([ADR 0002](0002-mise-como-unico-gestor-runtime.md)), había que decidir si Yarn y pnpm se gestionan vía Corepack (que viene con Node) o directamente como plugins/runtimes de Mise.

## Decisión

Mise instala y gestiona Yarn y pnpm directamente, no a través de Corepack.

## Consecuencias

- `install_yarn.sh` se reemplaza por configuración/instalación vía Mise en vez de un script de instalación independiente.
- No se depende del campo `packageManager` de `package.json` ni de habilitar Corepack como paso previo.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md), [ADR 0016](0016-politica-de-versiones-node-mise.md).
