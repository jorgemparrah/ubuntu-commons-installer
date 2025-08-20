const inquirer = require('inquirer');
const { execSync } = require('child_process');
const chalk = require('chalk');

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
        const status = execSync(`./${tool.script} status`, { encoding: 'utf8' }).trim();
        return status;
    } catch (error) {
        return 'NOT_INSTALLED';
    }
}

// Show main menu
async function showMainMenu() {
    const toolsWithStatus = await Promise.all(
        tools.map(async (tool) => {
            const status = await getToolStatus(tool);
            return { ...tool, status };
        })
    );
    const choices = [];
    const categories = ['SYSTEM', 'EDITORS', 'DEVELOPMENT', 'PRODUCTIVITY', 'MAINTENANCE'];
    
    categories.forEach(category => {
        choices.push(new inquirer.Separator(`=== ${category} ===`));
        
        const categoryTools = toolsWithStatus.filter(t => t.category === category);
        categoryTools.forEach(tool => {
            const statusIcon = tool.status === 'INSTALLED' ? '✓' : '✗';
            const statusText = tool.status === 'INSTALLED' ? 'Instalado' : 'No instalado';
            const action = tool.status === 'INSTALLED' ? 'reinstall' : 'install';
            
            choices.push({
                name: `${statusIcon} ${tool.name} (${statusText})`,
                value: { ...tool, action },
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

// Execute actions
async function executeActions(selectedTools) {
    console.log(chalk.blue('\n🚀 Ejecutando acciones...\n'));
    
    for (const tool of selectedTools) {
        const actionText = tool.action === 'reinstall' ? 'Reinstalando' : 'Instalando';
        console.log(chalk.yellow(`📦 ${actionText} ${tool.name}...`));
        
        try {
            execSync(`./${tool.script} ${tool.action}`, { stdio: 'inherit' });
            console.log(chalk.green(`✅ ${tool.name} completado`));
        } catch (error) {
            console.log(chalk.red(`❌ Error con ${tool.name}`));
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

main();
