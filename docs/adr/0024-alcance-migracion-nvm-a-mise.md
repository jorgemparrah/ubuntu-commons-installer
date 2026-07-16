# 0024. La migración NVM→Mise preserva lo detectado, no aplica la política de versiones por defecto

Fecha: 2026-07-16
Estado: Aceptada

## Contexto

[ADR 0016](0016-politica-de-versiones-node-mise.md) define qué versiones de Node instala Mise **por defecto** cuando no hay estado previo (última estable + últimas 2 LTS). Al implementar la migración `scripts/migrations/001_nvm_to_mise.sh` (Hito 7) surgió la pregunta de si debía aplicar esa misma política al migrar, o preservar exactamente lo que la persona usuaria ya tenía instalado vía NVM.

También surgió qué hacer con los paquetes npm instalados globalmente bajo cada versión de NVM: reinstalarlos automáticamente es lo que la evaluación inicial del repositorio recomendaba evitar (ver ROADMAP.md, Etapa 5 histórica), porque puede traer paquetes obsoletos, conflictivos, o simplemente no deseados en el nuevo entorno.

## Decisión

- La migración **reinstala vía Mise exactamente las versiones de Node que detecta bajo `~/.nvm/versions/node/`**, no la política de ADR 0016. Esa política aplica al primer uso de Mise "en frío" (por ejemplo, el futuro Gestor de runtimes del Hito 8), no a una migración cuyo objetivo es preservar continuidad, no imponer un estándar nuevo.
- La versión global de Mise queda fijada según el alias `default` de NVM si resuelve a una versión detectada; si no, se usa la versión más alta detectada.
- Los paquetes npm instalados globalmente por versión **se inventarían** (se listan en el `dry-run`/log, para que la persona usuaria sepa qué tenía) **pero no se reinstalan automáticamente**. Reinstalarlos, si se desea, queda como paso manual posterior (`npm install -g <paquete>` bajo la versión ya migrada a Mise).

## Consecuencias

- Después de migrar, el conjunto de versiones de Node instaladas vía Mise puede no coincidir con lo que ADR 0016 recomendaría para una instalación nueva — eso es intencional, no un defecto.
- Ningún paquete global se pierde silenciosamente: sigue existiendo bajo el `.nvm` movido al backup, y su lista queda en el log de la migración.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md), [ADR 0003](0003-migracion-nvm-sin-borrado-directo.md), [ADR 0016](0016-politica-de-versiones-node-mise.md).
