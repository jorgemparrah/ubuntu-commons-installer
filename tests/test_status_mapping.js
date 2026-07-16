#!/usr/bin/env node
// tests/test_status_mapping.js
//
// Prueba no destructiva del contrato de estado enriquecido y del mapeo
// estado -> acción por defecto del Hito 3 (ver docs/ROADMAP.md y
// docs/adr/0004-idempotencia-instalado-igual-skip.md,
// docs/adr/0012-modelo-de-estado-enriquecido.md).
//
// No ejecuta ningún instalador ni requiere Node.js estar en un estado
// particular más allá de poder correr este archivo.
//
// Uso:
//   node tests/test_status_mapping.js

const path = require('path');
const {
    KNOWN_STATUSES,
    DEFAULT_ACTION_BY_STATUS,
    STATUS_LABELS,
    normalizeStatus
} = require(path.join(__dirname, '..', 'scripts', 'lib', 'status_contract.js'));

let run = 0;
let failed = 0;

function assertEqual(description, actual, expected) {
    run += 1;
    if (actual !== expected) {
        failed += 1;
        console.log(`FALLO - ${description} (se obtuvo '${actual}', se esperaba '${expected}')`);
    } else {
        console.log(`  OK  - ${description}`);
    }
}

// El hallazgo crítico que corrige este hito: INSTALLED nunca debe mapear a
// 'reinstall' por defecto.
assertEqual(
    "INSTALLED mapea a 'skip', no a 'reinstall'",
    DEFAULT_ACTION_BY_STATUS.INSTALLED,
    'skip'
);

assertEqual('NOT_INSTALLED mapea a install', DEFAULT_ACTION_BY_STATUS.NOT_INSTALLED, 'install');
assertEqual('OUTDATED mapea a update', DEFAULT_ACTION_BY_STATUS.OUTDATED, 'update');
assertEqual('BROKEN mapea a repair', DEFAULT_ACTION_BY_STATUS.BROKEN, 'repair');
assertEqual('UNSUPPORTED mapea a skip', DEFAULT_ACTION_BY_STATUS.UNSUPPORTED, 'skip');
assertEqual('UNKNOWN mapea a skip', DEFAULT_ACTION_BY_STATUS.UNKNOWN, 'skip');

for (const status of KNOWN_STATUSES) {
    assertEqual(`normalizeStatus('${status}') se mantiene igual`, normalizeStatus(status), status);
    run += 1;
    if (!STATUS_LABELS[status]) {
        failed += 1;
        console.log(`FALLO - STATUS_LABELS tiene una entrada para '${status}'`);
    } else {
        console.log(`  OK  - STATUS_LABELS tiene una entrada para '${status}'`);
    }
}

assertEqual(
    "normalizeStatus('') cae a UNKNOWN",
    normalizeStatus(''),
    'UNKNOWN'
);
assertEqual(
    "normalizeStatus('algo-no-reconocido') cae a UNKNOWN",
    normalizeStatus('algo-no-reconocido'),
    'UNKNOWN'
);
assertEqual(
    "normalizeStatus('installed') (minúscula) cae a UNKNOWN, no se asume INSTALLED",
    normalizeStatus('installed'),
    'UNKNOWN'
);

console.log('');
console.log(`Pruebas ejecutadas: ${run}`);
console.log(`Fallos: ${failed}`);

process.exit(failed > 0 ? 1 : 0);
