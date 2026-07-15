# 0006. Framework de migraciones versionado

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El proyecto tiene acciones de instalación/desinstalación pero ningún concepto de "actualizar" un estado de workstation histórico. Como `/home` puede reutilizarse desde una instalación anterior, migrar ese estado (por ejemplo NVM → Mise) es un requisito de primera clase, no un caso especial.

Fuente: ASSESSMENT.md, HI-03.

## Decisión

Se crean migraciones versionadas bajo `scripts/migrations/`, por ejemplo:

```
scripts/migrations/
├── 001_nvm_to_mise.sh
├── 002_shell_runtime_cleanup.sh
└── ...
```

Cada migración define: identificador, detección, prerequisitos, comportamiento en `--dry-run`, comportamiento al aplicar, validación, marca de finalización y notas de rollback. Las marcas de finalización se guardan en:

```
~/.local/state/ubuntu-workstation/migrations/
```

`./setup.sh migrate --list` / `--dry-run` / `migrate` son parte del router de comandos (ver [0001](0001-bootstrap-bash-sin-node.md)).

## Consecuencias

- Una migración completada no se reaplica.
- Una migración fallida no marca finalización.
- Relacionado: [0001](0001-bootstrap-bash-sin-node.md), [0003](0003-migracion-nvm-sin-borrado-directo.md), [0005](0005-gestor-de-backups-centralizado.md).
