# CONTRIBUTING.md

## Guía para contribuir a Ubuntu Workstation

Este documento resume el flujo práctico para contribuir. Las reglas de fondo (filosofía, estándares de código, qué documentar y cuándo) viven en `AGENT.md` — léelo primero; esta guía no lo repite, lo aterriza en pasos concretos.

## Antes de empezar

1. Lee `AGENT.md` completo (visión, filosofía, estructura del repo).
2. Si vas a tocar un instalador o una decisión de arquitectura, revisa `docs/ROADMAP.md` (qué hito cubre esto, si depende de otro) y `docs/adr/README.md` (si ya existe una decisión aceptada sobre el tema).
3. Si tu cambio es sobre compatibilidad con Ubuntu 24.04/26.04, revisa `docs/UBUNTU_COMPATIBILITY.md` antes de asumir que algo funciona o no.

## Cómo probar un cambio

**Nunca ejecutes instaladores reales ni migraciones contra tu `$HOME` de desarrollo.** Ver `docs/TESTING.md` para el detalle completo; en resumen:

- Cambios en `scripts/lib/`, tests de contrato/simulados (`tests/*.sh`, `tests/*.js`): se pueden correr en cualquier máquina, no tocan `$HOME` real (usan `UCI_HOME_DIR`, ver [ADR 0023](adr/0023-variable-uci-home-dir-para-pruebas.md)).
- Cualquier cosa que instale software real o modifique archivos de shell de verdad: **solo dentro de un contenedor Docker desechable** (`tests/docker/build-and-test-all.sh`, o el flujo manual documentado en `docs/TESTING.md`).
- Antes de dar por terminada una tarea: `bash -n` sobre los scripts tocados, y ShellCheck si está disponible (ver `AGENT.md` §18). Si no puedes probar algo (por ejemplo `install_kernel.sh`, que nunca se instala de verdad ni en CI), dilo explícitamente en vez de asumir que funciona.

## Estándares de código

Ver `AGENT.md` §12-§18 para el detalle completo (modo estricto de Bash, logging, manejo de errores). Puntos que se olvidan seguido:

- Todo script nuevo o modificado usa `#!/usr/bin/env bash` + `set -Eeuo pipefail` ([ADR 0008](adr/0008-bash-estricto-en-scripts-nuevos.md)) — **si tocas un script legacy que todavía no lo tiene, súbelo al estándar como parte del mismo cambio**, no lo dejes para después.
- Las bibliotecas pensadas para `source` (`scripts/lib/*.sh`) nunca declaran su propio modo estricto ([ADR 0022](adr/0022-modo-estricto-en-bibliotecas-sourceadas.md)) y usan una guarda de carga única (`if [[ "${UCI_X_SH_LOADED:-0}" == "1" ]]; then return 0; fi`).
- El contrato de un instalador de aplicación es `status|install|uninstall|reinstall|update|repair` ([ADR 0004](adr/0004-idempotencia-instalado-igual-skip.md), [0012](adr/0012-modelo-de-estado-enriquecido.md), [0029](adr/0029-contrato-completo-de-instalador-referencia.md)); `scripts/editors/install_vim.sh` es la referencia completa a copiar. Migrar los instaladores que todavía no lo implementan es el objetivo del Hito 11 — no se exige de golpe fuera de ese hito.
- `dpkg -s` y un `grep` sin anclar dan falso positivo para un paquete en estado "config-files" remanente tras `apt remove`. Usa siempre `dpkg -l "$paquete" | grep -q '^ii'` y `apt purge` (no `apt remove`) en `uninstall_tool()`.
- En el dispatcher `main()`, usa `case "${1:-}" in` (no `case "$1" in`) — bajo `set -u`, `$1` sin argumentos es una variable no definida, no una cadena vacía.

## Documentación

Ver `AGENT.md` §5 para qué archivo de `docs/` se actualiza y cuándo. El más fácil de olvidar: `docs/TEST_CASES.md` se actualiza **antes** de escribir el test que lo implementa, nunca después.

## Commits y Pull Requests

Ver `AGENT.md` §19-§20. En resumen: commits pequeños y enfocados, mensaje describiendo el "por qué"; un PR describe propósito, resumen, archivos modificados, impacto de migración y pruebas realizadas.

## Flujo de trabajo esperado de un agente de IA

Ver `AGENT.md` §21 y §23. Un agente de IA nunca avanza de fase sin aprobación explícita, nunca elimina funcionalidad en silencio, y siempre pregunta ante requisitos ambiguos — esto aplica igual si sos un colaborador humano usando un agente para asistirte.
