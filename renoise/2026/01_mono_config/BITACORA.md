# BITÁCORA DE DESARROLLO
## lurssen-mono-breakcore

**Proyecto:** Batch processor profesional para convertir discografías completas a **mono verdadero 48 kHz M4A o WAV** usando el carácter del **Lurssen Mastering Console** (IK Multimedia / T-RackS).

**Fecha de esta entrada:** 2026-07-30  
**Estado actual:** ✅ **FUNCIONA PERFECTO** (export M4A + WAV)

**Archivos principales del proyecto (estado actual):**
- `lurssen_mono_breakcore.py` — El script principal (todo el conocimiento está aquí)
- `README.md`
- `BITACORA.md` (este archivo)
- `config.example.yaml` / `config.yaml`
- `requirements.txt`
- `pyproject.toml`

**Funciones clave para navegar el código:**
- `main()` — Orquestación + parseo de argumentos + sanitización de paths
- `run_interactive_mode()` + `show_summary()`
- `process_single_file()` — Worker top-level para multiprocessing
- `process_with_lurssen()` + `_ensure_pcm_wav_for_pedalboard()`
- `process_with_ffmpeg_emulation()` + `encode_processed_wav()` (+ wrapper `encode_processed_wav_to_m4a`)
- `normalize_output_format()` / `normalize_wav_bit_depth()` / `output_extension()` / `wav_pcm_codec()`
- `apply_breakcore_preset()`
- `_sanitize_user_path()` — **La función más importante para paths**
- `find_audio_files()` + `compute_output_path()`
- `load_config()` + `resolve_value()`
- `find_lurssen_plugin()` + `show_plugin_info()`

> **Declaración importante:** A fecha de hoy el script está estable, robusto y en producción. Todas las funcionalidades principales han sido probadas y resuelven los problemas reales del flujo de trabajo del usuario (especialmente rutas en volúmenes externos y soporte amplio de formatos).

---

## 1. Resumen Ejecutivo

Herramienta CLI + menú interactivo para procesar grandes bibliotecas de música (breakcore / electrónica agresiva) aplicando:

- Procesamiento a través del plugin **Lurssen Mastering Console** (o Lurssen Mastering EQ v6) vía `pedalboard`.
- Fallback de alta calidad usando una cadena de filtros `ffmpeg` cuidadosamente afinada.
- Salida: **mono 48 kHz** en **M4A (AAC 256k/320k)** o **WAV (PCM 16/24-bit)**, con preservación de estructura de carpetas y metadatos (cuando el contenedor lo permite).
- Filosofía breakcore: **sin normalización fuerte de loudness por defecto**, énfasis en punch, pegamento y claridad en mono.

---

## 2. Estado Actual (2026-07-08)

### Lo que funciona perfectamente:
- Menú interactivo completo y amigable (`-I` o sin argumentos).
- Detección automática de plugin Lurssen.
- Aplicación de perfiles recomendados + ajuste fino.
- Procesamiento paralelo (multiprocessing seguro).
- Rutas en volúmenes externos (`/Volumes/...`) sin problemas.
- Soporte de **MP3** como entrada (decodificación transparente).
- Manejo robusto de paths con comillas (copy-paste típico del usuario).
- Dos caminos de procesamiento completamente funcionales.
- Preservación de metadatos + estructura de carpetas.
- Dry-run, verbose, inspección de parámetros del plugin.
- Guardar/cargar configuración YAML.

### Limitaciones conocidas (aceptadas):
- Solo macOS (porque usa Audio Units).
- Requiere que el plugin Lurssen esté autorizado en T-RackS.
- El procesamiento con plugin es stateful → se usa chunking de ~3 segundos.
- Salida siempre resampleada a 48 kHz (decisión de diseño).

---

## 3. Arquitectura Principal

### Flujo general

```
Input (cualquier formato soportado)
        │
        ▼
find_audio_files() → lista ordenada
        │
        ▼
Para cada archivo:
    ┌─────────────────────────────┐
    │  ¿use_plugin && plugin?     │
    └───────────────┬─────────────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  process_with_lurssen()   process_with_ffmpeg_emulation()
         │                     │
         ▼                     ▼
  temp mono WAV (si plugin)   salida directa .m4a
         │
         ▼
  encode_processed_wav_to_m4a()  (ffmpeg + metadatos del original)
         │
         ▼
  Output: carpeta espejo + nombre + sufijo + .m4a
```

### Los dos caminos de procesamiento

**1. Camino Plugin (preferido)**
- `pedalboard.load_plugin(plugin_path)`
- `apply_breakcore_preset()` (mapeo defensivo de parámetros)
- Lectura chunked con `AudioFile`
- **Colapso verdadero a mono**: `np.mean(processed, axis=0, keepdims=True)`
- Escribe WAV temporal mono (mantiene sr original del archivo)
- Luego `encode_processed_wav_to_m4a()` → fuerza 48 kHz + alimiter/loudnorm + metadatos

**2. Camino Emulación (sin plugin)**
- Todo en un solo pase de ffmpeg:
  - Filtros afinados (drive, EQs estratégicos, compresión ligera, presencia)
  - Opcional loudnorm
  - Salida directa a m4a mono 48 kHz

### Manejo de archivos temporales
- Ubicación: `/tmp/lurssen_mono_breakcore/`
- Prefijos:
  - `proc_*.wav` → resultado del procesamiento con plugin
  - `decode_*.wav` → decodificación intermedia de mp3/m4a para pedalboard
- Limpieza:
  - El worker (`process_single_file`) limpia el `temp_wav` en `finally`.
  - `_ensure_pcm_wav_for_pedalboard` devuelve el archivo a limpiar.
  - `process_with_lurssen` tiene `finally` para limpiar decodificados.

### Colapso a Mono (crítico para breakcore)
```python
if processed.shape[0] > 1:
    processed = np.mean(processed, axis=0, keepdims=True).astype(np.float32)
```
Esto es intencional y no debe cambiarse sin discusión.

---

## 4. Manejo de Rutas — La Lección Más Importante

### Bug histórico (resuelto)
El usuario reportó que al poner rutas de volúmenes externos aparecían así:

```
/Users/andreibarwood/kuwagga/renoise/2026/01_mono_config/'/Volumes/The_DollMaker/...'
```

**Causa raíz:**
- El usuario pegaba rutas con comillas (`'/Volumes/...'`) por costumbre de shell/Finder.
- `Path("'/Volumes/...'").resolve()` → al no empezar con `/`, se resolvía relativo al CWD del repo.

### Solución implementada: `_sanitize_user_path()`

Ubicación: cerca del principio del archivo.

Comportamiento:
1. Strip de whitespace.
2. Eliminación repetida de comillas exteriores `'` o `"`.
3. **Recovery**: si después de limpiar aún hay comillas internas (ej. rutas ya envenenadas), usa regex para extraer la primera ruta absoluta que empiece por `/Volumes/`, `/Users/`, etc.

**Se aplica en TODOS los puntos de entrada:**
- Argumentos CLI (después de `parse_args()`)
- `_prompt_path()` (tanto questionary como fallback)
- `run_interactive_mode` (inicialización y carga YAML)
- `load_config()`
- `find_lurssen_plugin()`
- `configure_plugin_path()`
- Resolución final de `input_root` / `output_root`

**Recomendación para el futuro:** Nunca asumir que un path que viene del usuario es limpio. Siempre pasar por `_sanitize_user_path()`.

---

## 5. Soporte de Formatos de Entrada

```python
SUPPORTED_EXTS = {".wav", ".wave", ".aiff", ".aif", ".flac", ".m4a", ".mp3", ".opus"}
```

### Estrategia de decodificación (agregada con MP3)

```python
def _ensure_pcm_wav_for_pedalboard(input_path: Path) -> Tuple[Path, Optional[Path]]:
```

- Formatos "nativos confiables" (wav, aiff, flac) → se pasan directo a `AudioFile`.
- Todo lo demás (`.mp3`, `.m4a`, `.opus`, etc.) → se decodifica con ffmpeg a `pcm_f32le` en un WAV temporal.
- El temporal se limpia automáticamente.

Esto hace que agregar nuevos formatos sea trivial: solo añadir la extensión a `SUPPORTED_EXTS`.

**Nota:** El camino de emulación ffmpeg siempre funcionó con cualquier cosa que ffmpeg soporte (incl. Opus).

---

## 6. Sistema de Configuración y Precedencia

Función clave: `resolve_value(cli_val, config_val, default)`

Orden de precedencia (más alto primero):
1. Valores pasados por CLI
2. Valores que vienen del menú interactivo (se inyectan como si fueran CLI)
3. `config.yaml` (o el archivo pasado con `-c`)
4. Defaults internos (`BREAKCORE_DEFAULTS`, etc.)

El menú interactivo puede cargar y guardar `config.yaml`.

El archivo `config.yaml` actual puede ser:
- YAML completo con todas las claves, o
- Legacy: una sola línea con el path del plugin (string puro).

---

## 7. Menú Interactivo (UX principal)

Se lanza automáticamente si no se proveen `-i` y `-o`.

Características destacadas:
- `show_summary()` en cada iteración (muy útil para el usuario).
- Perfiles preconstruidos (`INTERACTIVE_PROFILES`).
- Flujo de "Custom values".
- Opciones de loudness con explicaciones breakcore.
- Preview / dry-run desde el menú.
- Herramientas de plugin (`--show-plugin-params` también disponible por CLI).

---

## 8. Aplicación de Parámetros del Plugin

Función: `apply_breakcore_preset()`

Es **muy defensiva**:
- Busca por nombre en minúsculas.
- Múltiples candidatos por parámetro (`"input drive"`, `"drive"`, `"inputdrive"`, etc.).
- Casos especiales para Lurssen Mastering EQ v6 (T-RackS):
  - `gain_3_lm`, `gain_3_rs`, `gain_4_lm`, etc.
  - Mapeo de "presence" a las bandas de EQ.
  - Uso de `color`/`saturation` derivado de `input_drive`.

Si no encuentra parámetros, igual aplica preset si está disponible y continúa.

---

## 9. Detalles de Implementación Importantes

| Aspecto                    | Detalle |
|---------------------------|--------|
| Sample rate de trabajo    | Se respeta el del archivo de entrada durante el procesamiento con plugin. La codificación final fuerza 48 kHz. |
| Chunk size                | ~3 segundos (`sr * 3.0`). Importante para comportamiento stateful del plugin. |
| True mono                 | Promedio de canales (no solo left o mid). |
| Loudness por defecto      | `None` (deshabilitado). Se aplica solo `alimiter` con `true_peak`. |
| True peak por defecto     | -1.0 dBTP |
| Metadata                  | Siempre se copia del archivo **original** (`-map_metadata 1`). |
| Estructura de salida      | Se mantiene exactamente la estructura relativa de carpetas. |
| Parallelismo              | `ProcessPoolExecutor`. La función worker debe estar en el nivel superior del módulo. |
| Logging                   | `verbose` sube a DEBUG + información extra del plugin. |

---

## 10. Entorno de Desarrollo Recomendado

Desde las sesiones de julio 2026:

```bash
# Entorno pyenv utilizado
~/.pyenv/versions/3.13.14/envs/hokkaido/bin/python

# Comando típico
~/.pyenv/versions/3.13.14/envs/hokkaido/bin/python lurssen_mono_breakcore.py -I
```

Paquetes instalados vía:
```bash
pip install -r requirements.txt
```

**Dependencias duras:**
- `ffmpeg` (brew)
- `pedalboard` (para cargar el AU)
- `questionary` (mejor experiencia en menú; tiene fallback a input simple)

---

## 11. Comandos y Flags Útiles para Depuración

```bash
# Menú completo
python lurssen_mono_breakcore.py -I

# Ver parámetros reales del plugin (imprescindible)
python lurssen_mono_breakcore.py --show-plugin-params

# Dry run sin tocar nada
python ... --dry-run -i /ruta -o /salida

# Verbose (muestra qué parámetros se aplicaron realmente)
python ... -v

# Un solo job (más estable para debugging)
python ... -j 1 -v

# Forzar emulación sin plugin
python ... --no-plugin

# Cargar config específica
python ... -c config.yaml -i ... -o ...
```

**Durante desarrollo:**
- Usa siempre `--dry-run` primero.
- Revisa `/tmp/lurssen_mono_breakcore/` para ver los WAV intermedios.
- Con `-v` verás exactamente qué parámetros del plugin se tocaron.

---

## 12. Diagrama de Flujo Detallado

Este es el flujo completo del programa (versión actual que **funciona perfecto**):

```mermaid
flowchart TD
    Start([Inicio]) --> Parse[main: parse_args]
    Parse --> Sanitize[SANITIZE paths<br/>_sanitize_user_path en CLI]
    Sanitize --> LoadCfg[load_config + sanitize]

    LoadCfg --> Decide{¿-I o faltan rutas?}
    Decide -->|Sí| Interactive[run_interactive_mode<br/>+ show_summary]
    Decide -->|No| Resolve[Resolver input/output]

    Interactive --> InterSanitize[SANITIZE en prompts + carga YAML]
    InterSanitize --> Resolve

    Resolve --> FindPlugin[find_lurssen_plugin]
    FindPlugin --> Scan[find_audio_files<br/>usando SUPPORTED_EXTS]

    Scan --> Loop[Para cada archivo]

    Loop --> Compute[compute_output_path]
    Compute --> Exists{¿existe output<br/>y no overwrite?}
    Exists -->|Sí| Skip[skipped]
    Exists -->|No| Dry{¿dry-run?}
    Dry -->|Sí| DryReport[dry-run report]
    Dry -->|No| Branch{use_plugin && plugin_path?}

    Branch -->|Sí| PluginPath[process_with_lurssen]
    Branch -->|No| FFMPEGPath[process_with_ffmpeg_emulation]

    %% Camino Plugin
    PluginPath --> Ensure[_ensure_pcm_wav_for_pedalboard]
    Ensure --> Native{¿wav/aiff/flac?}
    Native -->|Sí| NativeRead[usar original directamente]
    Native -->|No| Decode[ffmpeg decode → temp decode_*.wav<br/>pcm_f32le]

    NativeRead --> LoadPlug[pedalboard.load_plugin]
    Decode --> LoadPlug

    LoadPlug --> Apply[apply_breakcore_preset<br/>mapeo defensivo + casos T-RackS]
    Apply --> Chunked[AudioFile read chunked ~3s]
    Chunked --> Process[plugin(audio, sr)]
    Process --> Mono{¿>1 canal?}
    Mono -->|Sí| TrueMono[np.mean(axis=0)<br/>True Mono Collapse]
    Mono -->|No| WriteTemp
    TrueMono --> WriteTemp[escribir temp proc_*.wav mono]

    WriteTemp --> EncodePlugin[encode_processed_wav_to_m4a]
    EncodePlugin --> FinalEncode1[ffmpeg<br/>-i temp_wav<br/>-i ORIGINAL (metadata)<br/>-ar 48000 -ac 1<br/>+ alimiter/loudnorm]

    %% Camino Emulación
    FFMPEGPath --> EmuFilters[build_ffmpeg_emulation_filter<br/>drive + EQs + comp + presence]
    EmuFilters --> EmuEncode[process_with_ffmpeg_emulation<br/>ffmpeg single-pass<br/>-af + loudnorm opcional]

    FinalEncode1 --> CleanupTemp1[limpiar temp_wav + decode temp]
    EmuEncode --> CleanupTemp2[sin temp intermedio]

    CleanupTemp1 --> Result[resultado success/error/skipped]
    CleanupTemp2 --> Result

    Result --> Collect[recolectar en main]
    Collect --> Summary[Resumen final + logs]

    Skip --> Summary
    DryReport --> Summary

    style Sanitize fill:#ffeb3b
    style InterSanitize fill:#ffeb3b
    style Ensure fill:#4caf50
    style TrueMono fill:#f44336,color:#fff
    style Decode fill:#2196f3
```

### Puntos clave del flujo (anotados)

- **Puntos de sanitización** (amarillo): Todos los paths que vienen del usuario pasan por `_sanitize_user_path()`.
- **Decodificación selectiva** (azul): Solo se decodifica cuando es necesario para pedalboard.
- **Colapso verdadero a mono** (rojo): Este paso es crítico para la calidad breakcore.
- El archivo **ORIGINAL** siempre se usa para copiar metadatos, incluso si se decodificó.
- Limpieza de temporales está garantizada con `finally` en `process_single_file` y en `process_with_lurssen`.

---

## 13. Pruebas Recomendadas Antes de Tocar el Código

**Regla de oro:** Antes de hacer **cualquier** cambio (incluso pequeño), ejecuta este checklist. El código actual **funciona perfecto**, así que cualquier modificación debe demostrar que no lo rompe.

### Checklist Obligatorio (mínimo)

| # | Prueba | Comando / Acción | Qué verificar |
|---|--------|------------------|---------------|
| 1 | **Dry-run básico** | `python ... --dry-run -i /ruta/pequeña -o /tmp/test_out` | Muestra correctamente los archivos y rutas de salida |
| 2 | **Ruta externa** | Usar carpeta real en `/Volumes/...` como input y/o output | **No** debe aparecer prepending del cwd del repo |
| 3 | **Path con comillas** | En menú interactivo o CLI, pegar ruta entre comillas simples o dobles | Debe sanitizar correctamente y resolver la ruta real |
| 4 | **Formato nativo (wav/flac)** | Procesar al menos 1 archivo .wav o .flac | Funciona con plugin y sin plugin |
| 5 | **Formato MP3** | Procesar al menos 1 archivo .mp3 | Se decodifica correctamente (ver temporales en `/tmp`) |
| 5b | **Formato Opus** | Procesar al menos 1 archivo .opus | Se reconoce en el scan y se decodifica vía ffmpeg |
| 6 | **Plugin + Emulación** | Correr una vez con plugin y otra con `--no-plugin` sobre los mismos archivos | Ambas generan salida válida |
| 7 | **Multiprocessing** | `-j 2` o `-j 3` con ≥4 archivos | No hay corrupción de archivos ni errores de concurrencia |
| 8 | **Overwrite** | Procesar, luego correr con `--overwrite` | Los archivos se reemplazan correctamente |
| 9 | **Metadatos** | Usar un archivo con título, artista, álbum, tracknumber | Verificar en el .m4a final con `ffprobe -i archivo.m4a -show_format -show_streams` |
| 10 | **Estructura de carpetas** | Input con subcarpetas (álbumes) | La salida debe replicar exactamente la estructura |
| 11 | **Preview desde menú** | En menú interactivo → "Preview / dry-run scan" | Lista correcta de archivos |
| 12 | **Dry-run desde menú** | Opción "START (dry-run only)" | No escribe nada |

### Pruebas Avanzadas / Regresión

- Procesar una carpeta grande real (mínimo 20-30 tracks) con `jobs=2` + verbose.
- Mezcla de formatos en la misma carpeta (wav + mp3 + flac + m4a).
- Archivo con caracteres especiales en el nombre (`' " & ( ) -`).
- Input y Output apuntando al **mismo** volumen externo.
- Ejecutar sin plugin instalado (debe caer gracefully a emulación).
- Cargar config legacy (solo una línea con plugin_path).
- Guardar configuración desde el menú y volver a cargarla.
- Verificar que los temporales se limpian correctamente después de cada ejecución (revisa `/tmp/lurssen_mono_breakcore/`).

### Herramientas de verificación recomendadas

```bash
# Ver formato y metadatos del resultado
ffprobe -i "archivo_MONO_LURSSEN_BREAKCORE.m4a" -show_format -show_streams -hide_banner

# Contar canales (debe ser 1)
ffprobe -i archivo.m4a -show_streams -select_streams a:0 -hide_banner | grep channels

# Ver duración y bitrate
ffprobe -i archivo.m4a -v quiet -print_format json -show_format | jq '.format.duration, .format.bit_rate'

# Buscar temporales huérfanos
ls -l /tmp/lurssen_mono_breakcore/
```

### Orden recomendado de pruebas después de un cambio

1. Dry-run con carpeta pequeña
2. Procesamiento real de 1 archivo .mp3 (camino plugin)
3. Procesamiento real de 1 archivo .wav (camino nativo)
4. Ruta en volumen externo
5. Con `jobs=2`
6. Verificación de metadatos + estructura

Si todas estas pasan → puedes considerar que el cambio es seguro.

---

## 14. Guía para Implementar Nuevas Funcionalidades

### Agregar un nuevo formato de entrada (ej. `.ogg`)
1. Añadir la extensión a `SUPPORTED_EXTS`.
2. (Opcional) Ajustar `_ensure_pcm_wav_for_pedalboard` si el formato necesita tratamiento especial.
3. Actualizar la documentación en el docstring del módulo y README si es relevante.
4. Listo. El resto del pipeline ya lo maneja.

### Agregar un nuevo perfil de mastering
Editar `INTERACTIVE_PROFILES` (al principio del archivo). Es muy fácil de extender.

### Mejorar el mapeo de parámetros del plugin
La función `apply_breakcore_preset` es el lugar. Agregar más candidatos en las listas `for cand in (...)`.

**Consejo:** Siempre prueba con `--show-plugin-params` y con `-v` para ver qué nombres reales expone el plugin en esa máquina.

### Cambiar la filosofía de loudness
- Modificar los defaults y las opciones en `LOUDNESS_OPTIONS`.
- Actualizar los comentarios en `README.md` y `config.example.yaml`.

### Agregar más opciones de salida (ej. 44.1 kHz, FLAC, Opus, etc.)
El formato de salida se elige con `output_format` (`m4a` | `wav`). Para nuevos formatos:
1. Añadir el valor a `SUPPORTED_OUTPUT_FORMATS` y `output_extension()`.
2. Extender `_append_codec_args()` con el codec ffmpeg correspondiente.
3. Propagar la opción en CLI / YAML / menú interactivo (mismo patrón que `wav`).
Sample rate sigue fijado a 48 kHz mono por diseño.

### Agregar logging más estructurado
Actualmente usa `logging` básico. Se puede mejorar añadiendo un logger por módulo o JSON logs si se quiere.

---

## 15. Historial de Cambios Recientes (Julio 2026)

### 2026-07-30 — Exportación a WAV (PCM)
- Nuevo `output_format`: `m4a` (default, compatible) | `wav`.
- `wav_bit_depth`: 16 o 24 (default 24 → `pcm_s24le`).
- CLI: `--format` / `--output-format`, `--wav-bit-depth`.
- YAML: `output_format`, `wav_bit_depth` (ver `config.example.yaml`).
- Menú interactivo: Output settings pregunta formato y, si es WAV, bit depth.
- Codificación unificada en `encode_processed_wav()` + `_append_codec_args()`; camino plugin y emulación ffmpeg ambos soportan WAV.
- `compute_output_path()` usa la extensión correcta (`.m4a` / `.wav`).
- Misma cadena de loudness/alimiter y mono 48 kHz que M4A.
- Documentación actualizada en README + config.example + esta bitácora.

### 2026-07-14 — Soporte de archivos .opus
- Agregado `.opus` a `SUPPORTED_EXTS` (descubrimiento + menú interactivo + CLI).
- Camino plugin: decodificación vía `_ensure_pcm_wav_for_pedalboard()` (ffmpeg → PCM float).
- Camino emulación: ffmpeg ya acepta Opus como entrada sin cambios extra.
- Actualizados docstring, mensaje de error y esta bitácora.

### 2026-07-08 — Soporte completo de archivos .mp3
- Agregado `.mp3` a `SUPPORTED_EXTS`.
- Implementada `_ensure_pcm_wav_for_pedalboard()` + integración en `process_with_lurssen`.
- Decodificación transparente vía ffmpeg para el camino del plugin.
- Actualizado docstring.

### 2026-07-08 — Fix crítico de manejo de rutas con comillas
- Introducida `_sanitize_user_path()`.
- Aplicación exhaustiva en todos los puntos de entrada de paths.
- Lógica de recuperación para valores ya envenenados (`cwd/'/Volumes/...`).
- Ahora es posible usar rutas en `/Volumes/The_DollMaker` (u otros discos externos) sin problemas.

### Mejoras previas
- Menú interactivo completo con perfiles.
- Soporte de multiprocessing.
- Manejo robusto de metadatos.
- Perfiles breakcore optimizados.
- Fallback ffmpeg de alta calidad.

---

## 16. Notas para Futuras Sesiones de Desarrollo

1. **Siempre parte del estado actual**: El código que está en `main()` hoy es la fuente de verdad. No asumas comportamientos antiguos.

2. **El menú interactivo es la interfaz principal**. La mayoría de usuarios lo usan. Los cambios en CLI deben seguir siendo compatibles.

3. **Los paths son traicioneros**. Cualquier nueva forma de recibir paths del usuario (nuevo flag, nuevo prompt, lectura de lista de archivos, etc.) **debe** pasar por `_sanitize_user_path()`.

4. **El colapso a mono es sagrado** para el caso de uso breakcore. Documentar muy bien cualquier cambio en esta área.

5. **Los parámetros del plugin varían** según la versión de T-RackS / Lurssen instalada. El código ya es defensivo; sigue siéndolo.

6. **Los archivos temporales** pueden acumularse si hay crashes. Considerar limpieza al inicio del programa en el futuro si se detectan muchos archivos viejos.

7. Consulta la sección **"13. Pruebas Recomendadas Antes de Tocar el Código"** antes de hacer cualquier cambio.

8. Revisa siempre la sección **"17. Cosas que NO TOCAR NUNCA"** antes de modificar lógica central. Si algo está en esa lista, hay una razón muy fuerte.

---

## 17. Cosas que NO TOCAR NUNCA (Reglas de Oro)

Estas son las decisiones de diseño y piezas de código que están **intencionalmente** de esta forma porque el script **funciona perfecto** hoy. 

**Cambiar cualquiera de estos elementos sin una discusión muy profunda y pruebas exhaustivas es una forma rápida de romper la herramienta.**

### 1. Colapso a Mono Verdadero (True Mono)
```python
if processed.shape[0] > 1:
    processed = np.mean(processed, axis=0, keepdims=True).astype(np.float32)
```
**NO TOCAR** la lógica de `np.mean(..., axis=0)`.

**Por qué:** Este es el corazón del propósito breakcore. "True mono" (promedio de ambos canales) es lo que fuerza que los elementos importantes (kicks, snares, leads) traduzcan correctamente en sistemas mono. Cambiar a "solo left", "mid", o cualquier otra cosa rompe la promesa del proyecto.

### 2. Filosofía de Loudness (Default = Deshabilitado)
- `loudness_target: null` por defecto
- Solo se aplica un `alimiter` suave con `true_peak: -1.0`
- En `LOUDNESS_OPTIONS` y en `select_loudness_target`, "Disabled" es la primera y recomendada opción.

**NO TOCAR** el default a -23 LUFS ni hacer loudness obligatorio.

**Por qué:** -23 LUFS es para broadcast/TV. Mata el punch, la dinámica y la energía caótica del breakcore. Esta decisión fue deliberada y está documentada en el README y en la config.

### 3. Sanitización de Paths (`_sanitize_user_path`)
Cualquier nuevo lugar donde se reciba un path del usuario **debe** pasar por `_sanitize_user_path()`.

Esto incluye:
- Nuevos flags CLI
- Nuevos prompts
- Lectura de listas de archivos
- Cualquier otra entrada de usuario

**NO TOCAR** ni saltarte esta función nunca más.

**Por qué:** Fue la causa del bug original ("siempre prepends the repo directory"). El usuario pega rutas con comillas constantemente. Esta función (incluyendo el recovery regex) es sagrada.

### 4. Formato de Salida Fijo
- Siempre **48 kHz**
- Siempre **1 canal (mono)**
- Siempre **AAC** en contenedor `.m4a`
- Siempre con el sufijo `_MONO_LURSSEN_BREAKCORE` (o el configurado)

**NO** cambiar esto a 44.1 kHz, Opus, MP3, estéreo por defecto, etc. sin una decisión de arquitectura mayor.

**Por qué:** Es el contrato del proyecto para "mono 48 kHz de alta calidad para producción y distribución".

### 5. Función Worker para Multiprocessing
```python
def process_single_file(...):
```
Esta función **debe permanecer en el nivel superior del módulo**.

**NO** la muevas dentro de otra función, ni la conviertas en un método de clase, ni uses `lambda`.

**Por qué:** `ProcessPoolExecutor` requiere que la función sea picklable y esté en el top-level cuando se usa `spawn` (comportamiento por defecto en macOS y Windows).

### 6. Copia de Metadatos desde el Archivo ORIGINAL
En ambas rutas de codificación:
```python
"-i", str(original_path),
"-map_metadata", "1",
```
**NO** cambies esto para usar el archivo procesado como fuente de metadatos.

**Por qué:** Cuando usamos el camino del plugin, el `temp_wav` es un archivo nuevo sin metadatos. Siempre hay que copiar del archivo de entrada original.

### 7. Tamaño de Chunks en Procesamiento con Plugin
```python
chunk_frames = max(4096, int(sr * 3.0))
```
**NO** reduzcas drásticamente este valor (ej. a 512 o 1024 frames) pensando que "va a ir más rápido".

**Por qué:** El plugin Lurssen es stateful. Chunks de ~3 segundos dan buen comportamiento. Chunks muy pequeños pueden degradar la calidad del procesamiento.

### 8. Manejo de Archivos Temporales y Limpieza
- El patrón de `finally` para limpiar `temp_wav` y los archivos de decodificación (`decode_*.wav`)
- El directorio `/tmp/lurssen_mono_breakcore/`

**NO** elimines la limpieza agresiva de temporales.

**Por qué:** Estos archivos pueden ser grandes y se acumulan fácilmente si hay errores. La limpieza en `finally` es lo que mantiene el sistema limpio.

### 9. Mapeo Defensivo de Parámetros del Plugin
La función `apply_breakcore_preset()` tiene decenas de nombres alternativos y casos especiales para T-RackS 6 / Lurssen EQ v6.

**NO** la simplifiques agresivamente ("voy a limpiar esto, solo voy a usar los nombres bonitos").

**Por qué:** Los nombres de parámetros cambian según la versión exacta del plugin instalada. El código defensivo es lo que hace que funcione en la mayoría de instalaciones de usuarios.

### 10. El Menú Interactivo como Experiencia Principal
El flujo que lanza el menú automáticamente cuando no hay `-i` / `-o` es intencional.

**NO** lo elimines ni lo hagas opcional de forma que rompa la usabilidad para usuarios normales.

**Por qué:** La mayoría de la gente usa `-I` o simplemente ejecuta el script sin argumentos. Es la interfaz más amigable.

---

**Regla final:**
> Si estás por tocar algo de esta lista → **detente**, agrega la prueba en la sección 13, y documenta el cambio en esta bitácora antes de continuar.

---

**Este documento debe mantenerse actualizado.** Cada vez que se haga un cambio importante, agregar una entrada con fecha, qué se modificó, por qué, y cualquier detalle de depuración relevante.

**Regla de oro para cualquier sesión futura:**
> Antes de editar cualquier línea:
> 1. Ejecuta la sección **13. Pruebas Recomendadas**.
> 2. Revisa la sección **17. Cosas que NO TOCAR NUNCA**.

**Hoy, 2026-07-08, el script FUNCIONA PERFECTO.**  
Cualquier desarrollo futuro debe construirse sobre esta base sólida.

---

*Bitácora generada para preservar conocimiento institucional del proyecto.*
