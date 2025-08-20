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

## Uso

### Instalación Interactiva (Recomendado)

Para instalar herramientas de forma interactiva:

```bash
./setup.sh
```

El script te mostrará una interfaz moderna con checkboxes que te permitirá:

1. **Ver el estado actual** de todas las herramientas (instaladas o no) con ✓/✗
2. **Todas las herramientas vienen desmarcadas** - selecciona solo las que quieres instalar
3. **Navegar con flechas** arriba/abajo para seleccionar herramientas
4. **Marcar/desmarcar con ESPACIO** para seleccionar herramientas específicas
5. **Usar atajos de teclado** para selección rápida
6. **Confirmar con ENTER** para proceder con la instalación

### Controles de la Interfaz

- **↑/↓ Flechas**: Navegar por las opciones
- **ESPACIO o X**: Marcar/desmarcar checkbox
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

### Características del Setup

- ✅ **Interfaz visual moderna** con checkboxes y colores
- ✅ **Lista unificada** que muestra estado de instalación y selección en una sola vista
- ✅ **Todas las herramientas desmarcadas por defecto** - tú decides qué instalar
- ✅ **Detección automática** de herramientas ya instaladas (✓ installed / ✗ not installed)
- ✅ **Navegación intuitiva** con flechas del teclado
- ✅ **Validación previa** en cada script de instalación
- ✅ **Atajos de teclado** para selección rápida
- ✅ **Instalación desatendida** una vez seleccionadas las herramientas
- ✅ **Resumen de instalación** con herramientas exitosas y fallidas
- ✅ **Confirmación antes de instalar** para evitar instalaciones accidentales
- ✅ **Mensajes informativos** con colores y estado de instalación

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
Select tools to install (use 'x' or SPACE to toggle, ENTER to confirm, 'q' to quit):

=== Tool Selection ===
Use 'x' or SPACE to toggle selection, ENTER to confirm, 'a' to select all, 'n' to select none, 'q' to quit

> ☐ System Updates ✓ (installed)
  ☐ Kernel & Headers ✓ (installed)
  ☐ Development Tools ✓ (installed)
  ☐ System Utilities ✓ (installed)
  ☐ Multimedia Tools ✓ (installed)
  ☐ ULauncher ✓ (installed)
  ☐ Visual Studio Code ✓ (installed)
  ☐ Cursor AI IDE ✓ (installed)
  ☐ Vim ✓ (installed)
  ☐ Docker ✓ (installed)
  ☐ Node.js ✓ (installed)
  ☐ Yarn ✓ (installed)
  ☐ Postman ✓ (installed)
  ☐ DBeaver ✓ (installed)
  ☐ GitKraken ✗ (not installed)
  ☐ Insomnia ✗ (not installed)
  ☐ MongoDB Compass ✓ (installed)
  ☐ kubectl ✗ (not installed)
  ☐ Terminator ✗ (not installed)
  ☐ Oh My Zsh ✓ (installed)
  ☐ Powerlevel10k ✓ (installed)
  ☐ Ranger ✗ (not installed)
  ☐ cmatrix ✓ (installed)
  ☐ GIMP ✓ (installed)
  ☐ OBS Studio ✗ (not installed)
  ☐ Google Chrome ✓ (installed)
  ☐ Spotify ✓ (installed)
  ☐ Zoom ✓ (installed)
  ☐ Flameshot ✓ (installed)
  ☐ Final System Update ✓ (installed)
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