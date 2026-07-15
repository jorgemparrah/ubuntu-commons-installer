# 0015. La documentación del proyecto se escribe en español

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El assessment inicial (LO-02) había recomendado mantener el código e identificadores técnicos en inglés y los mensajes de terminal en español o configurable, sin traducir contenido existente solo por consistencia cosmética. Sin embargo, el dueño del proyecto pidió explícitamente que toda la documentación (AGENT.md, docs/) se mantenga en español de aquí en adelante, incluyendo una traducción completa de lo ya escrito en inglés.

## Decisión

Esta ADR reemplaza el criterio de LO-02 en cuanto a la documentación: toda la documentación del proyecto (`AGENT.md`, `docs/*.md`, incluyendo ADRs futuras) se escribe en español. Los identificadores de código, nombres de scripts, nombres de variables y comandos permanecen en inglés cuando así lo exige la convención técnica (por ejemplo `set -euo pipefail`, nombres de funciones).

## Consecuencias

- Los documentos existentes (`AGENT.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/ASSESSMENT.md`, `docs/adr/*`) se tradujeron completamente al español el 2026-07-15.
- Cualquier documentación nueva se escribe directamente en español; no se traduce después.
- Los mensajes de terminal para el usuario final ya eran en español y no cambian.
