# 🛠️ Kuwagga - Colección de Herramientas y Scripts

Colección de scripts y herramientas para resolver problemas comunes que surgen cuando las sesiones de desarrollo interactúan demasiado con el sistema. Incluye múltiples scripts de fallback en zsh, Python y otros lenguajes.

## 📋 Tabla de Contenidos

- [Conversión de Audio/Video](#conversión-de-audiovideo)
- [Conversión de Documentos](#conversión-de-documentos)
- [Gestión y Monitoreo de Disco](#gestión-y-monitoreo-de-disco)
- [Monitoreo de Memoria](#monitoreo-de-memoria)
- [Herramientas de Sistema macOS](#herramientas-de-sistema-macos)
- [Recuperación de Datos](#recuperación-de-datos)
- [Herramientas Matemáticas/Educativas](#herramientas-matemáticaseducativas)
- [Herramientas de Git](#herramientas-de-git)
- [Build Scripts](#build-scripts)
- [Limpieza y Mantenimiento](#limpieza-y-mantenimiento)
- [Temas y Personalización](#temas-y-personalización)
- [Herramientas Varias](#herramientas-varias)

---

## 🎵 Conversión de Audio/Video

### Conversión M4A a MP4
**Ubicación:** `01 - 2025/08 - december - 2025/06_m4a_to_mp4.zsh`

Convierte archivos de audio M4A a MP4 (video con imagen estática) para subir a YouTube. Incluye modo interactivo con selección visual de carpetas usando ranger, soporte para múltiples archivos, y detección automática de terminal para colores.

**Características:**
- Conversión M4A → MP4 con imagen estática
- Modo interactivo y por línea de comandos
- Selección visual de carpetas con ranger
- Progreso animado y logging detallado
- Validación de archivos y manejo de errores

### Conversión WAV a M4A
**Ubicación:** `01 - 2025/06 - October - 2025/wav_to_m4a.zsh`

Convierte archivos WAV a M4A con compresión AAC de alta calidad.

### Conversión M4A a MP3
**Ubicación:** `01 - 2025/07 - november - 2025/12_m4a_to_mp3.zsh`

Convierte archivos M4A a formato MP3.

### Conversión FLAC a MP4
**Ubicación:** `01 - 2025/07 - november - 2025/10_flac_to_mp4_converter.zsh`

Convierte archivos FLAC a MP4.

### Gestión de Tags de Audio
**Ubicación:** `01 - 2025/08 - december - 2025/01_m4a_mp3_flac_tags.zsh`

Herramienta para gestionar metadatos (tags) de archivos de audio en formatos M4A, MP3 y FLAC.

### Generador de Templates de Tags
**Ubicación:** `01 - 2025/08 - december - 2025/02_tags_template_generator.zsh`

Genera plantillas para tags de audio.

### Agregar Imagen a MP3
**Ubicación:** `01 - 2025/07 - november - 2025/11_add_img_to_mp3.zsh`

Agrega imágenes de portada a archivos MP3.

---

## 📄 Conversión de Documentos

### Conversor Inteligente Markdown a PDF ⭐
**Ubicación:** `02 - 2026/01 - enero/02 - md_to_pdf_converter/`

Aplicación inteligente que selecciona automáticamente el mejor método de conversión disponible (WeasyPrint, Pandoc, md2pdf, ReportLab) según las características del documento y los métodos instalados.

**Características:**
- Selección automática del mejor método
- Modo interactivo con soporte para macOS Finder
- Análisis del documento (código, LaTeX, tablas, etc.)
- Fallback automático si un método falla
- Scripts individuales para cada método

**Uso:**
```bash
python md_to_pdf.py                    # Modo interactivo
python md_to_pdf.py documento.md       # Línea de comandos
```

### Conversor Wiki a PDF
**Ubicación:** `01 - 2025/08 - december - 2025/12_wiki_to_pdf.zsh`

Convierte listas de URLs de wikis (Fandom, etc.) a PDFs para lectura offline. Preserva imágenes y estilos tanto como sea posible.

**Uso:**
```bash
./12_wiki_to_pdf.zsh urls.txt [directorio_salida]
```

### Traductor de PDF
**Ubicación:** `01 - 2025/08 - december - 2025/13_translate_pdf/`

Herramienta para traducir archivos PDF a diferentes idiomas.

### Conversor HTML a PDF
**Ubicación:** `01 - 2025/07 - november - 2025/01 - HTML to PDF/`

Suite completa para convertir archivos HTML a PDF con múltiples métodos y configuraciones.

---

## 💾 Gestión y Monitoreo de Disco

### Disk Guard
**Ubicación:** `01 - 2025/08 - december - 2025/07_disk_guard.zsh`

Monitorea el espacio libre en disco y detecta caídas rápidas de espacio. Captura procesos que están escribiendo al sistema de archivos cuando se detecta una caída significativa.

**Características:**
- Monitoreo continuo del espacio libre
- Detección de caídas rápidas (>500MB en ~5 segundos)
- Captura de procesos escritores con `fs_usage`
- Análisis de snapshots de Time Machine
- Logging detallado de eventos

### Disk Guard Plus
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/02_disk_guard_plus.zsh`

Versión mejorada de Disk Guard con funcionalidades adicionales.

### Disk Guard Daemon
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/03_disk_guard_daemon.zsh`

Versión daemon de Disk Guard para ejecución en segundo plano.

### Disk Scanner
**Ubicación:** `01 - 2025/08 - december - 2025/08_disk_scanner.sh`

Escanea el disco en busca de directorios grandes y categoriza su seguridad para eliminación.

### Auditor de Disco macOS
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/04_auditor_disco_macos.zsh`

Audita el estado del disco en macOS.

### Registro de Espacio Libre
**Ubicación:** `01 - 2025/01 - Junio - 2025/30 de Junio - 2025/01_registro_espacio_libre.zsh`

Registra el espacio libre en disco a lo largo del tiempo.

### Rastreador de Cambios en Disco
**Ubicación:** `01 - 2025/01 - Junio - 2025/30 de Junio - 2025/02_rastreador_cambios_disco.zsh`

Rastrea cambios en el uso del disco.

### Vigía de Escritura Física
**Ubicación:** `01 - 2025/01 - Junio - 2025/30 de Junio - 2025/03_vigia_escritura_fisica.zsh`

Monitorea escrituras físicas al disco.

### Informe de Volúmenes
**Ubicación:** `01 - 2025/01 - Junio - 2025/30 de Junio - 2025/04_informe_volumenes.zsh`

Genera informes sobre los volúmenes del sistema.

### Bloqueo de Indexado de Volúmenes
**Ubicación:** `01 - 2025/01 - Junio - 2025/30 de Junio - 2025/05_bloqueo_indexado_volumenes.zsh`

Bloquea el indexado de Spotlight en volúmenes específicos.

### Stop the Bleeding
**Ubicación:** `01 - 2025/08 - december - 2025/09_stop_the_bleeding.sh`

Script de emergencia para detener procesos que están consumiendo espacio en disco rápidamente.

---

## 🧠 Monitoreo de Memoria

### Memory Pressure Monitor
**Ubicación:** `01 - 2025/05 - September 2025/memory_pressure_monitor.zsh`

Monitorea la presión de memoria del sistema y envía notificaciones cuando la memoria libre cae por debajo de un umbral (20% por defecto).

### Memory Pressure Monitor con Notificaciones Avanzadas
**Ubicación:** `01 - 2025/05 - September 2025/memory_pressure_monitor_advanced_notification_features.zsh`

Versión con características avanzadas de notificaciones.

### Memory Pressure Monitor con Notification Center
**Ubicación:** `01 - 2025/05 - September 2025/memory_pressure_monitor_notification_center.zsh`

Integración con Notification Center de macOS.

### Memory Pressure Monitor con Cron
**Ubicación:** `01 - 2025/05 - September 2025/memory_pressure_monitor_with_cron.zsh`

Versión configurada para ejecutarse automáticamente con cron.

### Memory Pressure Simulator
**Ubicación:** `01 - 2025/05 - September 2025/memory_pressure_simulator.zsh`

Simula presión de memoria para pruebas.

---

## 🍎 Herramientas de Sistema macOS

### Restaurar desde Papelera
**Ubicación:** `01 - 2025/04 - August - 2025/01 - put back from trash.zsh`

Recupera archivos de la papelera usando fzf para búsqueda interactiva. Mueve los archivos seleccionados a `~/Desktop/recovered`.

### Restaurar Preview
**Ubicación:** `01 - 2025/04 - August - 2025/02 - restore preview.zsh`

Restaura la aplicación Preview de macOS.

### Deshacer Commit de Git
**Ubicación:** `01 - 2025/04 - August - 2025/03 - undo git commit.zsh`

Deshace el último commit de Git de forma segura.

### Detener Descargas Automáticas de iCloud
**Ubicación:** `01 - 2025/04 - August - 2025/04 - stop icloud automatic downloads.zsh`

Detiene las descargas automáticas de iCloud.

### Limpiar Cryptex
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/05_limpiar_cryptex.zsh`

Limpia archivos cryptex del sistema.

### Revisar Purgeable en Finder
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/06_revisar_purgeable_finder.zsh`

Revisa el espacio purgeable visible en Finder.

### Bloquear Tethering Riesgoso
**Ubicación:** `01 - 2025/01 - Junio - 2025/19 de junio - 2025/07_bloquear_tethering_riesgoso.zsh`

Bloquea configuraciones de tethering que pueden ser riesgosas.

### Desinstalar CleanMyMac
**Ubicación:** `01 - 2025/01 - Junio - 2025/29 de junio - 2025/01_uninstall_cleanmymac.zsh`

Desinstala completamente CleanMyMac del sistema.

### Liberar Snapshot
**Ubicación:** `01 - 2025/01 - Junio - 2025/29 de junio - 2025/02_liberar_snapshot.zsh`

Libera snapshots de Time Machine.

### Eliminar Residuos del Instalador de macOS
**Ubicación:** `01 - 2025/08 - december - 2025/10_remove_macOS_installer_leftovers.sh`

Elimina archivos residuales dejados por el instalador de macOS (típicamente 5-15GB).

### Upgrade de Macs Legacy
**Ubicación:** `01 - 2025/07 - november - 2025/14_upgrade_legacy_macs.sh`

Scripts para actualizar Macs antiguos:
- `15_from_lion_to_el_capitan.sh` - De Lion a El Capitan
- `16_from_el_capitan_to_high_sierra.sh` - De El Capitan a High Sierra
- `14_upgrade_legacy_macs.sh` - Upgrade general

### Instalación de Sequoia
**Ubicación:** `01 - 2025/07 - november - 2025/13_install_sequoia.sh`

Script para instalar macOS Sequoia con instrucciones detalladas.

---

## 🔄 Recuperación de Datos

### Data Recovery (Android/iPhone)
**Ubicación:** `01 - 2025/07 - november - 2025/01_data_recovery.py`

Herramienta de backup y recuperación rápida para dispositivos Android (ADB) e iPhone (idevicebackup2). Incluye compresión con 7-Zip.

**Características:**
- Backup de Android vía ADB
- Backup de iPhone vía idevicebackup2
- Compresión automática con 7-Zip
- Backup de carpetas comunes (DCIM, Pictures, Movies, Music, Download, Documents)

### Data Recovery Installer
**Ubicación:** `01 - 2025/07 - november - 2025/02_data_recovery_installer.py`

Instalador para las herramientas de recuperación de datos.

---

## 📐 Herramientas Matemáticas/Educativas

### Teoría de Conjuntos
**Ubicación:** `01 - 2025/07 - november - 2025/05_teoria_de_conjuntos.py`

Visualización de intervalos y teoría de conjuntos con matplotlib.

### Complemento de un Conjunto
**Ubicación:** `01 - 2025/07 - november - 2025/06_el_complemento_de_un_conjunto.py`

Operaciones con complementos de conjuntos.

### Unión de Conjuntos
**Ubicación:** `01 - 2025/07 - november - 2025/07_union_de_conjuntos.py`

Operaciones de unión de conjuntos.

### Intersección de Conjuntos
**Ubicación:** `01 - 2025/07 - november - 2025/08_interseccion_de_conjuntos.py`

Operaciones de intersección de conjuntos.

### Disyunción, Diferencia y Diferencia Simétrica
**Ubicación:** `01 - 2025/07 - november - 2025/09_disyuncion_diferencia_y_diferencia_simetrica.py`

Operaciones avanzadas de conjuntos.

### Tabla PT100
**Ubicación:** `01 - 2025/07 - november - 2025/04_tabla_pt100.py`

Herramienta para trabajar con tablas de resistencia PT100 (sensores de temperatura).

### Funciones Trigonométricas
**Ubicación:** `aemaeth/01_trig_func.py`

Herramientas para funciones trigonométricas.

---

## 🔧 Herramientas de Git

### Observar Cambios en Commits
**Ubicación:** `01 - 2025/07 - november - 2025/18_observar_cambios_en_commits.sh`

Observa y analiza cambios en commits de Git.

### Reducir Tamaño del Repositorio Git
**Ubicación:** `02 - 2026/01 - enero/01 - reduce git repo size/`

Herramientas para limpiar y reducir el tamaño del historial de Git:
- `clean-git-history.sh` - Limpia el historial de Git
- `CLEAN-GIT-HISTORY-README.md` - Documentación

---

## 🏗️ Build Scripts

### Build Scripts para Flint
**Ubicación:** `01 - 2025/05 - September 2025/`

Scripts para compilar el proyecto Flint con diferentes configuraciones:
- `01_build_flint_w_dep.zsh` - Build básico con dependencias
- `02_build_flint_w_dep_http2_framing.zsh` - Con HTTP/2 framing
- `03_build_flint_w_dep_http2_framing_mac_os_only.zsh` - Solo macOS
- `04-11_build_flint_w_dep_http2_framing_apple_silicon_only.zsh` - Varias versiones para Apple Silicon
- `12_fix_framework_symlinks.zsh` - Corregir symlinks de frameworks

---

## 🧹 Limpieza y Mantenimiento

### Hunter
**Ubicación:** `01 - 2025/08 - december - 2025/11_hunter.zsh`

Herramienta para buscar y limpiar directorios grandes. Categoriza directorios por seguridad de eliminación y proporciona información detallada.

**Características:**
- Búsqueda de directorios grandes
- Categorización automática (SAFE/WARNING)
- Análisis de seguridad antes de eliminar
- Soporte para múltiples selecciones

### Desinstalar Bassmaster/Loopmasters
**Ubicación:** `01 - 2025/08 - december - 2025/05_uninstall_bassmaster_loopmasters.zsh`

Desinstala completamente las aplicaciones Bassmaster y Loopmasters.

### Renombrar Imágenes
**Ubicación:** `01 - 2025/07 - november - 2025/03_renombrar_imagenes.zsh`

Renombra imágenes en lote según patrones específicos.

### Desinstalador de Apps
**Ubicación:** `01 - 2025/02 - Julio - 2025/01 - 6 de Julio/01_desinstalador_de_apps.zsh`

Desinstala aplicaciones de macOS de forma completa.

### Eliminar Duplicados
**Ubicación:** `01 - 2025/02 - Julio - 2025/01 - 6 de Julio/02_eliminar_duplicados.zsh`

Encuentra y elimina archivos duplicados.

### Buscador de Archivos y Directorios
**Ubicación:** `01 - 2025/02 - Julio - 2025/05 - 21 de Julio/01 - Directory Finder.zsh`

Herramienta para buscar archivos y directorios.

### Buscador de Archivos
**Ubicación:** `01 - 2025/02 - Julio - 2025/06 - 22 de Julio/01_file_and_dirs_finder.zsh`

Buscador avanzado de archivos y directorios.

---

## 🎨 Temas y Personalización

### Tank Theme
**Ubicación:** `01 - 2025/08 - december - 2025/install_tank_theme.zsh`

Instala el tema "Tank" para terminal.

**Archivos relacionados:**
- `tank_theme_installer.swift` - Instalador Swift
- `test_tank_colors.zsh` - Prueba de colores

---

## 🔧 Herramientas Varias

### Setup Project
**Ubicación:** `01 - 2025/07 - november - 2025/setup_project.zsh`

Script de configuración inicial para proyectos.

### Feed Firebase Rule
**Ubicación:** `01 - 2025/06 - October - 2025/feed-firebase-rule.js`

Reglas de Firebase para feeds.

### Convertir AutoCAD a AutoLISP
**Ubicación:** `01 - 2025/08 - december - 2025/04_convertir_autocad_a_autolisp.lsp`

Convierte archivos de AutoCAD a AutoLISP.

### Plantilla AutoCAD RIC-18
**Ubicación:** `01 - 2025/08 - december - 2025/03_autocad_RIC-18_diagrama_unilineal_plantilla.lsp`

Plantilla para diagramas unilineales en AutoCAD.

### Limpiar Buffers de Renoise
**Ubicación:** `renoise/01_clear_all_buffers.lua`

Script Lua para Renoise que limpia todos los buffers.

### Patches
**Ubicación:** `patches/`

Colección de patches para varios componentes del sistema:
- BSD
- PrivacySettingsFramework
- Settings
- WebKit
- Tests

---

## 📝 Notas

- La mayoría de los scripts están diseñados para macOS
- Muchos scripts requieren permisos de administrador (sudo)
- Algunos scripts requieren herramientas adicionales instaladas (ffmpeg, ranger, fzf, etc.)
- Los scripts están organizados cronológicamente por fecha de creación
- Se recomienda revisar cada script antes de ejecutarlo para entender su funcionamiento

---

## ⚠️ Advertencia

Estos scripts están diseñados para resolver problemas específicos que surgen durante el desarrollo. Úsalos con precaución y asegúrate de entender qué hace cada script antes de ejecutarlo. Algunos scripts pueden modificar el sistema o eliminar archivos.

---

## 📅 Estructura del Repositorio

El repositorio está organizado por año y mes:
- `01 - 2025/` - Scripts creados en 2025
- `02 - 2026/` - Scripts creados en 2026
- `patches/` - Patches del sistema
- `renoise/` - Scripts para Renoise
- `aemaeth/` - Herramientas matemáticas

---

**Última actualización:** Enero 2026
