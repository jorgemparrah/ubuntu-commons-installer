# 0018. kubectl se gestiona vía Mise, no vía Snap

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

`install_kubectl.sh` instala kubectl vía Snap. La evaluación inicial y `docs/TOOLS.md` recomendaban mantener esa fuente sin más contexto. Al revisar la pregunta abierta sobre la fuente de kubectl, se confirmó que Mise puede gestionar kubectl como un runtime/herramienta más (igual que Node, Python, etc.), lo cual no se había considerado antes.

## Decisión

kubectl se instala y gestiona a través de Mise en vez de Snap.

## Consecuencias

- `install_kubectl.sh` se reescribe para instalar/activar kubectl vía Mise.
- Esto no contradice el orden de fuentes de paquetes de [ADR 0010](0010-orden-de-fuentes-de-paquetes.md) (apt → vendor → Snap → Flatpak): ese orden aplica a **paquetes de aplicación**, mientras que kubectl pasa a tratarse como una herramienta de runtime gestionada por Mise, en la misma categoría que Node/Python/Go.
- `docs/TOOLS.md` se actualiza para reflejar este cambio de fuente.
- Relacionado: [ADR 0002](0002-mise-como-unico-gestor-runtime.md), [ADR 0010](0010-orden-de-fuentes-de-paquetes.md).
