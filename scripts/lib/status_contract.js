// scripts/lib/status_contract.js
//
// Contrato de estado enriquecido (Hito 3, ver docs/adr/0012-modelo-de-estado-enriquecido.md
// y docs/adr/0004-idempotencia-instalado-igual-skip.md). Sin dependencias
// externas a propósito, para poder probarlo (tests/test_status_mapping.js)
// sin necesitar `npm install` ni nada de la interfaz interactiva.

const KNOWN_STATUSES = ['INSTALLED', 'NOT_INSTALLED', 'OUTDATED', 'BROKEN', 'UNSUPPORTED', 'UNKNOWN'];

// Acción por defecto según el estado. INSTALLED nunca dispara 'reinstall' por
// defecto (ADR 0004): la persona usuaria debe pedirlo explícitamente.
const DEFAULT_ACTION_BY_STATUS = {
    INSTALLED: 'skip',
    NOT_INSTALLED: 'install',
    OUTDATED: 'update',
    BROKEN: 'repair',
    UNSUPPORTED: 'skip',
    UNKNOWN: 'skip'
};

const STATUS_LABELS = {
    INSTALLED: { icon: '✓', text: 'Instalado' },
    NOT_INSTALLED: { icon: '✗', text: 'No instalado' },
    OUTDATED: { icon: '⚠', text: 'Desactualizado' },
    BROKEN: { icon: '⚠', text: 'Roto' },
    UNSUPPORTED: { icon: '?', text: 'No soportado' },
    UNKNOWN: { icon: '?', text: 'Estado desconocido' }
};

// Motivo mostrado cuando una herramienta seleccionada se omite (acción 'skip').
const SKIP_REASON_BY_STATUS = {
    INSTALLED: 'ya está instalado y no requiere ninguna acción',
    UNSUPPORTED: 'no es compatible con este sistema, se omite',
    UNKNOWN: 'su estado no se pudo determinar, se omite por seguridad'
};

function normalizeStatus(rawStatus) {
    return KNOWN_STATUSES.includes(rawStatus) ? rawStatus : 'UNKNOWN';
}

// resolveStatusFromExecResult(rawStdout)
// Caso feliz: el script de status corrió y salió con código 0.
function resolveStatusFromExecResult(rawStdout) {
    return normalizeStatus((rawStdout || '').toString().trim());
}

// resolveStatusFromExecError(error)
//
// El script de status sale con código != 0 tanto para señalar un estado
// legítimo (por convención, NOT_INSTALLED/UNSUPPORTED imprimen su valor y
// salen 1, ver install_vim.sh) como para una falla real de ejecución
// (script inexistente/ENOENT, sin permiso, timeout, crash sin imprimir
// nada). Hay que distinguirlos:
//
// - Si el proceso alcanzó a escribir algo reconocible en stdout antes de
//   fallar, se respeta ese estado.
// - Si no escribió nada útil, es una falla real: se reporta UNKNOWN, nunca
//   NOT_INSTALLED por defecto (ver docs/adr/0012-modelo-de-estado-enriquecido.md).
function resolveStatusFromExecError(error) {
    const stdout = ((error && error.stdout) || '').toString().trim();
    if (stdout) {
        return normalizeStatus(stdout);
    }
    return 'UNKNOWN';
}

module.exports = {
    KNOWN_STATUSES,
    DEFAULT_ACTION_BY_STATUS,
    STATUS_LABELS,
    SKIP_REASON_BY_STATUS,
    normalizeStatus,
    resolveStatusFromExecResult,
    resolveStatusFromExecError
};
