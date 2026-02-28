# 🎹 Export Tracks to MIDI

> Exporta tracks seleccionadas a archivos MIDI individuales con numeración ordenada y alta resolución temporal (960 PPQ).

## 🎯 ¿Por qué es útil?

En producción discográfica, los stems MIDI de tu sesión multitrack son fundamentales para:

- **📜 Notación**: Llevar arreglos a MuseScore, Sibelius o Finale para editar tus partituras impresas
- **🔄 Re-arrangements**: Reutilizar material en otros DAWs o sesiones
- **🎛️ Colaboración**: Compartir datos de notas con productores que no usan Renoise
- **🕐 Masterización de tiempo**: Mantener alta precisión temporal (960 PPQ) para sincronía perfecta

Contribuye al flujo **arrangement → exportación → post-producción** sin perder información de notas, velocidades ni automatización de CC (volumen, pan, width).

---

## 📥 Instalación

1. Copia la carpeta `com.kirtan.exporttracksmidi.xrnx` a la carpeta de Tools de Renoise:
   - **macOS**: `~/Library/Preferences/Renoise/V3.5.*/Scripts/Tools/`
   - **Windows**: `%APPDATA%\Renoise\V3.5.*\Scripts\Tools\`
   - **Linux**: `~/.config/renoise/V3.5.*/Scripts/Tools/`
2. Reinicia Renoise o recarga Tools.
3. Opcionalmente puedes arrastrar el tool a renoise y quedará instalado y funcional de forma inmediata, útil sin aún no has aprendido a bucear por tu Finder

---

## 📖 Tutorial de uso

### Paso 1: Abrir la herramienta

- **Menú**: `Tools → Export Tracks to MIDI`
- **Atajo global**: Configurable en Renoise

### Paso 2: Seleccionar carpeta destino

El tool te pedirá una carpeta donde guardar los archivos MIDI. Por defecto sugiere la misma carpeta que tu `.xrns`.

### Paso 3: Seleccionar tracks

Se abre un diálogo con todas las tracks secuenciadoras. Puedes:

- ✅ Marcar/desmarcar tracks individuales
- ✅ Usar **"Seleccionar Todo"** para incluir todas

Solo se exportan tracks de tipo secuenciador (no sends ni master como tracks MIDI separadas).

### Paso 4: Exportar

- Pulsa **Exportar** para iniciar
- Verás una barra de progreso con opción de **Cancelar**
- Al terminar, verás la lista de archivos exportados y posibles errores

### Formato de salida

- Archivos: `01_NombreTrack.mid`, `02_OtraTrack.mid`, etc.
- Archivos: El nombre de cada archivo midi es el mismo del track, es decir si el 'track 1' se llama violin el midi no se llama `track_1.mid` se llama `violin.mid` asi que conviene organizar los midis en una carpeta aparte que se llame `Scores/canción_1/violin.mid` para evitar casos como el de un album con 9 canciones que fue hecho con instrumentación uniforme y no sabes a cual canción pertenece cual archivo .mid, organizar...
- Si el nombre ya existe, se añade sufijo `_01`, `_02`, etc.
- Cada MIDI incluye: notas, velocidades, CC (volume/pan/width) y tempo

---

## 🔧 Consejos para producción

- Exporta stems MIDI **antes** de mezcla final si vas a externalizar la masterización
- Los archivos son compatibles con la mayoría de software de notación y DAWs
- Útil para crear lead sheets o arreglos para músicos en vivo
- Ayudas a aumentar el Legado de la historia de la musica de tu planeta y cuando alguien quiera tocar tu obra no toca adivinar cuales serían las notas, se tiene la ciencia de la música en frente y es re fácil reproducir tu obra
