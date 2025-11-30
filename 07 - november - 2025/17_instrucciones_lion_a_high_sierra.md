# 🛠️ Scripts de Actualización Bash: Lion → High Sierra

## Legacy Update Kit (2 Scripts)


***

## 📝 Descripción

**Kit de 2 scripts bash** ejecutables **directamente en OS X Lion (10.7)** y **El Capitan (10.11)** para actualizar paso a paso hasta **macOS High Sierra (10.13)**.

- **`15_from_lion_to_el_capitan.sh`**: Lion → El Capitan (10.11)
- **`16_from_el_capitan_to_high_sierra.sh`**: El Capitan → High Sierra (10.13)

**Semi-automatizados**: Abren App Store (necesitas Apple ID), esperan tu confirmación y lanzan instalador con flags auto (`--agreetolicense --nointeraction`). Nivel **Básico** 
(solo bash nativo, sin dependencias).

***

## ✅ Requisitos

- **OS X Lion 10.7.5** (actualizado a último parche) para Script 1 🦁
- **El Capitan 10.11** (recién instalado) para Script 2 🏔️
- **Apple ID** válido en App Store 📱
- **20-30 GB libres** en disco 💾
- **Internet estable** (~5-10 GB por descarga) 📡
- **Backup** (Time Machine o copia externa) 🔐

***

## 🚀 Instrucciones Paso a Paso

### 🎯 Script 1: Lion → El Capitan

1. **En Lion**: Abre Terminal (`/Applications/Utilities/Terminal.app`).
2. Crea el script:

```bash
nano ~/update_lion_capitan.sh
```

    - Pega código del script > **Ctrl+O** > **Enter** > **Ctrl+X**.
3. Permisos:

```bash
chmod +x ~/update_lion_capitan.sh
```

4. Ejecuta:

```bash
cd ~ && sudo ./update_lion_capitan.sh
```

5. **Sigue prompts**:
    - App Store se abre → **Inicia sesión** → **Get**.
    - Espera descarga (~1h) → ENTER cuando veas app en `/Applications/`.
    - ¡Instalación auto! Reinicia (~30-60min).

### 🎯 Script 2: El Capitan → High Sierra

1. **Tras reinicio en El Capitan**: Repite pasos 1-4 con `update_capitan_highsierra.sh`.
2. Igual: App Store → Descarga (~1h) → ENTER → Auto-instala.
3. **Final**: High Sierra listo (convierte a APFS auto).

***

## 📊 Progreso Esperado

```
📥 Descargando desde App Store...
⏳ Pulsa ENTER cuando listo:
🚀 Iniciando instalación auto...
Installing: 10% → 50% → Verifying... ✅
```


***

## 🐛 Solución de Problemas

| 🔴 Problema | 🔍 Causa | ✅ Solución |
| :-- | :-- | :-- |
| App Store no abre | Link expirado | Safari > `support.apple.com/elcapitan` o `apps.apple.com high sierra`. |
| "Instalador no encontrado" | Descarga incompleta | Verifica `ls /Applications/Install*` > Redescarga. |
| Sin espacio | Disco lleno | `sudo du -sh ~/Library/* /var/* \| sort -hr \| head` > Borra caches. |
| Error licencia | Flags no soportados | Quita `--nointeraction` del script. |
| Reinicio loop | Instalación fallida | Boot Recovery (Cmd+R) > Reinstala desde ahí. |


***

## ⚠️ Advertencias

- **Apple ID requerido** (gratis, pero verifica región).
- **Tiempo total**: 3-5h + descargas. **¡Backup primero!**
- Si no tienes App Store: Usa USB booteables (kit anterior).
- **High Sierra = tope**: No más allá sin hacks.

***

## 📚 Referencias

- [Apple - Descargar macOS](https://support.apple.com/es-cl/102662)
- [MrMacintosh Legacy](https://mrmacintosh.com/how-to-download-macos-catalina-mojave-or-high-sierra-full-installers/)

***

## 👨‍💻 Autor

Kirtan Teg Singh (2025). **v1.0** Compatible bash Lion+.

## 🎯 ¡De Lion a la cumbre! ⛰️✨


