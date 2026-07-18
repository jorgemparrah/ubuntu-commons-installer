# 0028. Arquitectura oficialmente soportada: amd64

Fecha: 2026-07-18
Estado: Aceptada

## Contexto

Al auditar compatibilidad con Ubuntu 24.04/26.04 (Hito 9, ver `docs/UBUNTU_COMPATIBILITY.md`) se encontraron varios instaladores con arquitectura hardcodeada a `amd64`/`x86_64` sin ninguna verificación previa (`install_chrome.sh`, y hasta su corrección, `install_cursor.sh`): en una máquina `arm64` instalarían en silencio un binario incompatible, o simplemente fallarían con un error de `dpkg` confuso ("wrong architecture"), sin ningún mensaje claro sobre la causa real. Ninguna ADR anterior había registrado explícitamente qué arquitectura soporta el proyecto.

## Decisión

- **Arquitectura oficialmente soportada inicialmente: `amd64`.** Todos los instaladores existentes asumen esto implícitamente; esta ADR lo hace explícito.
- **`arm64` queda como alcance futuro**, no soportado todavía. Cuando se decida soportarlo, corresponde una ADR nueva que reemplace o extienda esta, junto con el trabajo real de habilitarlo instalador por instalador (no se activa "de a poco" sin decisión explícita).
- **Comportamiento esperado ante una arquitectura no soportada**: un instalador que dependa de un binario/paquete específico de arquitectura debe **detectar la arquitectura real de la máquina y rechazar la instalación con un mensaje de error claro** (o, si el instalador ya sigue el contrato de estado enriquecido, un estado `UNSUPPORTED` — ver [ADR 0012](0012-modelo-de-estado-enriquecido.md)) en vez de continuar en silencio.
- **Prohibido**: continuar silenciosamente descargando/instalando un paquete `amd64` en una máquina `arm64` (o viceversa). Instalar el binario equivocado sin avisar es peor que fallar con un mensaje claro.
- Los instaladores que ya dependen de repositorios APT con múltiples arquitecturas declaradas (Docker, VS Code, Cursor: `arch=amd64,arm64,...`) no necesitan este chequeo explícito — apt ya resuelve la arquitectura correcta o falla de forma clara por sí mismo. Este chequeo aplica a instaladores de **descarga directa** de un binario/`.deb` fijado a una arquitectura (Chrome, y antes de su corrección, Cursor).

## Consecuencias

- `install_chrome.sh` se corrige para detectar la arquitectura antes de descargar el `.deb` de `amd64`, y rechazar con un mensaje claro en cualquier otra arquitectura (ver `docs/UBUNTU_COMPATIBILITY.md`).
- Cualquier instalador nuevo de descarga directa debe incluir este mismo chequeo desde el principio.
- Relacionado: [ADR 0012](0012-modelo-de-estado-enriquecido.md) (modelo de estado enriquecido, incluye `UNSUPPORTED`), [ADR 0027](0027-orden-de-fuentes-por-categoria.md) (orden de fuentes por categoría).
