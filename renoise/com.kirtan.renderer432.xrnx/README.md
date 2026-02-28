# Renoise 432Hz Renderer Tool

Tool de Renoise que:
1. Renderiza la canción base a WAV con `44.1kHz` y `24-bit`.
2. Convierte automáticamente la afinación de `440Hz` a `432Hz` con `ffmpeg`.
3. Exporta en:
   - `WAV` (`pcm_s24le`)
   - `FLAC` (`24-bit`, compresión nivel 8)
   - `MP3` (`44.1kHz`, `320kbps`)
4. Mantiene la duración del audio con el filtro:
   - `asetrate=44100*432/440,aresample=44100,atempo=440/432`

## Instalación

1. Copia la carpeta `com.kirtan.renderer432.xrnx` a tu carpeta de Tools de Renoise:
   - macOS: `~/Library/Preferences/Renoise/V3.5.*/Scripts/Tools/`
2. Reinicia Renoise o recarga tools.

## Uso

- Menú:
  - `Tools > 432Hz Renderer > Render Song to 432Hz (44.1k/24-bit)`
  - `Tools > 432Hz Renderer > Render Song to 432Hz FLAC (44.1k/24-bit)`
  - `Tools > 432Hz Renderer > Render Song to 432Hz MP3 (44.1k/320k)`
- Al ejecutar una opción se abre una ventana con:
  - selector de destino (`Destino...`) para elegir el archivo de salida,
  - botón `Iniciar Render`,
  - botón `Cancelar` para interrumpir el render en curso.
- Si no cambias la ruta, el tool propone un nombre automático.

Nombre de salida:
- `<songname>__432Hz_44k1_24b_wav.wav`
- `<songname>__432Hz_44k1_24b_flac.flac`
- `<songname>__432Hz_44k1_24b_mp3.mp3`
