# 0016. Política de versiones de Node instaladas por Mise

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

[ADR 0002](0002-mise-como-unico-gestor-runtime.md) estableció que Mise es el único gestor de runtimes, pero no definía cuántas versiones de Node se instalan por defecto ni qué archivo de configuración de proyecto se respeta. Esto quedó como pregunta abierta en `docs/ROADMAP.md`.

## Decisión

- Se instalan por defecto: la **última versión estable de Node** + las **últimas 2 versiones LTS**. Si la última estable es a la vez LTS, el conjunto se reduce a esas 2 versiones (no se duplica).
- A nivel de proyecto, Mise respeta tanto su formato nativo (`mise.toml`) como los formatos legacy `.nvmrc` y `.node-version`, para no romper proyectos existentes que ya los usan.

## Consecuencias

- El instalador de runtime debe consultar `.nvmrc`/`.node-version`/`mise.toml` en ese orden de compatibilidad al resolver qué versión usar en un proyecto.
- La lista de versiones "por defecto" instaladas globalmente puede cambiar con cada nueva LTS de Node; esto no requiere una nueva ADR, es mantenimiento normal de configuración.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md).
