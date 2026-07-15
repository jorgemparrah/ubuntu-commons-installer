# 0005. Gestor de backups centralizado antes de implementar migraciones

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Cada instalador modifica archivos y directorios por su cuenta. No existe una API común de backup, convención de retención, manifiesto ni metadata de rollback. Sin esto, cualquier migración (por ejemplo NVM → Mise) es riesgosa sobre un `/home` reutilizado.

Fuente: ASSESSMENT.md, HI-02.

## Decisión

Se introduce una librería de backup compartida (`scripts/lib/backup.sh`) antes de implementar el framework de migraciones. Estructura de estado:

```
~/.local/state/ubuntu-workstation/
├── backups/
│   └── <timestamp>/
│       ├── manifest.tsv
│       └── home/
├── migrations/
└── logs/
```

Propiedades requeridas: con timestamp, nunca sobrescrito, origen y destino registrados en el manifiesto, permisos de archivo preservados, soporte de `--dry-run`, reutilizable por cualquier módulo.

## Consecuencias

- Ninguna migración ni acción destructiva puede ejecutarse sin una sesión de backup inicializada primero.
- Relacionado: [0003](0003-migracion-nvm-sin-borrado-directo.md), [0006](0006-framework-de-migraciones-versionado.md).
