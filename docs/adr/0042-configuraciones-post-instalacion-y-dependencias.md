# 0042. Configuraciones post-instalación y dependencias entre instaladores

Fecha: 2026-07-21
Estado: Aceptada

## Contexto

Al revisar la deuda pendiente de Flameshot (el atajo de teclado `PrintScreen` nunca se configuró, solo se instaló el paquete, ver [ADR 0019](0019-flameshot-atajo-printscreen.md)) y el caso de Powerlevel10k (que asume Oh My Zsh ya instalado, sin que nada lo verifique), el dueño del proyecto pidió establecer el flujo general, no solo resolver el caso puntual de Flameshot:

1. **Configuraciones post-instalación.** El contrato actual de 6 verbos ([ADR 0029](0029-contrato-completo-de-instalador-referencia.md)) no tiene un lugar para pasos que solo tienen sentido si la herramienta ya está instalada, y que deberían poder revisarse/re-ejecutarse en cualquier momento después de la instalación (no solo una vez, durante `install`).
2. **Dependencias entre instaladores.** Algunas herramientas necesitan que otra ya esté instalada — Powerlevel10k necesita Oh My Zsh — sin que el catálogo lo declare ni ningún instalador lo verifique hoy.

## Decisión

### Verbo nuevo: `configure`

Se agrega `configure` como 7° verbo opcional del contrato (`scripts/lib/installer_cli.sh`), con el mismo patrón que `update`/`repair`: si el instalador no define `configure_tool`, el dispatcher lo rechaza explícitamente con código 3 ("no soportado"), nunca falla con "command not found". El dispatcher **no** fuerza centralmente que la herramienta esté `INSTALLED` antes de correr `configure_tool` — cada instalador que lo implemente es responsable de rechazar explícitamente si su propio `check_status` no reporta `INSTALLED`, mismo criterio que ya usan varios `repair_tool` para rechazar sobre `NOT_INSTALLED` (el dispatcher no asume cómo cada instalador define "instalado").

Primer caso real: `install_flameshot.sh` implementa `configure_tool` para el atajo `PrintScreen` (gsettings, entorno GNOME).

### Dependencias entre instaladores: campo `depends_on`

Campo nuevo, no-esquemático (mismo mecanismo sin esquema forzado de [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md)), `depends_on=<id>` en `tools_catalog.sh`. Primer caso real: `powerlevel10k` → `depends_on=oh_my_zsh`.

**Política explícita** (confirmada con el dueño del proyecto): si falta la dependencia, el instalador **rechaza con un mensaje claro** — nunca instala la dependencia por su cuenta sin que se le haya pedido explícitamente (principio de "explícito antes que implícito", `AGENT.md` sección 2). Se agrega `scripts/lib/dependencies.sh` (`dependency_require_installed <script_path> <etiqueta>`) para esto; `install_powerlevel10k.sh` lo usa al principio de `install_tool()`.

**Excepción, también confirmada explícitamente:** cuando la dependencia y la dependiente se piden instalar **juntas** en un mismo movimiento (por ejemplo, ambas en el mismo perfil de `setup.sh install --profile <nombre>`, Hito 13), debe garantizarse que la dependencia se instale primero — no debería hacer falta correr el comando dos veces. Esto se resuelve confiando en el **orden de registro** en `tools_catalog.sh` (`oh_my_zsh` ya está registrado antes que `powerlevel10k`, y `profile_installer_run`/`catalog_list_run` recorren el catálogo en ese orden): es una simplificación deliberada mientras exista una sola relación de dependencia — si en el futuro aparecen dependencias más complejas (múltiples niveles, o un ciclo), correspondería una ADR nueva evaluando un ordenamiento topológico real en vez de esta convención de orden de registro.

## Consecuencias

- `docs/ROADMAP.md` (Hito 17) pasa de `Blocked` a `In Progress`/`Done` según el alcance real implementado.
- Instaladores existentes no cambian su comportamiento salvo los dos casos concretos (`install_flameshot.sh`, `install_powerlevel10k.sh`) — el resto del catálogo sigue con 6 verbos, sin `depends_on`.
- La convención de orden de registro para garantizar dependencias antes que dependientes es una limitación conocida y documentada, no un ordenamiento topológico general — ver el aviso arriba.
- Relacionado: [ADR 0029](0029-contrato-completo-de-instalador-referencia.md) (contrato de 6 verbos, que este ADR extiende a 7), [ADR 0019](0019-flameshot-atajo-printscreen.md) (deuda que originó este hito), [ADR 0030](0030-registro-central-de-metadata-de-instaladores.md).
