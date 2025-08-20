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

### **Ejecución Simple:**
```bash
./setup.sh
```

### **Flujo de Ejecución:**

1. **📋 Introducción del Proyecto**
   - Ventana informativa con explicación del proyecto
   - Características principales
   - Organización por categorías

2. **🔍 Validación de Dependencias**
   - Verificación automática de dependencias del sistema
   - Ventana de confirmación para instalación automática
   - Instrucciones manuales si es necesario

3. **🖥️ Interfaz GUI de Selección**
   - Ventana con lista de herramientas organizadas por categorías
   - Checkboxes para selección múltiple
   - Estado de instalación visible (✓ Instalado / ✗ No instalado)

4. **📊 Progreso de Instalación**
   - Barra de progreso en tiempo real
   - Ventana de progreso con detalles de cada instalación
   - Resumen final de instalaciones exitosas y fallidas

El script te mostrará una interfaz gráfica moderna que te permitirá:

1. **Ver el estado actual** de todas las herramientas (instaladas o no) con ✓/✗
2. **Todas las herramientas vienen desmarcadas** - selecciona solo las que quieres instalar
3. **Selección múltiple** con checkboxes en ventanas gráficas
4. **Navegación intuitiva** con el mouse
5. **Confirmación visual** antes de proceder con la instalación
6. **Ver categorías organizadas** en columnas separadas (SYSTEM, EDITORS, DEVELOPMENT, PRODUCTIVITY, MAINTENANCE)
7. **Barra de progreso** que muestra el avance de la instalación

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

### Ejemplo de la Interfaz GUI

La nueva interfaz utiliza ventanas gráficas modernas con zenity:

#### **1. Ventana de Introducción:**
- **Título**: "🚀 Post-Install Setup"
- **Contenido**: Explicación completa del proyecto
- **Tamaño**: 600x400 píxeles

#### **2. Ventana de Validación de Dependencias:**
- **Título**: "⚠️ Dependencias Faltantes"
- **Tipo**: Ventana de confirmación (Sí/No)
- **Contenido**: Lista de dependencias faltantes con opción de instalación automática

#### **3. Ventana de Selección de Herramientas:**
- **Título**: "🛠️ Seleccionar Herramientas para Instalar"
- **Tipo**: Lista con checkboxes
- **Columnas**: Seleccionar | Categoría | Herramienta | Estado
- **Tamaño**: 800x600 píxeles
- **Características**: Selección múltiple, categorías organizadas, estado de instalación visible

**Ejemplo visual:**
```
┌─ 🛠️ Seleccionar Herramientas para Instalar ─┐
│ Selecciona las herramientas que deseas instalar: │
├─────────────────────────────────────────────────┤
│ ☐ SYSTEM    System Updates        ✓ Instalado  │
│ ☐ SYSTEM    Kernel & Headers      ✗ No instalado│
│ ☐ EDITORS   Visual Studio Code    ✗ No instalado│
│ ☐ EDITORS   Cursor AI IDE         ✓ Instalado  │
│ ☐ DEVELOPMENT Docker              ✗ No instalado│
│ ☐ DEVELOPMENT Node.js              ✗ No instalado│
│ ☐ PRODUCTIVITY Google Chrome       ✗ No instalado│
│ ☐ PRODUCTIVITY Spotify             ✗ No instalado│
│ ...         ...                   ...          │
├─────────────────────────────────────────────────┤
│ [Cancelar] [OK]                                │
└─────────────────────────────────────────────────┘
```

#### **4. Ventana de Progreso:**
- **Título**: "🚀 Instalando Herramientas"
- **Tipo**: Barra de progreso
- **Características**: Progreso en tiempo real, texto descriptivo
- **Tamaño**: 500x200 píxeles

#### **5. Ventana de Resultados:**
- **Título**: "✅ Instalación Completada" o "⚠️ Instalación Parcial"
- **Tipo**: Información o advertencia
- **Contenido**: Resumen de instalaciones exitosas y fallidas

### Controles de la Interfaz GUI

- **Mouse**: Navegación intuitiva con clics
- **Checkboxes**: Marcar/desmarcar herramientas individuales
- **Botones**: Confirmar o cancelar acciones
- **Ventanas modales**: Interacción clara y directa
- **Barra de progreso**: Visualización del avance en tiempo real

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
- **🖥️ Interfaz GUI Moderna**: Interfaz gráfica con zenity, sin parpadeo y completamente estable
- **🚀 Instalación Desatendida**: Una vez seleccionadas, las herramientas se instalan automáticamente
- **📊 Categorías Organizadas**: Herramientas agrupadas por categorías (SYSTEM, EDITORS, DEVELOPMENT, PRODUCTIVITY, MAINTENANCE)
- **📋 Introducción Informativa**: Explicación clara del proyecto al inicio
- **🔍 Validación de Dependencias**: Verificación automática de dependencias del sistema
- **⚡ Instalación Automática**: Opción para instalar dependencias faltantes automáticamente
- **📊 Barra de Progreso**: Visualización del progreso de instalación en tiempo real

## Dependencias del Sistema

El script verifica automáticamente las siguientes dependencias del sistema:

### **Dependencias Principales:**
- **`zenity`**: Para la interfaz gráfica (se instala automáticamente si no está presente)
- **`sudo`**: Para ejecutar comandos con privilegios de administrador
- **`apt`**: Gestor de paquetes de Debian/Ubuntu
- **`snapd`**: Gestor de paquetes Snap

### **Instalación Automática:**
Si alguna dependencia falta, el script:
1. **Detecta automáticamente** las dependencias faltantes
2. **Muestra una ventana** con la lista de lo que necesita instalarse
3. **Ofrece instalar automáticamente** las dependencias
4. **Proporciona comandos manuales** si prefieres instalarlas tú mismo

### **Instalación Manual (si es necesario):**
```bash
sudo apt update && sudo apt install zenity sudo apt snapd
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