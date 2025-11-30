# 🦁 Bootable Legacy Maker: Lion → High Sierra  
## 14_upgrade_legacy_macs.sh

---

## 📝 Descripción
Este script en **bash** automatiza la creación de **dos USB booteables** esenciales para actualizar Macs antiguos (2009-2012) desde **OS X Lion (10.7)** hasta **macOS High 
Sierra (10.13)**. El proceso requiere un paso intermedio obligatorio por **OS X El Capitan (10.11) 🛣️🚘**.

El script gestiona la descarga de instaladores, el formateo de USBs y la creación de medios de arranque oficiales usando `createinstallmedia`.

**Nivel: Intermedio** 💻. Requiere 2 memorias USB y acceso a un Mac moderno para crear los instaladores.

---

## ✅ Requisitos
- **Mac Moderno** (Ventura/Sonoma/Sequoia) para ejecutar el script y descargar instaladores 🖥️
- **2 Memorias USB** de **16 GB o más** (serán borradas) 💾
- **Mac Antiguo (Target)** con OS X Lion (10.7.5) compatible con High Sierra (MacBook Pro/Air/iMac 2010+) 🦁
- **Internet** para descargar ~12 GB de instaladores 📡
- **Backup** de datos del Mac antiguo (Time Machine recomendado) 🔐

---

## 🚀 Instrucciones de Uso

### 1️⃣ Prepara el script
Copia el contenido en un archivo:
```bash
nano ~/bootable_macos_legacy.sh
```
- Pega el código del script.
- Guarda: **Ctrl+O**, **Enter**, **Ctrl+X**.
- Dale permisos:
```bash
chmod +x ~/bootable_macos_legacy.sh
```

### 2️⃣ Prepara tus USBs
- Conecta el **USB 1** (para El Capitan) al Mac moderno.
- Formatea como **Mac OS Plus (con registro)** y esquema **GUID** en Utilidad de Discos (opcional, el script lo pedirá).
- Ten listo el **USB 2** (para High Sierra).

### 3️⃣ Ejecuta el script (como root)
```bash
cd ~ && sudo ./bootable_macos_legacy.sh
```
- Ingresa tu contraseña de administrador.

### 4️⃣ Flujo del Script ⏳
1. **Detección USB**: Te pedirá seleccionar el volumen USB conectado.
2. **Descargas**: 
   - Abrirá la App Store/Navegador para descargar **El Capitan** y **High Sierra**.
   - Espera a que las apps aparezcan en `/Applications/` antes de presionar ENTER.
3. **Creación USB 1 (El Capitan)**: 
   - El script borrará el USB y copiará los archivos (~20-30 min).
4. **Cambio de USB**: 
   - Te pedirá expulsar USB 1 e insertar USB 2.
5. **Creación USB 2 (High Sierra)**: 
   - Repetirá el proceso (~20-30 min).

---

## 📋 Proceso de Instalación en el Mac Antiguo (Legacy)

Una vez creados los USBs, sigue este orden **ESTRICTO** en tu Mac con Lion:

### 1️⃣ Paso 1: Lion → El Capitan (10.11)
1. Apaga el Mac antiguo.
2. Inserta **USB 1 (El Capitan)**.
3. Enciende manteniendo pulsada la tecla **Option (Alt) ⌥**.
4. Selecciona el instalador USB "Install OS X El Capitan".
5. Instala El Capitan sobre tu disco actual (actualización) o borra disco (instalación limpia).
6. Configura lo mínimo tras el reinicio.

### 2️⃣ Paso 2: El Capitan → High Sierra (10.13)
1. Con El Capitan funcionando, apaga el Mac.
2. Inserta **USB 2 (High Sierra)**.
3. Enciende manteniendo pulsada **Option (Alt) ⌥**.
4. Selecciona "Install macOS High Sierra".
5. **Importante**: Al instalar, el sistema convertirá tu disco a **APFS** (normal en SSDs).
6. Completa la instalación.

---

## 🐛 Solución de Problemas

| 🔴 Problema | 🔍 Causa Probable | ✅ Solución |
|-------------|-------------------|-------------|
| "createinstallmedia not found" | Instalador incompleto (stub) | Descarga instaladores completos (~6GB) desde [MrMacintosh](https://mrmacintosh.com/) o App Store links 
directos. |
| Error "zsh: killed" | Permisos o SIP | Ejecuta siempre con `sudo`. Verifica que el USB esté montado en `/Volumes`. |
| Mac antiguo no bootea USB | Firmware desactualizado | Resetea PRAM (Cmd+Opt+P+R) al encender. Asegúrate que es modelo 2010+. |
| USB no aparece en Alt-Boot | Formato incorrecto | Vuelve a crear USB asegurando esquema **GUID Partition Map**. |

---

## ⚠️ Advertencias
- **Pérdida de Datos USB**: El script **BORRA COMPLETAMENTE** los USBs seleccionados. Verifica bien el nombre del volumen.
- **Tiempo**: Descargar y crear ambos USBs puede tomar **1-2 horas**. Ten paciencia.
- **Compatibilidad**: High Sierra es el tope para muchos Macs 2009-2011. No intentes Mojave/Catalina sin parches (OpenCore).

---

## 👨‍💻 Autor y Versión
Kirtan Teg Singh  
**Versión 1.0** (nov 2025)  
Fuentes oficiales: [Apple Support](https://support.apple.com/es-cl/101578)

---

## 🎯 ¡Ahora ve a revivir la Mac de tus amigos legacy! ♻️
