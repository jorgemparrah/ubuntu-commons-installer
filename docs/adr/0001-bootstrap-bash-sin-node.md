# 0001. `setup.sh` como router de comandos Bash, independiente de Node

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Hoy `setup.sh` instala dependencias de Node y lanza `setup.js`, que es quien ofrece el menú interactivo. Ningún comando fundamental (`doctor`, `status`, `backup`, `migrate`) puede existir todavía sin Node, y el propio bootstrap de Node depende de NVM (ver [0002](0002-mise-como-unico-gestor-runtime.md)). Si la capa de JavaScript falla o no está instalada, no hay forma de diagnosticar la máquina.

Fuente: ASSESSMENT.md, CR-04 y CR-01 (sección "Current execution model").

## Decisión

`setup.sh` se convierte en un router de comandos que funciona en Bash puro para las operaciones fundamentales:

```
help
doctor
status
backup
migrate
validate
```

Solo el selector interactivo (checkboxes, multi-selección) requiere Node y puede seguir viviendo en `setup.js`.

## Consecuencias

- Se necesita infraestructura compartida en Bash (`scripts/lib/logging.sh`, `scripts/bootstrap/preflight.sh`).
- `doctor` y `status` deben poder ejecutarse apenas se clona el repositorio, antes de instalar cualquier runtime.
- Relacionado: [0002](0002-mise-como-unico-gestor-runtime.md).
