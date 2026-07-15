# 0019. Flameshot se confirma como herramienta de captura, con atajo en PrintScreen

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

`install_flameshot.sh` ya instala Flameshot y toca configuración de atajos, pero no estaba confirmado si Flameshot seguía siendo la herramienta preferida ni qué ajustes de escritorio (en general) debía gestionar el proyecto. Se evaluaron alternativas (Ksnip, el capturador nativo de GNOME) y se confirmó Flameshot por sus anotaciones, blur y captura de zona.

## Decisión

Flameshot se mantiene como la única herramienta de captura de pantalla gestionada por el proyecto. El único ajuste de escritorio que el proyecto configura es: la tecla `PrintScreen` debe lanzar Flameshot en vez del capturador nativo de GNOME.

## Consecuencias

- `install_flameshot.sh` debe verificar/configurar el atajo de teclado `PrintScreen` (por ejemplo, vía `gsettings`/`dconf` en GNOME) apuntando a Flameshot, y desactivar o sobrescribir el atajo nativo de captura de GNOME si está activo.
- Ningún otro ajuste de escritorio o atajo de teclado se gestiona por el proyecto (ver [ADR 0020](0020-alcance-fuera-nvidia-dotfiles-agentes.md)).
- Cualquier configuración existente de atajos debe respaldarse antes de modificarse, siguiendo la política general de backups ([ADR 0005](0005-gestor-de-backups-centralizado.md)).
