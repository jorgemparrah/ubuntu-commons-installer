# 0003. La limpieza de NVM se hace por migración versionada, nunca por borrado directo

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El desinstalador actual de Node.js elimina `~/.nvm` recursivamente y edita `.bashrc`, `.zshrc` y `.profile` con `sed` buscando cualquier línea que contenga `nvm`, sin crear respaldo antes. Como la instalación objetivo reutiliza `/home`, esto puede destruir versiones de Node y paquetes globales instalados, además de borrar líneas de shell no relacionadas.

Fuente: ASSESSMENT.md, CR-02.

## Decisión

La limpieza de NVM nunca ocurre como efecto secundario de `uninstall`/`reinstall`. Se implementa como una migración versionada (ver [0006](0006-framework-de-migraciones-versionado.md)) que:

1. inventaría versiones de NVM y paquetes globales por versión;
2. copia los archivos de shell a un respaldo con timestamp (ver [0005](0005-gestor-de-backups-centralizado.md));
3. mueve `.nvm` a un respaldo en vez de borrarlo;
4. elimina solo bloques de inicialización de NVM reconocidos exactamente (ver [0007](0007-bloques-gestionados-en-archivos-de-shell.md));
5. verifica Mise y Node antes de marcar la migración como completa;
6. deja una vía de rollback.

## Consecuencias

- El `install_nodejs.sh` actual no debe invocarse con `uninstall`/`reinstall` en una máquina con estado NVM valioso hasta que exista esta migración.
- Relacionado: [0002](0002-mise-como-unico-gestor-runtime.md), [0005](0005-gestor-de-backups-centralizado.md), [0006](0006-framework-de-migraciones-versionado.md), [0007](0007-bloques-gestionados-en-archivos-de-shell.md).

## Apéndice — Rutas de `/home` que pueden ya existir al reutilizar el home

La instalación objetivo formatea la partición del sistema operativo pero retiene la partición home existente. Por lo tanto puede que ya existan:

```text
~/.nvm
~/.config/mise
~/.local/share/mise
~/.npm
~/.cache
~/.bashrc
~/.zshrc
~/.profile
~/.gitconfig
~/.ssh
~/.config/Code
~/.config/Cursor
~/.docker
```

**Nivel de riesgo actual:** Alto, principalmente porque las acciones legacy de `uninstall`/`reinstall` pueden eliminar o editar este estado retenido.

**Requisitos mínimos de seguridad antes de usar el instalador refactorizado sobre un `/home` retenido:**

- `doctor` debe ejecutarse sin modificar el sistema;
- `--dry-run` debe estar soportado por las migraciones;
- debe existir un gestor de backups (ver [0005](0005-gestor-de-backups-centralizado.md));
- la migración de NVM debe mover, no eliminar, `.nvm`;
- los cambios exactos de shell deben reportarse (ver [0007](0007-bloques-gestionados-en-archivos-de-shell.md));
- no debe ocurrir ningún reinstall automático (ver [0004](0004-idempotencia-instalado-igual-skip.md));
- las claves SSH y credenciales nunca deben modificarse;
- toda acción destructiva debe requerir confirmación explícita;
- debe generarse un reporte de recuperación.

Hasta que se cumplan estas condiciones, la acción actual `reinstall` de Node.js no debe usarse sobre un `/home` preservado.
