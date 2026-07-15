# 0002. Mise como único gestor de runtimes

Fecha: 2026-07-15
Estado: Aceptada

## Contexto

`install_nodejs.sh` descarga e instala NVM, lo carga en el shell activo e instala la LTS vigente. Esto contradice la regla del proyecto de que Mise debe ser el único gestor de runtimes soportado, y acopla el bootstrap a una herramienta que se quiere reemplazar.

Fuente: ASSESSMENT.md, CR-01.

## Decisión

Mise es el único gestor de runtimes soportado hacia adelante. No se introducen NVM, ASDF ni Volta salvo pedido explícito.

- El bootstrap nuevo instala/activa Mise, nunca NVM.
- `install_nodejs.sh` no se reescribe en el momento como instalador genérico de Mise: primero se introducen los módulos de runtime y migración (ver [0003](0003-migracion-nvm-sin-borrado-directo.md)), y luego se retira o redirige el script antiguo.

## Consecuencias

- Se necesita un módulo de runtime independiente del instalador legacy de Node.
- La migración NVM → Mise es un prerequisito para retirar `install_nodejs.sh`.
- Relacionado: [0001](0001-bootstrap-bash-sin-node.md), [0003](0003-migracion-nvm-sin-borrado-directo.md).
