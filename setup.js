const inquirer = require('inquirer');
const { execFileSync } = require('child_process');
const chalk = require('chalk');
const {
    DEFAULT_ACTION_BY_STATUS,
    STATUS_LABELS,
    SKIP_REASON_BY_STATUS,
    resolveStatusFromExecResult,
    resolveStatusFromExecError
} = require('./scripts/lib/status_contract');

// Tools configuration (Node.js removed from list since it's installed as dependency)
const tools = [
    // SYSTEM — cli-utils (ex agrupador "Development Tools", ver ADR 0035)
    { name: 'wget', script: 'scripts/system/install_wget.sh', category: 'SYSTEM' },
    { name: 'curl', script: 'scripts/system/install_curl.sh', category: 'SYSTEM' },
    { name: 'Git', script: 'scripts/system/install_git.sh', category: 'SYSTEM' },
    { name: 'build-essential', script: 'scripts/system/install_build_essential.sh', category: 'SYSTEM' },
    { name: 'software-properties-common', script: 'scripts/system/install_software_properties_common.sh', category: 'SYSTEM' },
    { name: 'apt-transport-https', script: 'scripts/system/install_apt_transport_https.sh', category: 'SYSTEM' },
    { name: 'GnuPG', script: 'scripts/system/install_gnupg2.sh', category: 'SYSTEM' },

    // SYSTEM — terminals
    { name: 'Terminator', script: 'scripts/system/install_terminator.sh', category: 'SYSTEM' },
    { name: 'Ranger', script: 'scripts/system/install_ranger.sh', category: 'SYSTEM' },
    { name: 'nnn', script: 'scripts/system/install_nnn.sh', category: 'SYSTEM' },
    { name: 'lf', script: 'scripts/system/install_lf.sh', category: 'SYSTEM' },
    { name: 'Yazi', script: 'scripts/system/install_yazi.sh', category: 'SYSTEM' },
    { name: 'Ghostty', script: 'scripts/system/install_ghostty.sh', category: 'SYSTEM' },
    { name: 'WezTerm', script: 'scripts/system/install_wezterm.sh', category: 'SYSTEM' },

    // SYSTEM — shell-personalization
    { name: 'Oh My Zsh', script: 'scripts/system/install_oh_my_zsh.sh', category: 'SYSTEM' },
    { name: 'Powerlevel10k', script: 'scripts/system/install_powerlevel10k.sh', category: 'SYSTEM' },

    // SYSTEM — gui-utils (Meld/Baobab/GParted: ex agrupador "System Utilities", ver ADR 0035)
    { name: 'Meld', script: 'scripts/system/install_meld.sh', category: 'SYSTEM' },
    { name: 'Baobab', script: 'scripts/system/install_baobab.sh', category: 'SYSTEM' },
    { name: 'GParted', script: 'scripts/system/install_gparted.sh', category: 'SYSTEM' },
    { name: 'GIMP', script: 'scripts/system/install_gimp.sh', category: 'SYSTEM' },
    { name: 'OBS Studio', script: 'scripts/system/install_obs_studio.sh', category: 'SYSTEM' },

    // SYSTEM — misc
    { name: 'cmatrix', script: 'scripts/system/install_cmatrix.sh', category: 'SYSTEM' },

    // MULTIMEDIA (ex agrupador "Multimedia Tools", ver ADR 0035; ya vivían
    // en category=multimedia en tools_catalog.sh, ahora también en el menú)
    { name: 'Cheese', script: 'scripts/system/install_cheese.sh', category: 'MULTIMEDIA' },
    { name: 'v4l-utils', script: 'scripts/system/install_v4l_utils.sh', category: 'MULTIMEDIA' },
    { name: 'ubuntu-restricted-extras', script: 'scripts/system/install_ubuntu_restricted_extras.sh', category: 'MULTIMEDIA' },
    { name: 'VLC', script: 'scripts/system/install_vlc.sh', category: 'MULTIMEDIA' },

    // EDITORS
    { name: 'Visual Studio Code', script: 'scripts/editors/install_vscode.sh', category: 'EDITORS' },
    { name: 'Cursor AI IDE', script: 'scripts/editors/install_cursor.sh', category: 'EDITORS' },
    { name: 'Antigravity IDE', script: 'scripts/editors/install_antigravity_ide.sh', category: 'EDITORS' },
    { name: 'Vim', script: 'scripts/editors/install_vim.sh', category: 'EDITORS' },
    
    // DEVELOPMENT
    { name: 'Docker', script: 'scripts/development/install_docker.sh', category: 'DEVELOPMENT' },
    { name: 'Yarn', script: 'scripts/development/install_yarn.sh', category: 'DEVELOPMENT' },
    { name: 'GitHub CLI', script: 'scripts/development/install_gh.sh', category: 'DEVELOPMENT' },
    { name: 'Postman', script: 'scripts/development/install_postman.sh', category: 'DEVELOPMENT' },
    { name: 'DBeaver', script: 'scripts/development/install_dbeaver.sh', category: 'DEVELOPMENT' },
    { name: 'GitKraken', script: 'scripts/development/install_gitkraken.sh', category: 'DEVELOPMENT' },
    { name: 'Insomnia', script: 'scripts/development/install_insomnia.sh', category: 'DEVELOPMENT' },
    { name: 'MongoDB Compass', script: 'scripts/development/install_mongodb_compass.sh', category: 'DEVELOPMENT' },
    { name: 'kubectl', script: 'scripts/development/install_kubectl.sh', category: 'DEVELOPMENT' },
    { name: 'VirtualBox', script: 'scripts/development/install_virtualbox.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — CLIs de IA (Hito 16, ver ADR 0036/0037)
    { name: 'Claude Code', script: 'scripts/development/install_claude_code.sh', category: 'DEVELOPMENT' },
    { name: 'Codex CLI', script: 'scripts/development/install_codex_cli.sh', category: 'DEVELOPMENT' },
    { name: 'OpenCode', script: 'scripts/development/install_opencode.sh', category: 'DEVELOPMENT' },
    { name: 'Antigravity CLI', script: 'scripts/development/install_antigravity.sh', category: 'DEVELOPMENT' },

    // PRODUCTIVITY
    { name: 'ULauncher', script: 'scripts/productivity/install_ulauncher.sh', category: 'PRODUCTIVITY' },
    { name: 'Google Chrome', script: 'scripts/productivity/install_chrome.sh', category: 'PRODUCTIVITY' },
    { name: 'Spotify', script: 'scripts/productivity/install_spotify.sh', category: 'PRODUCTIVITY' },
    { name: 'Zoom', script: 'scripts/productivity/install_zoom.sh', category: 'PRODUCTIVITY' },
    { name: 'Flameshot', script: 'scripts/productivity/install_flameshot.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — mensajería/comunicación (Hito 25)
    { name: 'Telegram Desktop', script: 'scripts/productivity/install_telegram_desktop.sh', category: 'PRODUCTIVITY' },
    { name: 'Slack', script: 'scripts/productivity/install_slack.sh', category: 'PRODUCTIVITY' },
    { name: 'Discord', script: 'scripts/productivity/install_discord.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — agentes de IA de propósito general (Hito 16, ver ADR 0036/0037)
    { name: 'Claude Desktop', script: 'scripts/productivity/install_claude_desktop.sh', category: 'PRODUCTIVITY' },
    { name: 'OpenClaw', script: 'scripts/productivity/install_openclaw.sh', category: 'PRODUCTIVITY' },
    { name: 'Hermes Agent', script: 'scripts/productivity/install_hermes_agent.sh', category: 'PRODUCTIVITY' },

    // MAINTENANCE (System Updates/Kernel & Headers movidos aquí desde
    // SYSTEM, ver ADR 0035 — consistente con category=maintenance en
    // tools_catalog.sh)
    { name: 'System Updates', script: 'scripts/system/install_system_update.sh', category: 'MAINTENANCE' },
    { name: 'Kernel & Headers', script: 'scripts/system/install_kernel.sh', category: 'MAINTENANCE' },
    { name: 'Final System Update', script: 'scripts/maintenance/install_final_update.sh', category: 'MAINTENANCE' }
];

// Get tool status. La distinción entre "no instalado" y "falla real de
// ejecución" vive en scripts/lib/status_contract.js (resolveStatusFromExec*),
// para poder probarla sin depender de execFileSync/inquirer/chalk.
async function getToolStatus(tool) {
    try {
        const rawStatus = execFileSync(`./${tool.script}`, ['status'], { encoding: 'utf8' });
        return resolveStatusFromExecResult(rawStatus);
    } catch (error) {
        return resolveStatusFromExecError(error);
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
    const categories = ['SYSTEM', 'MULTIMEDIA', 'EDITORS', 'DEVELOPMENT', 'PRODUCTIVITY', 'MAINTENANCE'];

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
            execFileSync(`./${tool.script}`, [tool.action], { stdio: 'inherit' });
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
// programa principal (`node setup.js`). El contrato de estado enriquecido
// vive en scripts/lib/status_contract.js, sin dependencias externas, para
// poder probarse (ver tests/test_status_mapping.js) sin requerir
// `npm install` ni la interfaz interactiva.
if (require.main === module) {
    main();
}
