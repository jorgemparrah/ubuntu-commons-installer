# 0023. `UCI_HOME_DIR` como home lógico, simulable para pruebas

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

A partir de Doctor (Hito 4) y en los hitos que siguen (Backups, Migraciones), varias partes del proyecto necesitan leer o escribir bajo el home del usuario (`~/.nvm`, `~/.ssh`, `~/.bashrc`, `~/.local/state/ubuntu-workstation/`, etc.). El dueño del proyecto todavía no ha podido validar estos hitos en una máquina o VM separada, y pidió una forma de simular un home de prueba en su propia workstation sin arriesgar el `$HOME` real — en particular para los hitos que sí escriben en disco (a diferencia de Doctor, que es de solo lectura).

## Decisión

Se introduce `UCI_HOME_DIR`, una variable de entorno que `setup.sh` resuelve una sola vez al inicio:

```bash
UCI_HOME_DIR="${UCI_HOME_DIR:-${HOME}}"
```

Todo módulo que necesite razonar sobre "el home" (Doctor hoy; Backups, Migraciones y Runtime más adelante) recibe `UCI_HOME_DIR` como parámetro explícito en vez de leer `$HOME` directamente. Esto permite:

```bash
UCI_HOME_DIR="$(mktemp -d)" ./setup.sh doctor --verbose
```

para correr contra un home vacío/simulado, sin tocar el `$HOME` real de la máquina.

## Consecuencias

- Las funciones de `scripts/diagnostics/doctor.sh` (y las que se agreguen en `scripts/lib/backup.sh`, migraciones, etc.) reciben el home como parámetro (`home_dir`) en vez de usar `$HOME` implícitamente — más testeable y explícito, en línea con cómo `preflight_check_repo_files` ya recibe `repo_root`.
- Las pruebas (`tests/test_doctor.sh` y las que sigan) usan `UCI_HOME_DIR=<carpeta temporal>` en vez de sobreescribir la variable `HOME` real del proceso, evitando efectos secundarios más amplios.
- Esta variable no reemplaza `--dry-run` (que sigue siendo necesario para Migraciones, ver [ADR 0006](0006-framework-de-migraciones-versionado.md)): `UCI_HOME_DIR` simula *dónde* se opera, `--dry-run` simula *si* se opera de verdad. Ambos mecanismos son complementarios.
- Relacionado: [ADR 0003](0003-migracion-nvm-sin-borrado-directo.md) (apéndice de rutas de home retenido), [ADR 0005](0005-gestor-de-backups-centralizado.md).
