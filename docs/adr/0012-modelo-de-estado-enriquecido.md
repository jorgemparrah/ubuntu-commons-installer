# 0012. Modelo de estado enriquecido para `status`

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

La mayoría de los scripts reportan hoy solo `INSTALLED` / `NOT_INSTALLED`. Que un comando exista en `PATH` no significa que la instalación esté sana ni que provenga de la fuente esperada: Node puede venir de NVM, Mise, APT o Snap; Docker puede estar presente pero no corriendo; kubectl puede ser una versión inesperada; una AppImage puede no tener entrada de escritorio.

Fuente: ASSESSMENT.md, HI-01.

## Decisión

Se adopta un contrato de resultado más rico para `status`:

```
INSTALLED
NOT_INSTALLED
OUTDATED
BROKEN
UNSUPPORTED
UNKNOWN
```

Eventualmente legible por máquina, por ejemplo:

```json
{
  "state": "INSTALLED",
  "version": "1.2.3",
  "source": "apt",
  "path": "/usr/bin/example",
  "healthy": true
}
```

La salida legible para humanos se mantiene disponible en paralelo.

## Consecuencias

- Habilita que el modelo de idempotencia de [0004](0004-idempotencia-instalado-igual-skip.md) distinga instalado-sano de instalado-desactualizado/roto.
- Los instaladores existentes migran a este contrato de forma incremental, no todos a la vez.
