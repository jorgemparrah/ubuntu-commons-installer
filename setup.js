const inquirer = require('inquirer');
const { execSync } = require('child_process');
const chalk = require('chalk');

// Contrato de estado enriquecido (Hito 3, ver docs/adr/0012-modelo-de-estado-enriquecido.md).
// Los instaladores existentes solo devuelven INSTALLED/NOT_INSTALLED todavía;
// se adoptan aquí de forma incremental (ver docs/adr/0004-idempotencia-instalado-igual-skip.md).
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

// Tools configuration (Node.js removed from list since it's installed as dependency)
const tools = [
    // SYSTEM
    { name: 'System Updates', script: 'scripts/system/install_system_update.sh', category: 'SYSTEM' },
    { name: 'Kernel & Headers', script: 'scripts/system/install_kernel.sh', category: 'SYSTEM' },
    { name: 'Development Tools', script: 'scripts/system/install_development_tools.sh', category: 'SYSTEM' },
    { name: 'System Utilities', script: 'scripts/system/install_system_utils.sh', category: 'SYSTEM' },
    { name: 'Multimedia Tools', script: 'scripts/system/install_multimedia.sh', category: 'SYSTEM' },
    { name: 'Terminator', script: 'scripts/system/install_terminator.sh', category: 'SYSTEM' },
    { name: 'Oh My Zsh', script: 'scripts/system/install_oh_my_zsh.sh', category: 'SYSTEM' },
    { name: 'Powerlevel10k', script: 'scripts/system/install_powerlevel10k.sh', category: 'SYSTEM' },
    { name: 'Ranger', script: 'scripts/system/install_ranger.sh', category: 'SYSTEM' },
    { name: 'cmatrix', script: 'scripts/system/install_cmatrix.sh', category: 'SYSTEM' },
    { name: 'GIMP', script: 'scripts/system/install_gimp.sh', category: 'SYSTEM' },
    { name: 'OBS Studio', script: 'scripts/system/install_obs_studio.sh', category: 'SYSTEM' },
    
    // EDITORS
    { name: 'Visual Studio Code', script: 'scripts/editors/install_vscode.sh', category: 'EDITORS' },
    { name: 'Cursor AI IDE', script: 'scripts/editors/install_cursor.sh', category: 'EDITORS' },
    { name: 'Vim', script: 'scripts/editors/install_vim.sh', category: 'EDITORS' },
    
    // DEVELOPMENT
    { name: 'Docker', script: 'scripts/development/install_docker.sh', category: 'DEVELOPMENT' },
    { name: 'Yarn', script: 'scripts/development/install_yarn.sh', category: 'DEVELOPMENT' },
    { name: 'Postman', script: 'scripts/development/install_postman.sh', category: 'DEVELOPMENT' },
    { name: 'DBeaver', script: 'scripts/development/install_dbeaver.sh', category: 'DEVELOPMENT' },
    { name: 'GitKraken', script: 'scripts/development/install_gitkraken.sh', category: 'DEVELOPMENT' },
    { name: 'Insomnia', script: 'scripts/development/install_insomnia.sh', category: 'DEVELOPMENT' },
    { name: 'MongoDB Compass', script: 'scripts/development/install_mongodb_compass.sh', category: 'DEVELOPMENT' },
    { name: 'kubectl', script: 'scripts/development/install_kubectl.sh', category: 'DEVELOPMENT' },
    
    // PRODUCTIVITY
    { name: 'ULauncher', script: 'scripts/productivity/install_ulauncher.sh', category: 'PRODUCTIVITY' },
    { name: 'Google Chrome', script: 'scripts/productivity/install_chrome.sh', category: 'PRODUCTIVITY' },
    { name: 'Spotify', script: 'scripts/productivity/install_spotify.sh', category: 'PRODUCTIVITY' },
    { name: 'Zoom', script: 'scripts/productivity/install_zoom.sh', category: 'PRODUCTIVITY' },
    { name: 'Flameshot', script: 'scripts/productivity/install_flameshot.sh', category: 'PRODUCTIVITY' },
    
    // MAINTENANCE
    { name: 'Final System Update', script: 'scripts/maintenance/install_final_update.sh', category: 'MAINTENANCE' }
];

// Get tool status
async function getToolStatus(tool) {
    try {
        const rawStatus = execSync(`./${tool.script} status`, { encoding: 'utf8' }).trim();
        return normalizeStatus(rawStatus);
    } catch (error) {
        // Convención existente: el script de status sale con código != 0
        // específicamente para señalar "no instalado" (ver install_vim.sh).
        return 'NOT_INSTALLED';
    }
}

// Show main menu
async function showMainMenu() {
    const toolsWithStatus = await Promise.all(
        tools.map(async (tool) => {
            const status = await getToolStatus(tool);
            const action = DEFAULT_ACTION_BY_STATUS[status] || 'skip';
            return { ...tool, status, action };
        })
    );
    const choices = [];
    const categories = ['SYSTEM', 'EDITORS', 'DEVELOPMENT', 'PRODUCTIVITY', 'MAINTENANCE'];

    categories.forEach(category => {
        choices.push(new inquirer.Separator(`=== ${category} ===`));

        const categoryTools = toolsWithStatus.filter(t => t.category === category);
        categoryTools.forEach(tool => {
            const { icon, text } = STATUS_LABELS[tool.status];

            choices.push({
                name: `${icon} ${tool.name} (${text})`,
                value: tool,
                checked: false
            });
        });
    });

    const { selectedTools } = await inquirer.prompt([
        {
            type: 'checkbox',
            name: 'selectedTools',
            message: 'Selecciona las herramientas:',
            choices: choices,
            pageSize: 40
        }
    ]);

    return selectedTools;
}

// Para cada herramienta seleccionada cuya acción por defecto sea 'skip'
// porque ya está INSTALLED, se ofrece explícitamente forzar un reinstall.
// Nunca ocurre automáticamente (ver docs/adr/0004-idempotencia-instalado-igual-skip.md).
async function confirmForcedReinstalls(selectedTools) {
    for (const tool of selectedTools) {
        if (tool.status !== 'INSTALLED') {
            continue;
        }

        const { forceReinstall } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'forceReinstall',
                message: `${tool.name} ya está instalado y aparenta estar sano. ¿Forzar reinstalación de todas formas?`,
                default: false
            }
        ]);

        tool.action = forceReinstall ? 'reinstall' : 'skip';
    }
}

// Execute actions
async function executeActions(selectedTools) {
    console.log(chalk.blue('\n🚀 Ejecutando acciones...\n'));

    const ACTION_TEXT = {
        install: 'Instalando',
        update: 'Actualizando',
        repair: 'Reparando',
        reinstall: 'Reinstalando',
        uninstall: 'Desinstalando'
    };

    for (const tool of selectedTools) {
        if (tool.action === 'skip') {
            const reason = SKIP_REASON_BY_STATUS[tool.status] || 'no requiere ninguna acción';
            console.log(chalk.gray(`⏭️  ${tool.name}: ${reason}.`));
            console.log('');
            continue;
        }

        const actionText = ACTION_TEXT[tool.action] || 'Ejecutando acción sobre';
        console.log(chalk.yellow(`📦 ${actionText} ${tool.name}...`));

        try {
            execSync(`./${tool.script} ${tool.action}`, { stdio: 'inherit' });
            console.log(chalk.green(`✅ ${tool.name} completado`));
        } catch (error) {
            console.log(chalk.red(`❌ Error con ${tool.name} (acción '${tool.action}' no disponible o falló; ver salida arriba)`));
        }

        console.log('');
    }
}

// Main function
async function main() {
    try {
        console.log(chalk.cyan.bold('🚀 Post-Install Setup\n'));
        
        const selectedTools = await showMainMenu();

        if (selectedTools.length === 0) {
            console.log(chalk.yellow('No se seleccionaron herramientas.'));
            return;
        }

        await confirmForcedReinstalls(selectedTools);

        const { confirm } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: `¿Proceder con ${selectedTools.length} herramienta(s)?`,
                default: true
            }
        ]);

        if (confirm) {
            await executeActions(selectedTools);
            console.log(chalk.green.bold('\n🎉 ¡Instalación completada!'));
        }
        
    } catch (error) {
        console.error(chalk.red('Error:', error.message));
        process.exit(1);
    }
}

// Solo se ejecuta el flujo interactivo cuando este archivo corre como
// programa principal (`node setup.js`), no cuando se importa para pruebas
// (ver tests/test_status_mapping.js).
if (require.main === module) {
    main();
}

module.exports = {
    KNOWN_STATUSES,
    DEFAULT_ACTION_BY_STATUS,
    STATUS_LABELS,
    SKIP_REASON_BY_STATUS,
    normalizeStatus
};
