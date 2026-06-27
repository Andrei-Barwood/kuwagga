# Reparador de Video MP4

CLI multiplataforma (Windows, macOS y Linux) para reparar videos MP4, MOV, M4V y formatos similares truncados o corruptos, especialmente grabaciones H.264 y H.265.

El script combina dos herramientas:

- **untrunc**: reconstruye la estructura del contenedor MP4 usando un video de referencia sano del mismo origen.
- **ffmpeg**: actua como respaldo con remux y copia directa de flujos cuando untrunc no es suficiente.

---

## Requisitos previos

| Requisito | Detalle |
|-----------|---------|
| Python | 3.8 o superior |
| untrunc | Se instala automaticamente o se configura manualmente |
| ffmpeg | Se instala automaticamente segun el sistema operativo |

### macOS y Linux

- **Homebrew** (`brew`) recomendado para instalar `ffmpeg` y `untrunc`.
- El script intenta usar el tap `ottomatic-io/video` para untrunc.
- Si falla, compila untrunc desde el repositorio [anthwlock/untrunc](https://github.com/anthwlock/untrunc).

### Windows

- **Chocolatey** (`choco`) o **winget** para instalar `ffmpeg`.
- **untrunc** no tiene paquete estandar: el script puede descargarlo desde GitHub o puedes indicar la ruta a `untrunc.exe` manualmente.

---

## Instalacion

No requiere paquetes Python adicionales. Solo copia el script en tu equipo:

```
06_reparar_video_mp4.py
```

En macOS/Linux puedes hacerlo ejecutable:

```bash
chmod +x 06_reparar_video_mp4.py
```

---

## Formas de uso

### 1. Menu interactivo (recomendado)

```bash
python3 06_reparar_video_mp4.py
```

En Windows:

```powershell
python 06_reparar_video_mp4.py
```

Al iniciar veras el menu principal:

```
Menu principal:
  1. Reparar video truncado/corrupto
  2. Verificar / instalar dependencias
  3. Configurar ruta de untrunc
  4. Salir
```

### 2. Reparacion directa por linea de comandos

```bash
python3 06_reparar_video_mp4.py \
  --reference /ruta/al/video_sano.mp4 \
  --corrupt /ruta/al/video_roto.mp4
```

En Windows:

```powershell
python 06_reparar_video_mp4.py --reference C:\Videos\sano.mp4 --corrupt C:\Videos\roto.mp4
```

### 3. Instalar dependencias sin abrir el menu

```bash
python3 06_reparar_video_mp4.py --install-deps
```

### 4. Configurar ruta de untrunc (util en Windows)

```bash
python3 06_reparar_video_mp4.py --untrunc-path C:\tools\untrunc.exe
```

Tambien puedes hacerlo desde el menu, opcion **3**.

### 5. Ayuda

```bash
python3 06_reparar_video_mp4.py --help
```

---

## Tutorial paso a paso

### Paso 1: Preparar los archivos

Necesitas **dos videos**:

1. **Video de referencia (sano)**: una grabacion completa y reproducible del **mismo dispositivo, misma resolucion y mismos ajustes** que el video danado. Cuanto mas parecido sea, mayor probabilidad de exito.
2. **Video corrupto o truncado**: el archivo que no se reproduce o se corto abruptamente.

Formatos compatibles: `.mp4`, `.m4v`, `.mov`, `.3gp`, `.mkv`.

> **Consejo:** Si grabaste con una camara o telefono y el archivo se corrompio al final de la grabacion, usa otro clip del mismo dia y configuracion como referencia.

### Paso 2: Verificar dependencias

1. Ejecuta el script.
2. Elige la opcion **2. Verificar / instalar dependencias**.
3. Si faltan herramientas, responde `s` cuando pregunte si deseas instalarlas automaticamente.

El script mostrara el estado de `ffmpeg`, `untrunc`, `brew` (macOS/Linux) o `choco`/`winget` (Windows).

### Paso 3: Reparar el video

1. Elige la opcion **1. Reparar video truncado/corrupto**.
2. Ingresa la ruta completa del **video de referencia**.
3. Ingresa la ruta completa del **video corrupto**.
4. Confirma con `s` para iniciar.

Puedes pegar rutas con comillas o espacios; el script las normaliza automaticamente.

### Paso 4: Revisar el resultado

El script ejecuta la reparacion en este orden:

#### Fase A: untrunc

- Corre untrunc mostrando la salida en vivo.
- Si detecta errores estructurales (por ejemplo `premature end`, `unknown sequence`), **reintenta automaticamente** con la bandera `-s` (omitir secuencias desconocidas).
- El archivo reparado se guarda junto al video corrupto con el sufijo `_fixed`:

```
video_roto.mp4  -->  video_roto_fixed.mp4
```

#### Fase B: ffmpeg (respaldo)

Si untrunc no logra reparar el archivo, el script intenta un **remux** con ffmpeg:

- Primero con tolerancia a errores (`+genpts+discardcorrupt`).
- Luego con copia directa de flujos (`-c copy`).

El archivo de respaldo se guarda con el sufijo `_remux`:

```
video_roto.mp4  -->  video_roto_remux.mp4
```

### Paso 5: Probar el video reparado

Abre el archivo generado con tu reproductor habitual (VLC, QuickTime, etc.). Si el video se ve pero el audio falla (o viceversa), prueba con otro video de referencia mas cercano al corrupto.

---

## Configuracion persistente

El script guarda ajustes en:

```
~/.video_repair/config.json
```

En Windows equivale a:

```
C:\Users\TU_USUARIO\.video_repair\config.json
```

Ahi se almacena, entre otras cosas, la ruta personalizada de `untrunc`.

Las herramientas descargadas automaticamente en Windows se guardan en:

```
~/.video_repair/tools/
```

---

## Instalacion manual de dependencias

Si la instalacion automatica falla, puedes instalar las herramientas a mano:

### ffmpeg

| Sistema | Comando |
|---------|---------|
| macOS | `brew install ffmpeg` |
| Linux (con brew) | `brew install ffmpeg` |
| Windows (Chocolatey) | `choco install ffmpeg -y` |
| Windows (winget) | `winget install Gyan.FFmpeg` |

### untrunc

| Sistema | Metodo |
|---------|--------|
| macOS | `brew tap ottomatic-io/video && brew install ottomatic-io/video/untrunc` |
| Linux | Mismo tap de Homebrew, o compilar desde [anthwlock/untrunc](https://github.com/anthwlock/untrunc) |
| Windows | Descargar `untrunc_x64.zip` desde [releases](https://github.com/anthwlock/untrunc/releases/latest) y configurar la ruta en el menu opcion 3 |

---

## Ejemplos practicos

### Reparar un video de camara truncado

```bash
python3 06_reparar_video_mp4.py \
  --reference ~/Videos/clip_corto_sano.MP4 \
  --corrupt ~/Videos/clip_largo_corrupto.MP4
```

### Solo instalar herramientas en un Mac nuevo

```bash
python3 06_reparar_video_mp4.py --install-deps
```

### Windows con untrunc descargado manualmente

```powershell
python 06_reparar_video_mp4.py --untrunc-path D:\utilidades\untrunc.exe
python 06_reparar_video_mp4.py --reference D:\Videos\ok.mp4 --corrupt D:\Videos\bad.mp4
```

---

## Solucion de problemas

| Problema | Posible causa | Que hacer |
|----------|---------------|-----------|
| `untrunc no disponible` | No instalado o ruta incorrecta | Opcion 2 del menu o descarga manual en Windows |
| `ffmpeg no disponible` | No esta en el PATH | Instalar con brew/choco/winget y reiniciar la terminal |
| El video reparado no reproduce | Referencia incompatible | Usa un video del mismo dispositivo y configuracion |
| Archivo `_fixed` muy pequeno | Corrupcion severa | Prueba el archivo `_remux` o un video de referencia distinto |
| Homebrew no encontrado (Linux) | brew no instalado | Instala Homebrew o compila untrunc manualmente |
| La descarga de untrunc falla (Windows) | Sin conexion o firewall | Descarga manual desde GitHub y usa opcion 3 |

---

## Limitaciones

- **untrunc** necesita un video de referencia del mismo origen; no funciona con cualquier MP4 arbitrario.
- La reparacion de **H.265 (HEVC)** depende de que el contenedor y los metadatos sean compatibles con la version de untrunc instalada.
- El remux con **ffmpeg** solo recupera datos que aun existen en el archivo; no reconstruye fotogramas perdidos como untrunc.
- Videos con cifrado DRM o formatos propietarios no soportados no se pueden reparar con estas herramientas.

---

## Referencias

- Script: `06_reparar_video_mp4.py`
- untrunc: [github.com/anthwlock/untrunc](https://github.com/anthwlock/untrunc)
- ffmpeg: [ffmpeg.org](https://ffmpeg.org/)
- Tap Homebrew: [github.com/ottomatic-io/homebrew-video](https://github.com/ottomatic-io/homebrew-video)