# 0009. Postergar una arquitectura de plugins/metadata declarativa para instaladores

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El nombre, categoría y ruta de script de cada herramienta están declarados manualmente en `setup.js`, mientras cada instalador también define su propia identidad y comportamiento. Esto duplica metadata: agregar un script exige editar la lista central en JavaScript, y renombrar un script puede romper una entrada del menú sin avisar.

Fuente: ASSESSMENT.md, HI-06. También relevante: ASSESSMENT.md LO-03 señalaba que el modelo de una sola categoría por herramienta eventualmente se vuelve limitante (por ejemplo, Docker podría ser a la vez "development" y "system"); esto no es un problema inmediato y no debería disparar un refactor temprano hacia plugins.

## Decisión

No se implementa un framework de plugins completo todavía. Se mantienen los directorios de categoría actuales (`system/`, `editors/`, `development/`, `productivity/`, `maintenance/`) y la lista de `setup.js` mientras se completa el trabajo de bootstrap, backup y migraciones.

Una posible estructura futura, a revisar recién después de que esos hitos estén estables:

```
scripts/installers/docker/
├── metadata.json
└── installer.sh
```

## Consecuencias

- Se acepta la duplicación/drift de metadata a corto plazo como riesgo conocido.
- Disparador para revisar esta decisión: una vez completados los hitos de bootstrap Bash ([0001](0001-bootstrap-bash-sin-node.md)), backups ([0005](0005-gestor-de-backups-centralizado.md)), migraciones ([0006](0006-framework-de-migraciones-versionado.md)) y Mise ([0002](0002-mise-como-unico-gestor-runtime.md)), o cuando la cantidad de instaladores/categorías lo justifique.

## Revisión (2026-07-19)

El disparador ya se cumplió: los cuatro hitos referenciados (Bootstrap, Gestor de Backups, Framework de migraciones, Gestor de runtimes/Mise) están `Done` en `docs/ROADMAP.md` desde antes del cierre del Hito 9. Se revisó esta decisión (`docs/TECHNICAL_REVIEW.md`, hallazgo M9) y **se confirma la postergación**: no es que falten las condiciones técnicas, sino que el Hito 11 (Modernización de instaladores, ver [ADR 0029](0029-contrato-completo-de-instalador-referencia.md)) tiene prioridad más alta en el roadmap actual y aborda primero la consistencia del contrato de instalador (`status/install/uninstall/reinstall/update/repair`) antes de introducir una capa de metadata declarativa sobre ese contrato. La arquitectura de plugins sigue siendo Hito 14 (`Blocked`), sin fecha comprometida.
