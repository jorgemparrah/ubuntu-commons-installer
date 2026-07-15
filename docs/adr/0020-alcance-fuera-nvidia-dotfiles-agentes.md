# 0020. NVIDIA/CUDA y los dotfiles de agentes de IA quedan fuera de alcance

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Dos preguntas abiertas de la evaluación inicial necesitaban resolución: si los drivers NVIDIA/CUDA debían automatizarse, y si los symlinks de `.agents`, `.claude` y `.cursor` debían gestionarse en este repositorio o en uno de dotfiles separado.

## Decisión

- **NVIDIA / CUDA**: no se gestionan como instalador de este repositorio. Quedan documentados como una fase manual separada (fuera del alcance de `setup.sh`), dado el alto riesgo y la variabilidad según hardware.
- **Symlinks de `.agents`, `.claude`, `.cursor`**: no se gestionan por este repositorio por ahora. No se descarta retomarlo más adelante en un repositorio de dotfiles separado, pero no es parte del alcance actual.

## Consecuencias

- Ningún instalador ni migración de este proyecto debe tocar drivers de GPU ni los symlinks mencionados.
- Si más adelante se decide automatizar alguno de los dos, se necesita una nueva ADR que reemplace esta.
- Relacionado: [ADR 0011](0011-alcance-diferido-para-el-primer-hito.md) (alcance diferido general).
