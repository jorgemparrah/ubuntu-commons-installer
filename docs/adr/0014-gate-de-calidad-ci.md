# 0014. Agregar un gate de calidad automatizado (CI) no destructivo

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

No hay ningún workflow de CI a nivel de repositorio que valide `bash -n`, ShellCheck, linting de JavaScript, ejecución de tests, o la metadata de instaladores.

Fuente: ASSESSMENT.md, ME-06.

## Decisión

Después de los primeros cambios estructurales (bootstrap, doctor, backups), se agrega un workflow de CI no destructivo que valide todos los scripts de shell y el código fuente de Node.js. Esto debe ocurrir antes de una modernización amplia de instaladores (ver ROADMAP.md, Hito 11 "Modernización de instaladores").

## Consecuencias

- El CI no ejecuta instaladores reales contra un sistema (evita efectos secundarios); solo valida sintaxis y estilo.
- Se convierte en prerequisito informal antes de tocar múltiples instaladores a la vez.
