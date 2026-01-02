# 🍎 Instalador Automático de macOS Sequoia (v1.3)  
## 13_install_sequoia.sh

---

## 📝 Descripción
Este script en **zsh** descarga automáticamente la versión más reciente disponible de **macOS Sequoia (15.x)** usando el comando nativo `softwareupdate` de Apple. Está 
optimizado para **MacBook Air M2 con macOS Ventura (13.x)**, donde las listas automáticas fallan. Prueba múltiples versiones estables (15.3.2 → 15.1), verifica el instalador y 
lo abre directamente para una instalación limpia (con borrado de disco manual).

Prueba versiones en orden descendente hasta éxito. Tamaño: ~14-16 GB. ⏱️ Tiempo: 1-3 horas (depende de internet).

**Nivel: Básico-Intermedio** 💻. Solo Terminal y sudo; no instala nada extra.

---

## ✅ Requisitos
- **macOS Ventura (13.x) o superior** en Apple Silicon (M1/M2/M3/M4) 🖥️
- **Espacio libre**: Mínimo 25 GB en `/` (recomendado 50 GB; limpia con `sudo rm -rf ~/Library/Caches/*`) 💾
- **Internet estable** (WiFi cableado ideal; >50 Mbps) 📡
- **Backup completo** (Time Machine): ¡Obligatorio! Borrará datos si eliges instalación limpia 🔐
- Terminal.app (incluido en macOS) 🖲️

**❌ No compatible**: Intel Macs antiguos o macOS <13.

---

## 🚀 Instrucciones paso a paso

### 1️⃣ Guarda el script
Copia el contenido en un archivo:
```bash
nano ~/13_install_sequoia.sh
```
- Pega el contenido del script.
- Presiona: **Ctrl+O**, **Enter**, **Ctrl+X**.

### 2️⃣ Dale permisos de ejecución
```bash
chmod +x ~/13_install_sequoia.sh
```

### 3️⃣ Ejecuta como root (¡imprescindible! 👑)
```bash
cd ~ && sudo ./13_install_sequoia.sh
```
- Introduce tu **contraseña admin**.

### 4️⃣ Espera el proceso ⏳
```
Probando 15.3.2 con --verbose...
Scanning for 15.3.2 installer  📥
Installing: 2.0%  →  5.0%  →  10.0%  ✨
Verifying...  ✔️
¡Éxito! Instalador en /Applications/Install macOS Sequoia.app (~14GB descargados).
```
- Se abre `/Applications/Install macOS Sequoia.app` **automáticamente**.

### 5️⃣ Instalación limpia (opcional pero recomendada 💡)
El Mac **reinicia solo** al entorno de instalación:

- En pantalla: Abre **Utilidad de Discos** 🖥️
- Selecciona **"Apple SSD"** (o volumen principal)
- Haz clic en **Borrar** 🗑️
- Formato: **APFS** | Esquema: **GUID** | Nombre: **"Macintosh HD"**
- Haz clic en **Borrar** 🔴
- Sal de Utilidad de Discos
- Haz clic en **Instalar macOS Sequoia** 📦
- Elige el **volumen borrado**
- Continúa ▶️

---

## 📊 Monitoreo en tiempo real
Mientras corre, abre **nuevas terminales** (Cmd+T para nueva pestaña):

### 📈 Logs principales (progreso %)
```bash
sudo tail -f /var/log/install.log | grep -Ei "(softwareupdate|sequoia|progress|installer)"
```
**Resultado esperado**: Muestra "Installing: XX%" en tiempo real ✅

### 💾 Espacio en disco (cada 2 segundos)
```bash
watch -n 2 'df -h /Applications'
```
**Resultado esperado**: Muestra libres decrecer → ~14GB al final ⬇️

### ⚙️ Proceso específico
```bash
top -pid $(pgrep -f softwareupdate)
```
**Resultado esperado**: CPU/RAM en uso 📊

---

## 🐛 Solución de problemas

| 🔴 Problema | 🔍 Causa | ✅ Solución |
|-------------|---------|-----------|
| "Fallo en todas versiones" | Servidores Apple/versión no para Ventura | Usa GUI: System Settings > General > Software Update > "More..." > "Get macOS Sequoia" 🖱️ |
| Pausa en % (>30 min sin cambio) | Red lenta 🐌 | Verifica WiFi; cierra apps pesadas (Activity Monitor). Reinicia router si es necesario 🔄 |
| "No espacio" 💥 | SSD lleno (256GB ajustado) | `sudo du -sh /var/* \| sort -hr \| head`; borra caches/temp: `rm -rf ~/Library/Caches/*` 🗑️ |
| Script no abre app | Download parcial ⚠️ | `rm -rf /Applications/Install*` y reintenta 🔁 |
| En Recovery? 🆘 | Boot issues durante instalación | Usa Internet Recovery (Cmd+Opt+R) > Terminal: mismo script 📡 |

**📋 Logs completos**: Abre **Console.app** > **system.log** > busca "softwareupdate" 🔎

---

## ⚠️ Advertencias
- **Irreversible sin backup**: Borrado destruye datos completamente 🚨 (Haz Time Machine primero!)
- Solo **Sequoia** (15.x) — no Tahoe 26; evita en 8GB RAM por lag 🐌
- Ejecuta **conectado a corriente** (batería drena rápido durante 2-3h) 🔌
- **No interrumpas** el proceso (no cierres Terminal hasta "¡Éxito!")
- Si falla todo: Contacta [Apple Support](https://support.apple.com/es-cl/102662) 📞 o [MrMacintosh 
DB](https://mrmacintosh.com/macos-sequoia-full-installer-database-download-directly-from-apple/) 💻

---

## 📚 Referencias
- [Apple Support - Descargar e instalar macOS](https://support.apple.com/es-cl/102662)
- [MrMacintosh - Sequoia Full Installer DB](https://mrmacintosh.com/macos-sequoia-full-installer-database-download-directly-from-apple/)
- [Apple - Novedades en Sequoia](https://support.apple.com/es-cl/120283)

---

## 👨‍💻 Autor y versión
Kirtan Teg Singh - basado en documentación oficial de Apple.  
**Versión 1.3** (nov 2025)  
⚡ Última actualización: 2025-11-30

💡 **Tip**: Actualiza el array `versions=()` cuando Apple lance versiones nuevas de Sequoia.

---


