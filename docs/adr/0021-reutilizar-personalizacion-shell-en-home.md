# 0021. Reutilizar/respaldar la personalización existente de Oh My Zsh y Powerlevel10k al reutilizar `/home`

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Se confirmó mantener tanto Oh My Zsh como Powerlevel10k. Como el proyecto debe soportar la reutilización de un `/home` existente (ver [ADR 0003](0003-migracion-nvm-sin-borrado-directo.md) para el caso de NVM), `install_oh_my_zsh.sh` e `install_powerlevel10k.sh` no deben sobrescribir sin más la personalización ya existente del usuario (temas, plugins, configuración de `.zshrc`/`.p10k.zsh`) cuando ya hay una instalación previa en el home retenido.

## Decisión

Al detectar una instalación previa de Oh My Zsh o Powerlevel10k en un `/home` reutilizado, el instalador debe:

1. detectar la personalización existente (plugins activos, tema, `.p10k.zsh`, cambios locales en `.zshrc` fuera de los bloques gestionados del proyecto — ver [ADR 0007](0007-bloques-gestionados-en-archivos-de-shell.md));
2. respaldarla antes de cualquier cambio (ver [ADR 0005](0005-gestor-de-backups-centralizado.md));
3. ofrecer reutilizarla en vez de reinstalar desde cero.

No se reinstala Oh My Zsh/Powerlevel10k "desde cero" por defecto cuando ya existe una instalación válida, siguiendo el mismo principio de idempotencia de [ADR 0004](0004-idempotencia-instalado-igual-skip.md).

## Consecuencias

- `install_oh_my_zsh.sh` e `install_powerlevel10k.sh` necesitan lógica de detección de estado previo, no solo de instalación.
- Esto es un caso concreto adicional de la estrategia general de reutilización de `/home` (ver ARCHITECTURE.md, sección 19).
