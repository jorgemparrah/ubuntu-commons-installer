# 0032. Mecanismo de instalación condicional por versión de Ubuntu (Ghostty)

Fecha: 2026-07-20
Estado: Aceptada

## Contexto

Al agregar Ghostty (terminal acelerada por GPU) al catálogo de herramientas, se encontró que su disponibilidad en los repositorios oficiales de Ubuntu depende de la versión: el paquete `ghostty` ya está en el repositorio oficial de Ubuntu 26.04 (`resolute`), pero **no** existe todavía en el de Ubuntu 24.04 (`noble`) — en 24.04 solo está disponible vía el PPA mantenido por el autor del empaquetado (`ppa:mkasberg/ghostty-ubuntu`).

Ningún instalador de este proyecto había necesitado antes decidir su mecanismo de instalación (apt oficial vs. repositorio de terceros) según la versión de Ubuntu en tiempo de ejecución — todos los mecanismos existentes (apt, apt-vendor-repo, snap, deb-direct, git-clone, mise) son fijos para una herramienta dada, independientes de la versión.

## Decisión

`scripts/system/install_ghostty.sh` detecta la versión de Ubuntu con `lsb_release -rs` (versión numérica, nunca el codename — mismo criterio ya establecido en `scripts/system/install_kernel.sh` tras su corrección del Hito 9) y elige el mecanismo en `install_tool`/`uninstall_tool`:

- Ubuntu 24.04: agrega el PPA (`ppa:mkasberg/ghostty-ubuntu`, mismo patrón de PPA que `scripts/productivity/install_ulauncher.sh`) antes de instalar el paquete; lo quita al desinstalar.
- Cualquier otra versión (26.04 en adelante): instala el paquete directamente desde el repositorio oficial, sin tocar ningún PPA.

`status`/`update`/`repair` no distinguen el mecanismo: una vez instalado, el paquete `ghostty` se comporta igual sin importar de dónde vino — la rama condicional vive únicamente en `install_tool`/`uninstall_tool`.

No se introduce una biblioteca compartida nueva para esto: es un caso aislado (una sola herramienta), y generalizar prematuramente un helper de "instalación condicional por versión" sin un segundo caso real violaría el principio de evitar abstracciones especulativas.

## Consecuencias

- Si en el futuro otra herramienta necesita el mismo patrón (mecanismo distinto según versión de Ubuntu), corresponde revisar esta ADR y decidir si vale la pena extraer un helper compartido (por ejemplo en `scripts/lib/apt.sh` o una biblioteca nueva) recién en ese momento, con al menos dos casos reales para guiar el diseño.
- `install_ghostty.sh` queda registrado en `tools_catalog.sh` con `manager=apt` (el mecanismo de fondo, en ambas ramas, sigue siendo APT); el detalle de PPA condicional no se modela como un campo separado del catálogo por ahora.
- Relacionado: [ADR 0027](0027-orden-de-fuentes-por-categoria.md) (orden de fuentes por categoría), [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato de 6 verbos).
