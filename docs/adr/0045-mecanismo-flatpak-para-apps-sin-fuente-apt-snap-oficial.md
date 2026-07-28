# 0045. Mecanismo `flatpak` para aplicaciones sin fuente APT/Snap oficial

Fecha: 2026-07-27
Estado: Aceptada

## Contexto

El Hito 50 (ver `docs/ROADMAP.md`) incorpora dos aplicaciones cuyo único método de instalación oficial en Ubuntu 24.04 es Flatpak vía Flathub:

- **Kooha** (grabador de pantalla para GNOME/Wayland): su repositorio oficial (`SeaDve/Kooha`) publica el badge de Flathub como método primario y advierte explícitamente que los paquetes que no son Flatpak "no están soportados por el desarrollador". Existe un snap publicado por la misma cuenta del autor (`seadve`), pero al no estar declarado como soportado por el proyecto, usarlo contradiría el criterio de priorizar fuentes oficiales sin ambigüedad de mantenimiento (mismo razonamiento aplicado a Helix en el Hito 49, pero con la conclusión inversa: allí la doc oficial SÍ listaba el snap).
- **Papers** (visor de documentos de GNOME, sucesor de Evince): **no está en los repositorios de Ubuntu 24.04** — recién se incorpora como app core de GNOME a partir de versiones posteriores. En 24.04, Flathub es la única fuente disponible.

Ninguno de los mecanismos ya existentes del catálogo (`apt`, `apt-vendor-repo`, `snap`, `mise`, `deb-direct`, `curl-script`, `git-clone`, `archive-direct`, `izpack-installer`, `aws-cli-installer`) modela Flatpak.

[ADR 0027](0027-orden-de-fuentes-por-categoria.md) ubica Flatpak como última opción en la jerarquía de fuentes — eso sigue vigente: Flatpak **no** desplaza a APT/Snap cuando existe una alternativa oficial. Esta ADR no cambia esa prioridad; agrega el mecanismo para el caso en que las opciones anteriores simplemente no existen.

Se consideraron dos alternativas antes de decidir:

1. **Evitar Flatpak**: instalar Kooha vía su snap no declarado como soportado, y Papers solo en 26.04 (`supported_os=26.04`, no disponible en 24.04). Descartada por el dueño del proyecto: se aparta de las fuentes oficiales y deja una herramienta sin cobertura en una de las dos versiones soportadas.
2. **Diferir ambas** a un hito posterior. Descartada: la decisión de fondo (¿el proyecto soporta Flatpak?) no se simplifica por postergarla.

## Decisión

Se agrega un mecanismo nuevo, `manager=flatpak`, con una biblioteca compartida `scripts/lib/flatpak.sh` (hermana de `apt.sh`/`snap.sh`/`apt_vendor_repo.sh`/`deb_direct.sh`/`git_clone.sh`/`curl_script.sh`).

Dos casos reales concretos (Kooha y Papers) justifican extraer la biblioteca compartida desde el inicio, en vez de resolverlo dentro de un único instalador y esperar un segundo caso — el criterio de [ADR 0032](0032-mecanismo-condicional-por-version-de-ubuntu.md) ("esperar un segundo caso real antes de abstraer") ya se cumple en este mismo hito.

API de la biblioteca, deliberadamente paralela a `scripts/lib/snap.sh` (mismo rol para un mecanismo distinto):

- `flatpak_available`: 0 si el binario `flatpak` existe **y** responde (`flatpak --version`). No distingue *por qué* no responde — a quien llama solo le importa que `status` no puede confiar en la respuesta.
- `flatpak_app_installed <app_id>`: 0 si el app ID aparece en `flatpak list --app --columns=application` (match exacto de línea, no substring).
- `flatpak_ensure_flathub`: instala el paquete `flatpak` vía APT si falta y registra el remote de Flathub con `--if-not-exists` (idempotente). **Se registra a nivel de sistema (`--system`, el default), no `--user`**: consistente con el resto del catálogo, que instala software para la máquina, no para un usuario puntual.
- `flatpak_install_app <app_id>` / `flatpak_remove_app <app_id>` / `flatpak_update_app <app_id>`: operaciones con `-y --noninteractive` para no colgar un instalador desatendido.

Semántica de los verbos para este mecanismo:

- `status` devuelve `UNKNOWN` si Flatpak no está disponible (mismo criterio que Snap: distinguir "no puedo saberlo" de "no está instalado", hallazgo original de `docs/UBUNTU_COMPATIBILITY.md`), `INSTALLED` / `NOT_INSTALLED` en el resto de los casos.
- `status` **no** distingue `OUTDATED`: requeriría consultar Flathub por red, violando que `status` sea liviano y local (mismo criterio ya aplicado a Snap, ver `scripts/lib/snap.sh`). `update` existe igual como verbo explícito.
- `repair` no se implementa: el dispatcher lo rechaza con código 3, mismo criterio que Snap/Mise.
- `reinstall` usa el fallback mecánico del dispatcher (`uninstall` + `install`).

## Consecuencias

- **Dependencia de sistema nueva**: `flatpak` no viene instalado por defecto en Ubuntu (a diferencia de `snapd`). `flatpak_ensure_flathub` lo instala vía APT como parte de `install`, igual que `apt_vendor_repo_ensure_gnupg` instala `gnupg` cuando falta. El usuario no necesita prepararlo a mano.
- **`requires_manual_validation=yes`** para ambas herramientas: igual que el grupo Snap, Flatpak no se puede validar funcionalmente en los contenedores Docker de CI (requiere `flatpak` real y acceso a Flathub por red). La cobertura automatizada es un contrato mockeado; la validación real queda para `tests/manual/` (Hito 19).
- **No cambia la jerarquía de fuentes**: Flatpak sigue siendo la última opción de [ADR 0027](0027-orden-de-fuentes-por-categoria.md). Este mecanismo se usa solo cuando no existe fuente APT/repo-de-proveedor/Snap oficial — no como alternativa preferida. Kooha y Papers califican; una herramienta que sí esté en `universe` no debe migrarse a Flatpak por este ADR.
- **Papers y el solapamiento con Evince**: Papers es el sucesor de Evince (ya presente en Ubuntu por defecto) y de Okular (ya en el catálogo). Se agrega como opción adicional, no como reemplazo de ninguno — mismo criterio que Neovim frente a Vim (Hito 34) y Bruno frente a Postman/Insomnia (Hito 31).
- Relacionado: [ADR 0027](0027-orden-de-fuentes-por-categoria.md) (jerarquía de fuentes, sin cambios), [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato de verbos), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md) (registro sin esquema forzado), [ADR 0037](0037-mecanismo-curl-script-para-clis-de-ia.md) (precedente de "agregar un mecanismo nuevo con su biblioteca compartida").
