# 0010. Orden de prioridad de fuentes de paquetes

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

El repositorio mezcla APT, repositorios de proveedor, archivos `.deb` descargados, Snap, e instaladores descargados, sin una política explícita de por qué se elige una fuente sobre otra.

Fuente: ASSESSMENT.md, ME-01. Ver también AGENT.md sección 15.

## Decisión

Salvo excepción documentada, el orden de preferencia para instalar una herramienta es:

1. repositorio oficial de Ubuntu;
2. repositorio APT oficial del proveedor;
3. paquete o instalador oficial del proveedor;
4. Snap;
5. Flatpak;
6. fuente comunitaria, solo con aprobación explícita.

Cada instalador debe documentar su fuente y su mecanismo de actualización.

## Consecuencias

- Al revisar o modernizar un instalador (ver ROADMAP.md, Etapa 7), corresponde verificar que su fuente respete este orden o dejar constancia de la excepción.
