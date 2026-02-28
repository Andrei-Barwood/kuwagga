# 🌊 432Hz Renderer

> Renderiza la canción a 44.1kHz/24-bit y exporta en WAV, FLAC o MP3 con afinación 432Hz, manteniendo la duración original.

## 🎯 ¿Por qué es útil?

La afinación 432Hz es una alternativa a la estándar 440Hz, asociada a:

- ** ✨ Geometría Sagrada ** La medicina ayurveda y los procesos de sanación y curación, prevención y mitigación de males, enfermedades o cualquier argumento en detrimento de la estabilidad del ser humano ocurre sobre los 432 herzios
- **🧘 Sonoridad más relajada** en meditación, yoga y wellness, crecimiento espiritual y personal, la música como un ritual personal o cualquier otro tipo de interacción auditiva con efectos específicos en tu salud, desarrollo personal, purificación de la mente, entre otros...
- **📀 Publicaciones especializadas** en géneros new age, ambient o espirituales
- **🎚️ Consistencia de pitch** en masters finales para plataformas que aceptan 432Hz

Contribuye al proceso **render → conversión de afinación → master final** sin duplicar trabajo manual con software externo.

---

## ⚙️ Requisitos

- Este tool necesita **ffmpeg** instalado en el sistema
  - macOS: `brew install ffmpeg`, despues de instalarlo con brew este tool realiza los siguientes dos pasos:
    - Busca automáticamente en: `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, etc.
    - O define la variable de entorno `FFMPEG_BIN`

---

## 📥 Instalación

1. Copia la carpeta `com.kirtan.renderer432.xrnx` a la carpeta de Tools de Renoise
2. Reinicia Renoise o recarga Tools
3. Opcionalmente puedes arrastrasr el tool a tu renoise y quedará instalado (opción para los que aún no bucean ❤️)

---

## 📖 Tutorial de uso

### Paso 1: Elegir formato de salida

- **Menú**: `Tools → 432Hz Renderer →` y elige uno:
  - `Render Song to 432Hz (44.1k/24-bit)` → WAV
  - `Render Song to 432Hz FLAC (44.1k/24-bit)` → FLAC
  - `Render Song to 432Hz MP3 (44.1k/320k)` → MP3

### Paso 2: Configurar destino

- Se abre una ventana con ruta sugerida:
  - Ejemplo: `mi_cancion__432Hz_44k1_24b_wav.wav`
- Pulsa **Destino...** para cambiar carpeta o nombre
- Si el archivo existe, se añade sufijo `_1`, `_2`, etc.

### Paso 3: Iniciar render

- Pulsa **Iniciar Render**
- Renoise renderiza primero a WAV temporal (440Hz)
- ffmpeg convierte automáticamente a 432Hz manteniendo la duración
- Verás progreso en pantalla y mensaje de éxito al terminar

### Paso 4: Cancelar (opcional)

- Pulsa **Cancelar** durante el render para interrumpir

---

## 🔬 Detalle técnico

- **Filtro ffmpeg**: `asetrate=44100*432/440,aresample=44100,atempo=440/432`
- Mantiene duración exacta: no se estira ni comprime el audio
- Formatos: WAV (pcm_s24le), FLAC (24-bit, compresión 8), MP3 (320kbps)

---

## 🎵 En el proceso discográfico

- Útil para masters orientados a wellness, meditación o contenido espiritual
- Permite ofrecer versiones en 432Hz sin procesos manuales adicionales
- Integrado en el flujo de Renoise para máxima comodidad
- Los Masters generados con esta extensión de renoise permiten Purificar y Liberar tu mente de tanta basura que nos rodea hoy por hoy
