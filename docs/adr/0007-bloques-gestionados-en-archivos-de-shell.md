# 0007. Los archivos de shell solo se editan mediante bloques marcados y propios del proyecto

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Editar `.bashrc`/`.zshrc`/`.profile` con patrones amplios de `sed` (por ejemplo, "cualquier línea que contenga `nvm`") es frágil y puede borrar contenido del usuario que no tiene relación con el proyecto.

Fuente: ASSESSMENT.md, HI-04.

## Decisión

Cualquier configuración de shell que el proyecto necesite activar se escribe dentro de un bloque delimitado y con nombre propio:

```bash
# >>> ubuntu-workstation: mise >>>
eval "$(mise activate bash)"
# <<< ubuntu-workstation: mise <<<
```

Solo esos bloques exactos pueden agregarse, modificarse o eliminarse por el proyecto. Para la limpieza histórica de NVM, se detectan patrones conocidos del instalador de NVM y las líneas que no calcen exactamente se presentan al usuario para revisión manual, en vez de borrarlas automáticamente.

## Consecuencias

- Ninguna migración puede usar `sed`/`grep` de coincidencia amplia sobre archivos de configuración del usuario.
- Relacionado: [0003](0003-migracion-nvm-sin-borrado-directo.md).
