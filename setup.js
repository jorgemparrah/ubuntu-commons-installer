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
    { name: 'wget', description: 'Cliente de descarga de archivos por HTTP/FTP desde la línea de comandos', script: 'scripts/system/install_wget.sh', category: 'SYSTEM' },
    { name: 'curl', description: 'Cliente de transferencia de datos por URL desde la línea de comandos', script: 'scripts/system/install_curl.sh', category: 'SYSTEM' },
    { name: 'Git', description: 'Sistema de control de versiones distribuido', script: 'scripts/system/install_git.sh', category: 'SYSTEM' },
    { name: 'build-essential', description: 'Paquete meta con las herramientas de compilación básicas (gcc, make, etc.)', script: 'scripts/system/install_build_essential.sh', category: 'SYSTEM' },
    { name: 'software-properties-common', description: 'Utilidades para gestionar repositorios y PPAs de APT', script: 'scripts/system/install_software_properties_common.sh', category: 'SYSTEM' },
    { name: 'apt-transport-https', description: 'Soporte para que APT descargue paquetes por HTTPS', script: 'scripts/system/install_apt_transport_https.sh', category: 'SYSTEM' },
    { name: 'GnuPG', description: 'Herramienta de cifrado y firma digital (OpenPGP)', script: 'scripts/system/install_gnupg2.sh', category: 'SYSTEM' },
    { name: 'fzf', description: 'Buscador difuso (', script: 'scripts/system/install_fzf.sh', category: 'SYSTEM' },
    { name: 'thefuck', description: 'Corrige automáticamente el último comando de terminal mal escrito', script: 'scripts/system/install_thefuck.sh', category: 'SYSTEM' },
    { name: 'jq', description: 'Procesador de JSON en la línea de comandos', script: 'scripts/system/install_jq.sh', category: 'SYSTEM' },
    { name: 'yq', description: 'Procesador de YAML en la línea de comandos (equivalente a jq)', script: 'scripts/system/install_yq.sh', category: 'SYSTEM' },
    { name: 'HTTPie', description: 'Cliente HTTP de línea de comandos con salida legible y coloreada', script: 'scripts/system/install_httpie.sh', category: 'SYSTEM' },
    { name: 'xh', description: 'Cliente HTTP de línea de comandos, reimplementación de HTTPie en Rust', script: 'scripts/system/install_xh.sh', category: 'SYSTEM' },
    { name: 'dust', description: 'Reemplazo de \'du\' que muestra el uso de disco en forma de árbol', script: 'scripts/system/install_dust.sh', category: 'SYSTEM' },
    { name: 'duf', description: 'Reemplazo de \'df\' con una salida más legible del uso de discos', script: 'scripts/system/install_duf.sh', category: 'SYSTEM' },
    { name: 'procs', description: 'Reemplazo de \'ps\' para listar procesos con salida más legible', script: 'scripts/system/install_procs.sh', category: 'SYSTEM' },
    { name: 'zoxide', description: 'Reemplazo inteligente de \'cd\' que aprende las rutas usadas con frecuencia', script: 'scripts/system/install_zoxide.sh', category: 'SYSTEM' },
    { name: 'btop', description: 'Monitor de recursos del sistema (CPU/memoria/red/procesos) en la terminal', script: 'scripts/system/install_btop.sh', category: 'SYSTEM' },
    { name: 'tealdeer', description: 'Cliente rápido (en Rust) de tldr: páginas de ayuda de comandos simplificadas', script: 'scripts/system/install_tealdeer.sh', category: 'SYSTEM' },
    { name: 'ripgrep', description: 'Búsqueda de texto recursiva, mucho más rápida que grep', script: 'scripts/system/install_ripgrep.sh', category: 'SYSTEM' },
    { name: 'fd', description: 'Reemplazo simple y rápido de find', script: 'scripts/system/install_fd.sh', category: 'SYSTEM' },
    { name: 'bat', description: 'Reemplazo de cat con resaltado de sintaxis y números de línea', script: 'scripts/system/install_bat.sh', category: 'SYSTEM' },
    { name: 'eza', description: 'Reemplazo moderno de ls, con colores y soporte de Git', script: 'scripts/system/install_eza.sh', category: 'SYSTEM' },
    { name: 'tree', description: 'Listado de directorios en forma de árbol', script: 'scripts/system/install_tree.sh', category: 'SYSTEM' },
    { name: 'unzip/zip', description: 'Utilidades estándar de compresión y descompresión ZIP', script: 'scripts/system/install_zip_utils.sh', category: 'SYSTEM' },
    { name: 'rsync', description: 'Sincronización y transferencia eficiente de archivos', script: 'scripts/system/install_rsync.sh', category: 'SYSTEM' },

    // SYSTEM — terminals
    { name: 'Terminator', description: 'Emulador de terminal con soporte para dividir la ventana en paneles', script: 'scripts/system/install_terminator.sh', category: 'SYSTEM' },
    { name: 'Ranger', description: 'Gestor de archivos de terminal con vista en columnas al estilo Miller', script: 'scripts/system/install_ranger.sh', category: 'SYSTEM' },
    { name: 'nnn', description: 'Gestor de archivos de terminal minimalista y muy rápido', script: 'scripts/system/install_nnn.sh', category: 'SYSTEM' },
    { name: 'lf', description: 'Gestor de archivos de terminal inspirado en ranger, escrito en Go', script: 'scripts/system/install_lf.sh', category: 'SYSTEM' },
    { name: 'Yazi', description: 'Gestor de archivos de terminal moderno con vista previa, escrito en Rust', script: 'scripts/system/install_yazi.sh', category: 'SYSTEM' },
    { name: 'Ghostty', description: 'Emulador de terminal moderno acelerado por GPU', script: 'scripts/system/install_ghostty.sh', category: 'SYSTEM' },
    { name: 'WezTerm', description: 'Emulador de terminal acelerado por GPU con multiplexor integrado', script: 'scripts/system/install_wezterm.sh', category: 'SYSTEM' },
    { name: 'Kitty', description: 'Emulador de terminal acelerado por GPU', script: 'scripts/system/install_kitty.sh', category: 'SYSTEM' },
    { name: 'Alacritty', description: 'Emulador de terminal minimalista acelerado por GPU', script: 'scripts/system/install_alacritty.sh', category: 'SYSTEM' },

    // SYSTEM — shell-personalization
    { name: 'Oh My Zsh', description: 'Framework de configuración y temas para el shell Zsh', script: 'scripts/system/install_oh_my_zsh.sh', category: 'SYSTEM' },
    { name: 'Powerlevel10k', description: 'Tema visual rápido y personalizable para el prompt de Zsh', script: 'scripts/system/install_powerlevel10k.sh', category: 'SYSTEM' },

    // SYSTEM — gui-utils (Meld/Baobab/GParted: ex agrupador "System Utilities", ver ADR 0035)
    { name: 'Meld', description: 'Herramienta gráfica de comparación y fusión de archivos/carpetas', script: 'scripts/system/install_meld.sh', category: 'SYSTEM' },
    { name: 'Baobab', description: 'Analizador gráfico de uso de disco', script: 'scripts/system/install_baobab.sh', category: 'SYSTEM' },
    { name: 'GParted', description: 'Editor gráfico de particiones de disco', script: 'scripts/system/install_gparted.sh', category: 'SYSTEM' },

    // SYSTEM — extras
    { name: 'cmatrix', description: 'Efecto visual de terminal estilo Matrix, sin utilidad práctica más allá de lo decorativo', script: 'scripts/system/install_cmatrix.sh', category: 'SYSTEM' },

    // MULTIMEDIA (ex agrupador "Multimedia Tools", ver ADR 0035; ya vivían
    // en category=multimedia en tools_catalog.sh, ahora también en el menú)
    { name: 'Cheese', description: 'Aplicación de cámara web para tomar fotos y video', script: 'scripts/system/install_cheese.sh', category: 'MULTIMEDIA' },
    { name: 'v4l-utils', description: 'Utilidades de línea de comandos para dispositivos de video (Video4Linux)', script: 'scripts/system/install_v4l_utils.sh', category: 'MULTIMEDIA' },
    { name: 'ubuntu-restricted-extras', description: 'Paquete meta con códecs multimedia y fuentes de uso restringido', script: 'scripts/system/install_ubuntu_restricted_extras.sh', category: 'MULTIMEDIA' },
    { name: 'VLC', description: 'Reproductor multimedia universal', script: 'scripts/system/install_vlc.sh', category: 'MULTIMEDIA' },

    // MULTIMEDIA — gráficos (GIMP/OBS Studio movidos aquí desde SYSTEM el
    // 2026-07-22, consistente con category=multimedia en
    // tools_catalog.sh desde la recategorización del mismo día; Inkscape
    // y Krita nuevos, Hito 35)
    { name: 'GIMP', description: 'Editor de imágenes raster (equivalente libre a Photoshop)', script: 'scripts/system/install_gimp.sh', category: 'MULTIMEDIA' },
    { name: 'OBS Studio', description: 'Software de grabación de pantalla y transmisión en vivo', script: 'scripts/system/install_obs_studio.sh', category: 'MULTIMEDIA' },
    { name: 'Inkscape', description: 'Editor de gráficos vectoriales', script: 'scripts/system/install_inkscape.sh', category: 'MULTIMEDIA' },
    { name: 'Krita', description: 'Aplicación de pintura digital e ilustración', script: 'scripts/system/install_krita.sh', category: 'MULTIMEDIA' },

    // MULTIMEDIA — línea de comandos (Hito 43)
    { name: 'ImageMagick', description: 'Suite de manipulación de imágenes por línea de comandos', script: 'scripts/system/install_imagemagick.sh', category: 'MULTIMEDIA' },
    { name: 'FFmpeg', description: 'Conversión y procesamiento de audio y video por línea de comandos', script: 'scripts/system/install_ffmpeg.sh', category: 'MULTIMEDIA' },

    // EDITORS
    { name: 'Visual Studio Code', description: 'Editor de código de Microsoft con soporte de extensiones', script: 'scripts/editors/install_vscode.sh', category: 'EDITORS' },
    { name: 'VSCodium', description: 'Build de Visual Studio Code sin telemetría ni marca de Microsoft', script: 'scripts/editors/install_vscodium.sh', category: 'EDITORS' },
    { name: 'Vim', description: 'Editor de texto modal clásico de terminal', script: 'scripts/editors/install_vim.sh', category: 'EDITORS' },
    { name: 'Neovim', description: 'Fork moderno de Vim con soporte nativo de LSP', script: 'scripts/editors/install_neovim.sh', category: 'EDITORS' },

    // DEVELOPMENT
    { name: 'Docker', description: 'Motor de contenedores para empaquetar y ejecutar aplicaciones', script: 'scripts/development/install_docker.sh', category: 'DEVELOPMENT' },
    { name: 'Yarn', description: 'Gestor de paquetes para proyectos Node.js', script: 'scripts/development/install_yarn.sh', category: 'DEVELOPMENT' },
    { name: 'pnpm', description: 'Gestor de paquetes para proyectos Node.js, alternativa rápida a npm/Yarn', script: 'scripts/development/install_pnpm.sh', category: 'DEVELOPMENT' },
    { name: 'GitHub CLI', description: 'Cliente de línea de comandos oficial de GitHub', script: 'scripts/development/install_gh.sh', category: 'DEVELOPMENT' },
    { name: 'Postman', description: 'Cliente gráfico para probar y documentar APIs', script: 'scripts/development/install_postman.sh', category: 'DEVELOPMENT' },
    { name: 'DBeaver', description: 'Cliente gráfico universal de bases de datos SQL/NoSQL', script: 'scripts/development/install_dbeaver.sh', category: 'DEVELOPMENT' },
    { name: 'GitKraken', description: 'Cliente gráfico de Git', script: 'scripts/development/install_gitkraken.sh', category: 'DEVELOPMENT' },
    { name: 'Insomnia', description: 'Cliente gráfico para probar APIs REST/GraphQL', script: 'scripts/development/install_insomnia.sh', category: 'DEVELOPMENT' },
    { name: 'MongoDB Compass', description: 'Cliente gráfico oficial para explorar y consultar bases de datos MongoDB', script: 'scripts/development/install_mongodb_compass.sh', category: 'DEVELOPMENT' },
    { name: 'kubectl', description: 'Cliente de línea de comandos para administrar clústeres de Kubernetes', script: 'scripts/development/install_kubectl.sh', category: 'DEVELOPMENT' },
    { name: 'VirtualBox', description: 'Software de virtualización de máquinas virtuales de Oracle', script: 'scripts/development/install_virtualbox.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — herramientas CLI (Hito 28)
    { name: 'ngrok', description: 'Túneles seguros para exponer servicios locales a internet', script: 'scripts/development/install_ngrok.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — misceláneos (Hito 29)
    { name: 'SoapUI', description: 'Herramienta de pruebas de servicios web SOAP/REST', script: 'scripts/development/install_soapui.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — clientes API open source (Hito 31)
    { name: 'Bruno', description: 'Cliente API git-native, local-first, alternativa a Postman/Insomnia', script: 'scripts/development/install_bruno.sh', category: 'DEVELOPMENT' },
    { name: 'Hoppscotch', description: 'Cliente API 100% libre y self-hosteable, alternativa a Postman', script: 'scripts/development/install_hoppscotch.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — clientes de bases de datos open source (Hito 32)
    { name: 'Beekeeper Studio', description: 'Cliente SQL multi-motor, alternativa libre a DBeaver', script: 'scripts/development/install_beekeeper_studio.sh', category: 'DEVELOPMENT' },
    { name: 'DbGate', description: 'Cliente SQL/NoSQL multi-motor, alternativa libre a DBeaver', script: 'scripts/development/install_dbgate.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — contenedores, Git TUI y virtualización libre (Hito 33)
    { name: 'Podman', description: 'Motor de contenedores sin daemon y sin privilegios de root, alternativa a Docker', script: 'scripts/development/install_podman.sh', category: 'DEVELOPMENT' },
    { name: 'Lazygit', description: 'Interfaz de terminal (TUI) para operar Git de forma visual', script: 'scripts/development/install_lazygit.sh', category: 'DEVELOPMENT' },
    { name: 'virt-manager', description: 'Interfaz gráfica para administrar máquinas virtuales QEMU/KVM', script: 'scripts/development/install_virt_manager.sh', category: 'DEVELOPMENT' },

    // DEVELOPMENT — CLIs de nube e infraestructura como código (Hito 42)
    { name: 'Terraform', description: 'Herramienta de infraestructura como código de HashiCorp (licencia BUSL, no FOSS desde 2023)', script: 'scripts/development/install_terraform.sh', category: 'DEVELOPMENT' },
    { name: 'OpenTofu', description: 'Fork FOSS de Terraform (MPL-2.0), mantenido por la Linux Foundation', script: 'scripts/development/install_opentofu.sh', category: 'DEVELOPMENT' },
    { name: 'AWS CLI', description: 'Cliente de línea de comandos oficial de Amazon Web Services', script: 'scripts/development/install_awscli.sh', category: 'DEVELOPMENT' },
    { name: 'Azure CLI', description: 'Cliente de línea de comandos oficial de Microsoft Azure', script: 'scripts/development/install_azure_cli.sh', category: 'DEVELOPMENT' },
    { name: 'Google Cloud CLI', description: 'Cliente de línea de comandos oficial de Google Cloud Platform', script: 'scripts/development/install_google_cloud_cli.sh', category: 'DEVELOPMENT' },

    // AI — asistentes de escritorio (ver ADR 0043)
    { name: 'Claude Desktop', description: 'Aplicación de escritorio de Claude (incluye el modo Cowork)', script: 'scripts/productivity/install_claude_desktop.sh', category: 'AI' },
    { name: 'OpenClaw', description: 'Agente de IA de propósito general para el escritorio', script: 'scripts/productivity/install_openclaw.sh', category: 'AI' },
    { name: 'Hermes Agent', description: 'Agente de IA de propósito general para el escritorio', script: 'scripts/productivity/install_hermes_agent.sh', category: 'AI' },

    // AI — CLIs (Hito 16, ver ADR 0036/0037/0043)
    { name: 'Claude Code', description: 'CLI de asistencia de código con IA de Anthropic', script: 'scripts/development/install_claude_code.sh', category: 'AI' },
    { name: 'Codex CLI', description: 'CLI de asistencia de código con IA de OpenAI', script: 'scripts/development/install_codex_cli.sh', category: 'AI' },
    { name: 'OpenCode', description: 'CLI de asistencia de código con IA, de código abierto', script: 'scripts/development/install_opencode.sh', category: 'AI' },
    { name: 'Antigravity CLI', description: 'CLI de asistencia de código con IA de Google (comando \'agy\')', script: 'scripts/development/install_antigravity.sh', category: 'AI' },

    // AI — IDEs (ver ADR 0043)
    { name: 'Cursor AI IDE', description: 'Editor de código basado en VS Code con asistencia de IA integrada', script: 'scripts/editors/install_cursor.sh', category: 'AI' },
    { name: 'Antigravity IDE', description: 'IDE de Google con asistencia de IA integrada', script: 'scripts/editors/install_antigravity_ide.sh', category: 'AI' },

    // AI — modelos locales (Hito 28, ver ADR 0043)
    { name: 'Ollama', description: 'Runtime para correr modelos de lenguaje (LLM) de forma local', script: 'scripts/development/install_ollama.sh', category: 'AI' },

    // PRODUCTIVITY
    { name: 'ULauncher', description: 'Lanzador de aplicaciones tipo Spotlight/Albert para el escritorio', script: 'scripts/productivity/install_ulauncher.sh', category: 'PRODUCTIVITY' },
    { name: 'Google Chrome', description: 'Navegador web de Google', script: 'scripts/productivity/install_chrome.sh', category: 'PRODUCTIVITY' },
    { name: 'Spotify', description: 'Cliente de streaming de música', script: 'scripts/productivity/install_spotify.sh', category: 'PRODUCTIVITY' },
    { name: 'Zoom', description: 'Cliente de videoconferencias', script: 'scripts/productivity/install_zoom.sh', category: 'PRODUCTIVITY' },
    { name: 'Flameshot', description: 'Herramienta de capturas de pantalla con anotaciones', script: 'scripts/productivity/install_flameshot.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — mensajería/comunicación (Hito 25)
    { name: 'Telegram Desktop', description: 'Cliente de escritorio de Telegram', script: 'scripts/productivity/install_telegram_desktop.sh', category: 'PRODUCTIVITY' },
    { name: 'Slack', description: 'Cliente de escritorio de Slack', script: 'scripts/productivity/install_slack.sh', category: 'PRODUCTIVITY' },
    { name: 'Discord', description: 'Cliente de escritorio de Discord', script: 'scripts/productivity/install_discord.sh', category: 'PRODUCTIVITY' },
    { name: 'Element', description: 'Cliente de escritorio oficial del protocolo de mensajería Matrix', script: 'scripts/productivity/install_element.sh', category: 'PRODUCTIVITY' },
    { name: 'Signal Desktop', description: 'Cliente de escritorio de Signal Messenger', script: 'scripts/productivity/install_signal_desktop.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — productividad de escritorio (Hito 26)
    { name: 'LibreOffice', description: 'Suite ofimática libre (procesador de texto, hoja de cálculo, presentaciones)', script: 'scripts/productivity/install_libreoffice.sh', category: 'PRODUCTIVITY' },
    { name: 'OnlyOffice', description: 'Suite ofimática con alta compatibilidad de formato con Microsoft Office', script: 'scripts/productivity/install_onlyoffice.sh', category: 'PRODUCTIVITY' },
    { name: 'Obsidian', description: 'Aplicación de notas en Markdown con vinculación entre notas (grafo de conocimiento)', script: 'scripts/productivity/install_obsidian.sh', category: 'PRODUCTIVITY' },
    { name: 'Joplin', description: 'Aplicación de notas en Markdown 100% libre, alternativa a Obsidian', script: 'scripts/productivity/install_joplin.sh', category: 'PRODUCTIVITY' },
    { name: 'KeePassXC', description: 'Gestor de contraseñas libre con cifrado local', script: 'scripts/productivity/install_keepassxc.sh', category: 'PRODUCTIVITY' },
    { name: 'Bitwarden', description: 'Gestor de contraseñas en la nube con cliente de escritorio libre', script: 'scripts/productivity/install_bitwarden.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — navegadores (Hito 27)
    { name: 'Brave', description: 'Navegador basado en Chromium con bloqueo de rastreadores integrado', script: 'scripts/productivity/install_brave.sh', category: 'PRODUCTIVITY' },
    { name: 'Chromium', description: 'Navegador de código abierto, base de Google Chrome', script: 'scripts/productivity/install_chromium.sh', category: 'PRODUCTIVITY' },

    // PRODUCTIVITY — misceláneos (Hito 29)
    { name: 'LocalSend', description: 'Envío de archivos entre dispositivos en la misma red local, sin nube', script: 'scripts/productivity/install_localsend.sh', category: 'PRODUCTIVITY' },
    { name: 'Syncthing', description: 'Sincronización de archivos P2P entre dispositivos, sin nube', script: 'scripts/productivity/install_syncthing.sh', category: 'PRODUCTIVITY' },
    { name: 'FileZilla', description: 'Cliente de transferencia de archivos FTP/SFTP', script: 'scripts/productivity/install_filezilla.sh', category: 'PRODUCTIVITY' },
    { name: 'Steam', description: 'Plataforma de distribución de videojuegos de Valve', script: 'scripts/productivity/install_steam.sh', category: 'PRODUCTIVITY' },
    { name: 'Lutris', description: 'Gestor de bibliotecas de juegos multi-plataforma (Wine/Proton/emuladores)', script: 'scripts/productivity/install_lutris.sh', category: 'PRODUCTIVITY' },
    { name: 'Heroic Games Launcher', description: 'Launcher libre para juegos de Epic Games Store, GOG y Amazon Games', script: 'scripts/productivity/install_heroic.sh', category: 'PRODUCTIVITY' },
    { name: 'Okular', description: 'Visor y editor de documentos/PDF de KDE', script: 'scripts/productivity/install_okular.sh', category: 'PRODUCTIVITY' },

    // MAINTENANCE (System Updates/Kernel & Headers movidos aquí desde
    // SYSTEM, ver ADR 0035 — consistente con category=maintenance en
    // tools_catalog.sh)
    { name: 'System Updates', description: 'Actualización de los paquetes del sistema vía APT', script: 'scripts/system/install_system_update.sh', category: 'MAINTENANCE' },
    { name: 'Kernel & Headers', description: 'Gestión del kernel de Linux y sus headers (incluye HWE)', script: 'scripts/system/install_kernel.sh', category: 'MAINTENANCE' },
    { name: 'Final System Update', description: 'Actualización final y limpieza de paquetes huérfanos, al cierre del aprovisionamiento', script: 'scripts/maintenance/install_final_update.sh', category: 'MAINTENANCE' }
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
    const categories = ['SYSTEM', 'MULTIMEDIA', 'EDITORS', 'DEVELOPMENT', 'AI', 'PRODUCTIVITY', 'MAINTENANCE'];

    categories.forEach(category => {
        choices.push(new inquirer.Separator(`=== ${category} ===`));

        const categoryTools = toolsWithStatus.filter(t => t.category === category);
        categoryTools.forEach(tool => {
            const { icon, text } = STATUS_LABELS[tool.status];

            const descriptionSuffix = tool.description ? ` — ${tool.description}` : '';
            choices.push({
                name: `${icon} ${tool.name} (${text})${descriptionSuffix}`,
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
