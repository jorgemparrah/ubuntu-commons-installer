# 0013. Separar acciones de mantenimiento de sistema de los instaladores de aplicaciones

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

Entradas como "System Updates", "Kernel & Headers" y "Final System Update" aparecen hoy junto a aplicaciones normales en el mismo flujo de checkboxes del menú interactivo. Esto permite que un usuario seleccione mantenimiento de sistema de alto impacto (por ejemplo, un cambio de kernel que requiere reinicio) como si fuera una aplicación cualquiera, y `reinstall` no tiene sentido para una tarea de mantenimiento.

Fuente: ASSESSMENT.md, ME-04.

## Decisión

Se separan conceptualmente cinco tipos de acción, aunque convivan temporalmente en los mismos directorios de categoría durante la transición:

- acciones de aprovisionamiento;
- instaladores de aplicaciones;
- acciones de mantenimiento;
- diagnósticos;
- migraciones.

No todas las entradas del menú se tratan como "herramientas idénticas".

## Consecuencias

- El menú interactivo debe poder distinguir visualmente una acción de mantenimiento/sistema de un instalador de aplicación.
- Los directorios actuales (`scripts/system/`, `scripts/maintenance/`, etc.) no se mueven de inmediato; el cambio es primero conceptual/de interfaz.
