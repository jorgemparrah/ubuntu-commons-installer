# Post-Install Scripts

Este repositorio contiene scripts de instalación automatizada para configurar un sistema Ubuntu con todas las herramientas de desarrollo necesarias.

## Estructura

El proyecto está organizado en instaladores modulares por categorías:

### Scripts de Instalación por Categorías

#### **📁 `scripts/editors/`** - Editores de Código
- **`install_vscode.sh`** - Editor Visual Studio Code
- **`install_cursor.sh`** - Editor Cursor AI IDE
- **`install_vim.sh`** - Editor modal Vim

#### **📁 `scripts/development/`** - Herramientas de Desarrollo
- **`install_docker.sh`** - Plataforma de contenedores Docker
- **`install_nodejs.sh`** - Runtime de JavaScript Node.js con NVM
- **`install_yarn.sh`** - Gestor de paquetes Yarn
- **`install_postman.sh`** - Cliente API Postman
- **`install_dbeaver.sh`** - Cliente universal de base de datos DBeaver
- **`install_gitkraken.sh`** - Cliente Git visual GitKraken
- **`install_insomnia.sh`** - Cliente REST alternativo a Postman
- **`install_mongodb_compass.sh`** - GUI para MongoDB
- **`install_kubectl.sh`** - Cliente de línea de comandos para Kubernetes (via snap)

#### **📁 `scripts/system/`** - Herramientas del Sistema
- **`install_system_update.sh`** - Actualización del sistema
- **`install_kernel.sh`** - Kernel HWE y headers
- **`install_development_tools.sh`** - Herramientas básicas de desarrollo
- **`install_system_utils.sh`** - Utilidades del sistema
- **`install_multimedia.sh`** - Herramientas multimedia
- **`install_terminator.sh`** - Terminal con múltiples pestañas
- **`install_oh_my_zsh.sh`** - Framework para gestión de Zsh
- **`install_powerlevel10k.sh`** - Tema rápido para Zsh
- **`install_ranger.sh`** - Gestor de archivos en terminal
- **`install_cmatrix.sh`** - Efecto visual Matrix en terminal
- **`install_gimp.sh`** - Editor de imágenes GIMP (via snap)
- **`install_obs_studio.sh`** - Software de grabación y streaming (via snap)

#### **📁 `scripts/productivity/`** - Aplicaciones de Productividad
- **`install_ulauncher.sh`** - Lanzador de aplicaciones ULauncher
- **`install_chrome.sh`** - Navegador web Google Chrome
- **`install_spotify.sh`** - Música en streaming Spotify
- **`install_zoom.sh`** - Cliente de videoconferencia Zoom
- **`install_flameshot.sh`** - Herramienta de captura de pantalla con configuración de teclas

#### **📁 `scripts/maintenance/`** - Mantenimiento del Sistema
- **`install_final_update.sh`** - Actualización final del sistema

### Script Principal

- **`setup.sh`** - Script principal interactivo con interfaz de checkboxes

### Ventajas de la Organización por Carpetas

- **📂 Mantenimiento más fácil**: Encontrar scripts por categoría lógica
- **🔧 Escalabilidad**: Fácil agregar nuevos scripts en la categoría correcta
- **🎯 Claridad**: Estructura clara y profesional
- **♻️ Reutilización**: Puedes copiar carpetas completas a otros proyectos
- **👥 Colaboración**: Más fácil para equipos trabajar en categorías específicas
- **📋 Separación clara**: Actualizaciones y mantenimiento separados de instalaciones

## Estructura del Proyecto

```
post-install/
├── setup.sh              # Script principal (Bash)
├── setup.js              # Interfaz interactiva (Node.js)
├── package.json          # Dependencias de Node.js
├── README.md             # Documentación
└── scripts/
    ├── system/           # Herramientas del sistema
    ├── editors/          # Editores de código
    ├── development/      # Herramientas de desarrollo
    ├── productivity/     # Aplicaciones de productividad
    └── maintenance/      # Utilidades de mantenimiento
```

## Uso

### **Ejecución Simple:**
```bash
./setup.sh
```

### **Flujo de Ejecución:**

1. **📋 Introducción del Proyecto**
   - Mensaje informativo con explicación del proyecto
   - Características principales
   - Organización por categorías

2. **🔍 Validación de Dependencias Básicas**
   - Verificación automática de dependencias del sistema (sudo, apt, snapd, curl, wget)
   - Opción de instalación automática si faltan

3. **📦 Instalación de Node.js**
   - Verificación de Node.js
   - Instalación automática usando el script existente si es necesario
   - Configuración de dependencias de Node.js (inquirer, chalk)
   - Verificación de archivos permanentes (setup.js, package.json)

4. **🖥️ Interfaz Interactiva de Selección**
   - Menú con herramientas organizadas por categorías
   - Checkboxes para selección múltiple
   - Estado de instalación visible (✓ Instalado / ✗ No instalado)

5. **📊 Progreso de Instalación**
   - Ejecución de scripts de instalación seleccionados
   - Feedback en tiempo real
   - Resumen final de instalaciones exitosas y fallidas

El script te mostrará una interfaz híbrida que combina:

1. **Bash para validaciones** - Verificación de dependencias y configuración inicial
2. **Node.js para el menú** - Interfaz interactiva moderna y estable
3. **Scripts modulares** - Cada herramienta con funciones de status, install, uninstall, reinstall

### **Características de la Interfaz:**

- **✅ Sin parpadeo** - Interfaz completamente estable
- **✅ Navegación intuitiva** - Uso del teclado y checkboxes
- **✅ Estados visuales** - ✓/✗ para cada herramienta
- **✅ Categorías organizadas** - Separadores por grupos
- **✅ Confirmaciones** - Seguridad antes de ejecutar
- **✅ Progreso visual** - Feedback durante la instalación

### Estructura de Scripts Modulares

Cada script de instalación sigue una estructura estándar con 4 funciones principales:

#### **📋 Funciones de Cada Script:**

```bash
#!/bin/bash
# install_example.sh

TOOL_NAME="Example Tool"

# 1. Verificar estado actual
check_status() {
    if command -v example &> /dev/null; then
        echo "INSTALLED"
        return 0
    else
        echo "NOT_INSTALLED"
        return 1
    fi
}

# 2. Instalar herramienta
install_tool() {
    echo "Instalando $TOOL_NAME..."
    # Lógica de instalación
}

# 3. Desinstalar herramienta
uninstall_tool() {
    echo "Desinstalando $TOOL_NAME..."
    # Lógica de desinstalación
}

# 4. Reinstalar herramienta
reinstall_tool() {
    echo "Reinstalando $TOOL_NAME..."
    uninstall_tool
    install_tool
}

# Función principal
main() {
    case "$1" in
        "status") check_status ;;
        "install") install_tool ;;
        "uninstall") uninstall_tool ;;
        "reinstall") reinstall_tool ;;
        *) echo "Uso: $0 {status|install|uninstall|reinstall}" ;;
    esac
}

main "$@"
```

#### **🔧 Uso de Scripts Individuales:**

```bash
# Verificar estado
./scripts/editors/install_vscode.sh status

# Instalar
./scripts/editors/install_vscode.sh install

# Desinstalar
./scripts/editors/install_vscode.sh uninstall

# Reinstalar
./scripts/editors/install_vscode.sh reinstall
```

#### **📋 Scripts Modulares Implementados:**

Todos los scripts del proyecto ahora tienen la estructura modular estándar:

- **✅ System**: `install_system_update.sh`, `install_kernel.sh`, `install_development_tools.sh`, `install_system_utils.sh`, `install_multimedia.sh`, `install_terminator.sh`, `install_oh_my_zsh.sh`, `install_powerlevel10k.sh`, `install_ranger.sh`, `install_cmatrix.sh`, `install_gimp.sh`, `install_obs_studio.sh`
- **✅ Editors**: `install_vscode.sh`, `install_cursor.sh`, `install_vim.sh`
- **✅ Development**: `install_docker.sh`, `install_nodejs.sh`, `install_yarn.sh`, `install_postman.sh`, `install_dbeaver.sh`, `install_gitkraken.sh`, `install_insomnia.sh`, `install_mongodb_compass.sh`, `install_kubectl.sh`
- **✅ Productivity**: `install_ulauncher.sh`, `install_chrome.sh`, `install_spotify.sh`, `install_zoom.sh`, `install_flameshot.sh`
- **✅ Maintenance**: `install_final_update.sh`

### Organización por Categorías

Las herramientas están organizadas en las siguientes categorías:

#### **🖥️ SYSTEM**
- **System Updates**: Actualizaciones del sistema
- **Kernel & Headers**: Kernel y headers del sistema
- **Development Tools**: Herramientas básicas de desarrollo
- **System Utilities**: Utilidades del sistema
- **Multimedia Tools**: Herramientas multimedia
- **Terminator**: Terminal avanzado
- **Oh My Zsh**: Framework para Zsh
- **Powerlevel10k**: Tema para Oh My Zsh
- **Ranger**: Navegador de archivos en terminal
- **cmatrix**: Efecto visual de Matrix
- **GIMP**: Editor de imágenes
- **OBS Studio**: Software de grabación y streaming

#### **📝 EDITORS**
- **Visual Studio Code**: Editor de código de Microsoft
- **Cursor AI IDE**: Editor con IA integrada
- **Vim**: Editor de texto avanzado

#### **⚙️ DEVELOPMENT**
- **Docker**: Contenedores de aplicaciones
- **Node.js**: Runtime de JavaScript
- **Yarn**: Gestor de paquetes de Node.js
- **Postman**: Cliente para APIs
- **DBeaver**: Cliente universal de base de datos
- **GitKraken**: Cliente gráfico de Git
- **Insomnia**: Cliente para APIs REST
- **MongoDB Compass**: Cliente gráfico de MongoDB
- **kubectl**: Cliente de línea de comandos para Kubernetes

#### **🎯 PRODUCTIVITY**
- **ULauncher**: Lanzador de aplicaciones
- **Google Chrome**: Navegador web
- **Spotify**: Reproductor de música
- **Zoom**: Software de videoconferencia
- **Flameshot**: Herramienta de captura de pantalla

#### **🔧 MAINTENANCE**
- **Final System Update**: Actualización final del sistema

### Ejemplo de la Interfaz Híbrida

La nueva interfaz combina Bash y Node.js para una experiencia óptima:

#### **1. Mensaje de Introducción (Bash):**
```
╔══════════════════════════════════════════════════════════════════════════════╗
║                           🚀 POST-INSTALL SETUP 🚀                           ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  Este proyecto automatiza la instalación de herramientas esenciales para     ║
║  desarrolladores en sistemas Ubuntu/Debian. Incluye editores de código,      ║
║  herramientas de desarrollo, aplicaciones de productividad y utilidades      ║
║  del sistema.                                                                ║
║                                                                              ║
║  🎯 Características principales:                                             ║
║     • Instalación selectiva de herramientas                                  ║
║     • Interfaz moderna con categorías organizadas                            ║
║     • Detección automática de herramientas ya instaladas                     ║
║     • Instalación desatendida y segura                                       ║
║     • Scripts modulares y reutilizables                                      ║
║                                                                              ║
║  📁 Organización por categorías:                                             ║
║     • SYSTEM: Actualizaciones, kernel, utilidades del sistema                ║
║     • EDITORS: VS Code, Cursor AI, Vim                                       ║
║     • DEVELOPMENT: Docker, Node.js, herramientas de desarrollo               ║
║     • PRODUCTIVITY: Chrome, Spotify, Zoom, etc.                              ║
║     • MAINTENANCE: Actualizaciones finales del sistema                       ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

ℹ Presiona ENTER para continuar...
```

#### **2. Validación de Dependencias (Bash):**
- Verificación automática de dependencias básicas
- Instalación automática de Node.js si es necesario
- Configuración de dependencias de Node.js

#### **3. Menú Interactivo (Node.js):**
```
🚀 Post-Install Setup

? Selecciona las herramientas:
  === SYSTEM ===
  ☐ ✓ System Updates (Instalado)
  ☐ ✗ Kernel & Headers (No instalado)
  ☐ ✗ Development Tools (No instalado)
  ☐ ✗ System Utilities (No instalado)
  ☐ ✗ Multimedia Tools (No instalado)
  ☐ ✗ Terminator (No instalado)
  ☐ ✗ Oh My Zsh (No instalado)
  ☐ ✗ Powerlevel10k (No instalado)
  ☐ ✗ Ranger (No instalado)
  ☐ ✗ cmatrix (No instalado)
  ☐ ✗ GIMP (No instalado)
  ☐ ✗ OBS Studio (No instalado)
  
  === EDITORS ===
  ☐ ✗ Visual Studio Code (No instalado)
  ☐ ✓ Cursor AI IDE (Instalado)
  ☐ ✗ Vim (No instalado)
  
  === DEVELOPMENT ===
  ☐ ✗ Docker (No instalado)
  ☐ ✗ Yarn (No instalado)
  ☐ ✗ Postman (No instalado)
  ☐ ✗ DBeaver (No instalado)
  ☐ ✗ GitKraken (No instalado)
  ☐ ✗ Insomnia (No instalado)
  ☐ ✗ MongoDB Compass (No instalado)
  ☐ ✗ kubectl (No instalado)
  
  === PRODUCTIVITY ===
  ☐ ✗ ULauncher (No instalado)
  ☐ ✗ Google Chrome (No instalado)
  ☐ ✗ Spotify (No instalado)
  ☐ ✗ Zoom (No instalado)
  ☐ ✗ Flameshot (No instalado)
  
  === MAINTENANCE ===
  ☐ ✗ Final System Update (No instalado)

[↑/↓] Mover, [ESPACIO] Seleccionar, [ENTER] Confirmar
```

#### **4. Progreso de Instalación (Node.js):**
```
🚀 Ejecutando acciones...

📦 Instalando Visual Studio Code...
[Progreso de instalación...]
✅ Visual Studio Code completado

📦 Instalando Docker...
[Progreso de instalación...]
✅ Docker completado

🎉 ¡Instalación completada!
```

### Controles de la Interfaz

- **↑/↓ Flechas**: Navegar por las opciones
- **ESPACIO**: Marcar/desmarcar checkbox
- **ENTER**: Confirmar selección
- **A**: Seleccionar todas las herramientas
- **N**: Deseleccionar todas las herramientas
- **Q**: Salir sin instalar

### Solución de Problemas

Si la tecla ESPACIO no funciona para marcar/desmarcar:

1. **Usa la tecla 'X'** como alternativa
2. **Ejecuta el debug de teclas**: `./debug_keys.sh` para verificar qué teclas se detectan
3. **Prueba el test simple**: `./test_space.sh` para verificar la funcionalidad básica

### Opciones Especiales

- **A**: Selecciona automáticamente todas las herramientas
- **N**: Deselecciona todas las herramientas
- **Q**: Sale del programa sin instalar nada

## Características

- **🎯 Instalación Selectiva**: Todas las herramientas vienen desmarcadas por defecto. Selecciona solo las que necesites instalar.
- **🔄 Reinstalación Segura**: Puedes ejecutar el script múltiples veces sin problemas
- **📁 Organización Modular**: Scripts organizados por categorías en carpetas específicas
- **✅ Validaciones**: Cada script verifica si la herramienta ya está instalada antes de proceder
- **🖥️ Interfaz Híbrida Moderna**: Bash para validaciones + Node.js para menú interactivo
- **🚀 Instalación Desatendida**: Una vez seleccionadas, las herramientas se instalan automáticamente
- **📊 Categorías Organizadas**: Herramientas agrupadas por categorías (SYSTEM, EDITORS, DEVELOPMENT, PRODUCTIVITY, MAINTENANCE)
- **📋 Introducción Informativa**: Explicación clara del proyecto al inicio
- **🔍 Validación de Dependencias**: Verificación automática de dependencias del sistema
- **⚡ Instalación Automática**: Opción para instalar dependencias faltantes automáticamente
- **📊 Barra de Progreso**: Visualización del progreso de instalación en tiempo real
- **🔧 Scripts Modulares**: Cada herramienta tiene funciones de status, install, uninstall y reinstall
- **📁 Archivos Permanentes**: setup.js y package.json son parte del proyecto, no se crean dinámicamente

## Dependencias del Sistema

El script verifica automáticamente las siguientes dependencias del sistema:

### **Dependencias Principales:**
- **`sudo`**: Para ejecutar comandos con privilegios de administrador
- **`apt`**: Gestor de paquetes de Debian/Ubuntu
- **`snapd`**: Gestor de paquetes Snap
- **`curl`**: Para descargas de archivos
- **`wget`**: Para descargas de archivos
- **`nodejs`**: Runtime de JavaScript (se instala automáticamente si no está presente)
- **`npm`**: Gestor de paquetes de Node.js (se instala con Node.js)

### **Instalación Automática:**
Si alguna dependencia falta, el script:
1. **Detecta automáticamente** las dependencias faltantes
2. **Muestra una ventana** con la lista de lo que necesita instalarse
3. **Ofrece instalar automáticamente** las dependencias
4. **Proporciona comandos manuales** si prefieres instalarlas tú mismo

### **Instalación Manual (si es necesario):**
```bash
sudo apt update && sudo apt install sudo apt snapd curl wget
```

## Validaciones de Instalación

Cada script de instalación incluye validaciones inteligentes que:

- **Verifican si la herramienta ya está instalada** antes de proceder (solo para mostrar estado, no para saltar)
- **Muestran mensajes informativos** con colores (✓ verde para instalado, ! amarillo para instalando)
- **Permiten reinstalaciones** si seleccionas una herramienta ya instalada
- **Muestran información adicional** como versiones cuando están disponibles
- **Actualizan automáticamente** componentes como kernels cuando hay versiones más nuevas disponibles

### Ejemplos de Validación:

```bash
# Herramienta ya instalada
✓ ULauncher is already installed.

# Herramienta no instalada
! Zoom is not installed. Installing...

# Con información de versión
✓ Node.js is already installed.
Node version: v20.18.0
NPM version: 10.8.2

# Kernel con actualización automática
✓ HWE Kernel is installed.
ℹ Kernel is up to date.
```

## Herramientas Instaladas

### Editores de Código
- **Visual Studio Code** - Editor de código con extensiones
- **Cursor AI IDE** - Editor con IA integrada
- **Vim** - Editor modal potente para terminal

### Herramientas de Desarrollo
- **Docker** - Plataforma de contenedores
- **Node.js** - Runtime de JavaScript (con NVM para gestión de versiones)
- **Yarn** - Gestor de paquetes para Node.js
- **Postman** - Cliente API para testing y desarrollo
- **DBeaver** - Cliente universal de base de datos
- **GitKraken** - Cliente Git visual
- **Insomnia** - Cliente REST alternativo a Postman
- **MongoDB Compass** - GUI para MongoDB
- **kubectl** - Cliente de línea de comandos para Kubernetes (via snap)

### Herramientas del Sistema
- **Terminator** - Terminal con múltiples pestañas y división
- **Oh My Zsh** - Framework para gestión de Zsh
- **Powerlevel10k** - Tema rápido y flexible para Zsh
- **Ranger** - Gestor de archivos en terminal
- **cmatrix** - Efecto visual Matrix en terminal
- **GIMP** - Editor de imágenes (alternativa a Photoshop, via snap)
- **OBS Studio** - Software de grabación y streaming (via snap)

### Aplicaciones de Productividad
- **ULauncher** - Lanzador de aplicaciones rápido
- **Google Chrome** - Navegador web
- **Spotify** - Música en streaming
- **Zoom** - Cliente de videoconferencia
- **Flameshot** - Captura de pantalla (configurado con tecla Print)

## Ejemplo de Uso

```bash
$ ./setup.sh

=== Post-Install Setup ===
Select tools to install (use ↑↓ to navigate, SPACE to toggle, A for all, N for none, ENTER to confirm, Q to quit)

SYSTEM
> ☐ System Updates ✓ (installed)
  ☐ Kernel & Headers ✓ (installed)
  ☐ Development Tools ✓ (installed)
  ☐ System Utilities ✓ (installed)
  ☐ Multimedia Tools ✓ (installed)

PRODUCTIVITY
  ☐ ULauncher ✓ (installed)

EDITORS
  ☐ Visual Studio Code ✓ (installed)
  ☐ Cursor AI IDE ✓ (installed)
  ☐ Vim ✓ (installed)

DEVELOPMENT
  ☐ Docker ✓ (installed)
  ☐ Node.js ✓ (installed)
  ☐ Yarn ✓ (installed)
  ☐ Postman ✓ (installed)
  ☐ DBeaver ✓ (installed)
  ☐ GitKraken ✗ (not installed)
  ☐ Insomnia ✗ (not installed)
  ☐ MongoDB Compass ✓ (installed)
  ☐ kubectl ✗ (not installed)

SYSTEM
  ☐ Terminator ✗ (not installed)
  ☐ Oh My Zsh ✓ (installed)
  ☐ Powerlevel10k ✓ (installed)
  ☐ Ranger ✗ (not installed)
  ☐ cmatrix ✓ (installed)
  ☐ GIMP ✓ (installed)
  ☐ OBS Studio ✗ (not installed)

PRODUCTIVITY
  ☐ Google Chrome ✓ (installed)
  ☐ Spotify ✓ (installed)
  ☐ Zoom ✓ (installed)
  ☐ Flameshot ✓ (installed)

MAINTENANCE
  ☐ Final System Update ✓ (installed)

Controls: ↑↓ Navigate | SPACE Toggle | A Select All | N Select None | ENTER Confirm | Q Quit
```

## Notas Importantes

### Después de la Instalación

1. **Docker**: Es posible que necesites cerrar sesión y volver a iniciar para que los cambios de grupo surtan efecto
2. **Node.js**: Reinicia tu terminal o ejecuta `source ~/.bashrc` para que NVM funcione correctamente
3. **Cursor AI IDE**: Se puede encontrar en el menú de aplicaciones
4. **Flameshot**: Está configurado con la tecla Print para capturas de pantalla
5. **Oh My Zsh**: Reinicia tu terminal o ejecuta `source ~/.zshrc` para ver los cambios
6. **Powerlevel10k**: Ejecuta `p10k configure` para personalizar tu prompt

### Permisos

Todos los scripts se ejecutan con permisos de administrador (sudo) cuando es necesario. Asegúrate de tener permisos de administrador antes de ejecutar los scripts.

## Personalización

Cada script de instalación es independiente y puede ser modificado según tus necesidades específicas. Los scripts están diseñados para ser idempotentes, por lo que pueden ejecutarse múltiples veces sin causar problemas.

## Requisitos

- Ubuntu 22.04 LTS o superior
- Conexión a internet
- Permisos de administrador