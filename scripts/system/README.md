# System Scripts

Esta carpeta contiene scripts para la instalación y configuración de herramientas básicas del sistema.

## Scripts Incluidos

- **`install_system_update.sh`** - Actualizaciones del sistema
- **`install_kernel.sh`** - Kernel y headers del sistema (con actualización automática)
- **`install_development_tools.sh`** - Agrupador delgado de 7 instaladores individuales (`install_wget.sh`, `install_curl.sh`, `install_git.sh`, `install_build_essential.sh`, `install_software_properties_common.sh`, `install_apt_transport_https.sh`, `install_gnupg2.sh`), ver [ADR 0031](../../docs/adr/0031-separar-instaladores-multi-paquete-en-agrupador-mas-individuales.md)
- **`install_system_utils.sh`** - Agrupador delgado de 3 instaladores individuales (`install_meld.sh`, `install_baobab.sh`, `install_gparted.sh`)
- **`install_multimedia.sh`** - Agrupador delgado de 4 instaladores individuales (`install_cheese.sh`, `install_v4l_utils.sh`, `install_ubuntu_restricted_extras.sh`, `install_vlc.sh`)

## Características

- ✅ Validaciones automáticas de instalación
- ✅ Actualización inteligente de kernels
- ✅ Instalación de herramientas esenciales del sistema
- ✅ Configuración de utilidades básicas
