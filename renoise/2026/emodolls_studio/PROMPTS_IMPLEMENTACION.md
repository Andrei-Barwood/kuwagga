# emodolls studio — pack de implementación

Producto aparte. App nativa macOS en Swift. Mastering true-mono original.
Licencia MIT. Idioma de UI: español.

Este archivo es la fuente de verdad para construir, interrumpir y retomar.
No uses el script Python `lurssen_mono_breakcore.py` como dependencia.
No copies cadenas, nombres de knobs, presets ni material de IK Multimedia.

---

## Cómo retomar (léelo siempre al abrir una sesión)

1. Lee este archivo entero (o al menos: Prohibido, Decisiones cerradas, Estado).
2. Busca `### ESTADO` más abajo. El siguiente prompt con casilla vacía `[ ]` es el que toca.
3. Pega **solo ese prompt** (la sección `PROMPT N`) en la sesión, más este preámbulo:

```
Eres el implementador de emodolls studio.
Repo: /Users/andreibarwood/Public/kuwagga/renoise/2026/emodolls_studio/
Lee PROMPTS_IMPLEMENTACION.md. Respeta Prohibido y Decisiones cerradas.
Ejecuta únicamente el PROMPT que te indico. No adelantes prompts.
Al terminar: marca el prompt como [x] en ### ESTADO, anota archivos tocados
y el comando para verificar. No firmes ni notarices hasta PROMPT 12.
```

4. Si un prompt queda a medias, no lo marques. Escribe en `### ESTADO` una línea `BLOQUEO:` con el error.
5. v1 es usable cuando PROMPT 00–11 están `[x]`. Firma/notarización es 12 (puede quedar bloqueado; ver credenciales).

---

### ESTADO

Fecha de este pack: 2026-09-09

- [x] PROMPT 00 — Scaffold Xcode + identidad
      Archivos: EmodollsStudio/project.yml, EmodollsStudio.xcodeproj (xcodegen),
      App/EmodollsStudioApp.swift, App/EmodollsStudio.entitlements,
      Theme/Theme.swift, Views/ContentView.swift, Assets.xcassets, .gitignore
      Verificar: `cd EmodollsStudio && xcodebuild -scheme EmodollsStudio -configuration Debug build` → 0
      Firma: Apple Development andresbarbudo@icloud.com, Team T77VRM22PQ, arm64, sandbox ON
- [x] PROMPT 01 — Modelo de dominio (géneros, caracteres, knobs, formatos)
      Archivos: Models/{Genre,CharacterID,KnobIDs,ExportFormat,MetadataDraft,SessionLimits}.swift
      Tests: EmodollsStudioTests/DomainTests.swift (11 tests)
      Verificar: `cd EmodollsStudio && xcodebuild -scheme EmodollsStudio -destination 'platform=macOS,arch=arm64' test` → 0
      4+4+4+2 caracteres; labels Yandere/Kizu/Kyun etc.; DittoPRO duplica L=R; sufijo `_MD`
- [x] PROMPT 02 — Sistema de tema (4 géneros × día/noche, tokens del atlas)
      Archivos: Theme/{Color+Hex,Palette,ThemeController,Themed}.swift
      Vista: ContentView pinta género + Día/Noche/Sistema + 3 knobs
      Tests: ThemeTests.swift (9) + DomainTests (11) = 20, 0 fallos
      Contraste text/bg ≥ 4.5 AA en las 8 paletas; tokens Breakcore.bgNight etc.
- [x] PROMPT 03 — Motor DSP (grafo original, colapso mono, techo −1.11)
      Archivos: DSP/{DSPSeal,MonoCollapse,Biquad,TanhSaturator,EQStage,FrequencySkeleton,
      Compressor,HighFrequencyCap,Oversampler,TruePeakLimiter,TPDFDither,DSPGraph,
      RenderSettings,AudioBufferIO}.swift
      API: RenderSettings + Engine.render / processMono
      Tests: DSPTests (7) + anteriores = 27, 0 fallos
      Limitador ×4 lookahead 8 ms a ETPC −1.11 ± 0.03; heat=0 THD bajo; Estreno off sin LUFS
- [x] PROMPT 04 — Recetas por carácter (sin valores custom)
      Archivos: DSP/Recipes.swift; grafo, RenderSettings, ThemeController, ContentView
      Tests: RecipeTests (9) + anteriores = 36, 0 fallos
      14 recetas; Shunya ceiling −2.00 / HPF 50 / b1 sin 40–80;
      anclas al cambiar carácter; knobs no cambian el carácter; Estreno no vive en Recipe
- [x] PROMPT 05 — I/O: decode, encode WAV/M4A, DittoPRO MP3, metadatos, sufijo `_MD`
      Archivos: Services/{AudioIO,StudioFilePicker,LameEncoder,ID3v23}.swift
      Vendor: libmp3lame.0.dylib + libmpg123.0.dylib (LGPL, enlace dinámico)
      Tests: AudioIOTests (5) + anteriores = 41, 0 fallos
      WAV ExtAudioFile 16-bit; M4A AAC 256k; DittoPRO LAME CBR 320 L=R + ID3v2.3
- [x] PROMPT 06 — Sesión: máx 10 temas, cola, overwrite, progreso
      Archivos: Services/{Session,Processor}.swift
      Tests: SessionTests (6) + anteriores = 47, 0 fallos
      Máx 10 con aviso en español; 1 job; skip si no overwrite;
      fallos no abortan; dry-run; progreso i/n en MainActor; cancel cooperativa
- [x] PROMPT 07 — Ventana única SwiftUI (español, knobs avanzados, formulario metadatos)
      Archivos: Views/ContentView.swift, App/EmodollsStudioApp.swift (Session + Theme)
      Tests: 47, 0 fallos (el TEST_HOST abre la ventana)
      Atajos: ⌘O entrada, ⌘⇧O salida, ⌘↩ procesar, ⌘. cancelar
- [x] PROMPT 08 — Destino streaming (Apple Music / iTunes / YouTube Music / Spotify)
      Archivos: DSP/Loudness.swift (BS.1770-4), DSPGraph aplica ganancia + limitador
      Tests: EstrenoTests (2) + anteriores = 49, 0 fallos
      Tono −6 dBFS 1 kHz 5 s → I ≈ −14 ± 0.5 LUFS, TP ≤ −1.11; knobs/carácter intactos
- [x] PROMPT 09 — Prueba de oído con 1 tema por género + sello true-peak
      Archivos: DSP/TruePeakLimiter.swift (clamp TP tras downsample; recetas no tocadas),
      EmodollsStudioTests/HearingTests.swift, DSPTests.swift (click ≤ ETPC)
      Clips: sintéticos 12 s burst/sub/pad/sitar (discografía no montada)
      afinfo: WAV 44 100 Hz Int16 1 ch, 12 s, sufijo `_MD`; TP en el sello
      Tests: HearingTests + DSPTests (8) + anteriores = 51, 0 fallos
      Verificar: `cd EmodollsStudio && xcodebuild -scheme EmodollsStudio -configuration Debug -destination 'platform=macOS,arch=arm64' -allowProvisioningUpdates test` → 51, 0
      Renders: `hearing-out/` (también sandbox Caches/emodolls-hearing/out)
      Oído (mono, clips sintéticos; recetas intactas):
      - breakcore / Obsesión: kicks y clicks siguen vivos (crest 13.8→15.0); no hay squash; TP −1.11.
      - dubstep / Subsoil: wobble 46 Hz con cuerpo (sub 0.08→0.05, no vacío); crest 7.3→11.3, sub no sucio; TP −1.44.
      - vaporwave / Mallsoft: pad encolado (crest 11.5→6.7) sin grit; TP −6.5 lejos del techo; Estreno I −14.0.
      - kirtan / Aarti viva: punteos con crest 11.7 (de 15.4), TP −3.23; Shunya más hueco (I −18.9) sin ensuciar graves.
- [x] PROMPT 10 — Empaquetado `.app` arrastrable a /Applications
      Archivos: AppIcon.appiconset (círculo #EC078B / #1A0A10), project.yml (dylibs → Resources),
      LameEncoder.swift (Bundle.main.url), package-release.sh, dist/LEEME.txt
      Destino: `dist/emodolls studio.app` arm64, Apple Development, sandbox ON, sin notarizar
      Resources: libmp3lame.0.dylib + libmpg123.0.dylib + NOTICE.txt + AppIcon.icns
      Uso: arrastrar a /Applications (`dist/LEEME.txt`)
      Verificar: `./package-release.sh` → lipo arm64; `codesign --verify --deep --strict`
- [ ] PROMPT 11 — README MIT + higiene (cero nombres ajenos)
- [ ] PROMPT 12 — Firma y notarización (solo si hay programa de pago)

BLOQUEO: (vacío)

---

## Prohibido

- Nombres, logos, presets, knobs o copy de IK Multimedia, T-RackS, Lurssen, Ozone, etc.
- Bundlear, llamar o detectar Audio Units comerciales.
- Python, pedalboard, ffmpeg como motor de DSP (ffmpeg/lame solo como encoder MP3 embebido, si hace falta).
- Palabra “Lurssen”, “T-RackS”, “IK” en UI, bundle, comentarios de código, README de la app.
- Nombres Monster High, Mattel, Draculaura, etc. en la app. El atlas es referencia cromática privada; los tokens se llaman por género.
- Más de 10 archivos de audio por sesión.
- Valores custom / sliders numéricos libres fuera de los tres knobs (cada knob tiene rango fijo).
- Sample rate de trabajo distinto de 44 100 Hz.
- Colapsar a stereo “de verdad”. El master es mono. DittoPRO duplica L=R al encode.
- Modo básico. Solo knobs avanzados (tres por género, con nombres del género).

---

## Decisiones cerradas (no reabrir)

### Producto

| Campo | Valor |
|---|---|
| Nombre visible | `emodolls studio` |
| Bundle ID | `studio.emodolls.app` |
| Min macOS | 14.0 (Sonoma), Apple Silicon |
| UI | SwiftUI, una ventana, español |
| Licencia | MIT |
| Usuarias | mamá (vaporwave / dubstep / breakcore / kirtan) y Andrei (discografía → Ditto) |
| Relación con el CLI Python | producto aparte; no se importa |

### Audio

| Campo | Valor |
|---|---|
| Reloj interno | 44 100 Hz, 32-bit float |
| Colapso mono | **antes** de la cadena (media L+R). Se masteriza lo que oye un parlante |
| WAV de entrega | PCM 16-bit, 44 100 Hz, 1 canal, dither TPDF |
| M4A | AAC, 256 kbps, 44 100 Hz, 1 canal |
| DittoPRO | MP3 CBR 320 kbps, 44 100 Hz, dual-mono L=R (contenido true-mono) |
| Sufijo | `_MD` (antes de la extensión) |
| Estructura de carpetas | espejo del input |
| Overwrite | checkbox; si está off y el destino existe, skip |
| Metadatos | formulario: título, artista, álbum, pista, año, género |
| Tope de sesión | 10 temas |

### Sello de true-peak (identidad matemática)

Constante de la casa, no el −1.0 genérico de Apple ni el −1.5 de YouTube.

```
ETPC  = −1.11 dBTP     // Emodolls True Peak Constant  (WAV, M4A)
EDP   = −1.61 dBTP     // Emodolls Delivery Peak       (MP3: ETPC − 0.50, overshoot de LAME)
LUFS* = −14.00         // solo plantilla Estreno
```

Por destino:

| Destino | True peak | Loudness |
|---|---|---|
| WAV / M4A, caracteres densos (breakcore, dubstep, kirtan intenso, vaporwave agresivo) | −1.11 dBTP | off |
| vaporwave Clarity / kirtan meditación | −2.00 dBTP | off |
| DittoPRO (cualquier carácter) | −1.61 dBTP | off, salvo Estreno |
| Plantilla **Estreno** (universal streaming) | −1.11 WAV/M4A, −1.61 MP3 | −14.00 LUFS |

El limitador true-peak es propio (lookahead 8 ms, release 80 ms, ceiling exacto). Medir con el mismo criterio ITU-R BS.1770 true-peak. El número −1.11 es el sello: si un master no cae en −1.11 ± 0.03 dBTP (salvo meditación / Estreno-MP3), el motor está mal.

### Grafo DSP (original, mismo esqueleto para todos)

```
decode → resample 44.1k → mono mean
  → HPF subtractivo (corte por género)
  → saturación suave (tanh, makeup)          // knob A
  → EQ 5 bandas (frecuencias propias)        // knob B escala TODAS las ganancias
  → presencia (campana propia del género)    // knob C
  → glue compressor (ratio/ataque por carácter)
  → techo de agudos (de-ess 5–8 kHz, no “de-esser de marca”)
  → limitador true-peak (ETPC o EDP)
  → (opcional) loudnorm −14 LUFS si Estreno
  → dither 16-bit si WAV
  → encode
```

Knob B es un *ride* de las 5 ganancias a la vez (técnica de oficio, no un control ajeno).
No hay valores custom: los knobs son 0.0…1.0. Las recetas solo eligen el punto de ancla (el valor inicial). El usuario puede girarlos, no puede escribir números.

### Tres knobs — nombres por género (IDs internos fijos)

IDs de código (nunca visibles): `heat`, `bloom`, `fang`.

| Género | heat (sat + pega al comp) | bloom (ride EQ) | fang (presencia) |
|---|---|---|---|
| breakcore | Yandere | Kizu | Kyun |
| dubstep | Pelt | Howl | Fang |
| vaporwave | Chlorine | Tide | Glare |
| kirtan | Seva | Aarti | Naam |

Vibra: breakcore = yandere / manga oscuro. dubstep = lobo / cuerpo. vaporwave = piscina / VHS. kirtan = ofrenda / lámpara. Cero “Drive / Push / Presence”.

### Plantillas y caracteres

Cuatro géneros. Los tres electrónicos tienen **4 caracteres** (traducción de Balanced / Aggressive / Heavy Glue / Clarity, con nombres propios). Kirtan tiene **2**.

**breakcore** (paleta Draculaura, tokens sin su nombre)

| Carácter | Qué hace la cadena |
|---|---|
| Obsesión | ancla: cadena completa, sat y glue moderados |
| Desu | más heat, saturación presente, ataque más rápido |
| Pegamento | más compresión, menos fang, más cuerpo 210 Hz |
| Airi | poco heat, más Kyun y aire, glue ligero |

**dubstep**

| Carácter | Qué hace |
|---|---|
| Subsoil | cuerpo 40–60 Hz contenido, glue medio |
| Drop | más heat, howl alto, techo −1.11 |
| Molasses | glue pesado, fang bajo, sub redondo |
| Steel | poco heat, fang alto, transiente de snare/growl |

**vaporwave**

| Carácter | Qué hace |
|---|---|
| Mallsoft | saturación VHS suave, 6 kHz un poco opaco |
| Runway | más heat, tide alto |
| Haze | glue lento, glare bajo, −2.0 dBTP si Clarity-equivalente |
| Marbre | poco heat, aire 12 kHz, claridad nostálgica |

Mapa Haze ≈ Heavy Glue, Marbre ≈ Clarity.

**kirtan** (pads electrónicos + voz/sitar)

| Carácter | Qué hace |
|---|---|
| Aarti viva | intenso, profundo, energético; presencia de voz/sitar ~2.8 kHz; true-peak −1.11 |
| Shunya | meditación, sin enfatizar tambores; pads + sitar; HPF más alto; sin punch 40–80 Hz; true-peak −2.00 |

**Estreno** no es un género. Es un *destino* (toggle): aplica −14.00 LUFS + techo de sello. Se puede combinar con cualquier carácter.

### Frecuencias de EQ (propias; no 60/120/1k/6k/10k)

Valores en Hz. Ganancias las define cada carácter en PROMPT 04; aquí solo el esqueleto.

| Género | HPF | b1 | b2 | b3 | b4 | b5 (aire) | fang (Hz) |
|---|---|---|---|---|---|---|---|
| breakcore | 32 | 85 | 210 | 3250 | 6800 | 11000 | 3500 |
| dubstep | 25 | 48 | 120 | 800 | 2500 | 8000 | 2400 |
| vaporwave | 30 | 80 | 400 | 2000 | 6000 | 12000 | 1800 |
| kirtan Aarti viva | 35 | 90 | 250 | 2800 | 6000 | 12000 | 2800 |
| kirtan Shunya | 50 | 200 | 800 | 3500 | 8000 | 12000 | 3200 |

### Formatos de entrada

wav, aiff, flac, m4a, mp3, opus. Saltar `._*` y dotfiles. Decode con AVAudioFile / AudioToolbox; FLAC/Opus/MP3: si AVFoundation no abre, usar el binario embebido solo como *decoder*, no como FX.

### Firma (estado real de esta máquina, 2026-09-09)

No inventar certificados. Esto es lo que hay en el llavero:

```
Apple ID de desarrollador:  andresbarbudo@icloud.com
Team Name:                  Andres Barbudo-Rodriguez (Personal Team)
Team ID:                    T77VRM22PQ
Tipo:                       Personal Team  (isFreeProvisioningTeam = 1)
Identidad de codesign:      Apple Development: andresbarbudo@icloud.com (F55558HA6K)
SHA-1:                      ED97875E8F7162521F866D5863C5D712F7482F70
Subject UID:                9YTBD2Y6TZ
```

No hay certificado **Developer ID Application**.
No hay perfil `notarytool store-credentials` en el llavero.
Un Personal Team **no puede notarizar** ni firmar un `.app` para que otra Mac lo abra sin Gatekeeper de forma permanente. Los perfiles de equipo personal caducan ~7 días.

v1 se firma con `Apple Development` para correr en **esta** Mac.
PROMPT 12 se ejecuta solo si Andrei activa Apple Developer Program de pago ($99) y crea un Developer ID Application. Hasta entonces: empaquetar el `.app`, documentar “clic derecho → Abrir” en la Mac de mamá, o añadir su Mac al team.

Nunca vuelques contraseñas del llavero a un archivo.

---

## Diseño visual (minimalismo 2026)

Una columna. Mucho aire. SF Pro. Un botón primario (Procesar). Cero chrome extra.
El género pinta el tema; día/noche cambia fondos y texto.
No uses wordmarks de Monster High. Solo HEX, rebautizados.

### Tokens — breakcore ← Draculaura G1

| Rol | Noche | Día |
|---|---|---|
| bg | `#1A0A10` | `#FFF5F8` |
| primary | `#EC078B` | `#EC078B` |
| secondary | `#B02171` | `#B02171` |
| accent | `#E786B7` | `#E786B7` |
| highlight | `#F952A8` | `#F952A8` |
| text | `#FFF5F8` | `#1A0A10` |
| muted | `#7E5B70` | `#6A3953` |

### Tokens — dubstep ← Clawdeen G1

| Rol | Noche | Día |
|---|---|---|
| bg | `#1A0C10` | `#F8EFE6` |
| primary | `#5A2476` | `#5A2476` |
| secondary | `#CD793F` | `#CD793F` |
| accent | `#A184BB` | `#A184BB` |
| highlight | `#E29E8F` | `#CC7A41` |
| text | `#F8EFE6` | `#1A0C10` |
| muted | `#3F2360` | `#570D16` |

### Tokens — vaporwave ← Lagoona G1 (agua, coral, VHS)

| Rol | Noche | Día |
|---|---|---|
| bg | `#14333A` | `#E8F6F4` |
| primary | `#6DC6C7` | `#427981` |
| secondary | `#F19ABF` | `#E56B8A` |
| accent | `#FDEA9A` | `#FDEA9A` |
| highlight | `#DAEDE7` | `#6DC6C7` |
| text | `#E8F6F4` | `#14333A` |
| muted | `#5AA0A4` | `#427981` |

### Tokens — kirtan ← Cleo G1 (templo, oro, teal)

| Rol | Noche | Día |
|---|---|---|
| bg | `#140C06` | `#FBF3E4` |
| primary | `#C7913A` | `#C7913A` |
| secondary | `#25786E` | `#25786E` |
| accent | `#8FC6C8` | `#8FC6C8` |
| highlight | `#FADF92` | `#FADF92` |
| text | `#FBF3E4` | `#140C06` |
| muted | `#9D693B` | `#422717` |

Día/noche: preferir `Color.accentColor` del género + `@Environment(\.colorScheme)` y un toggle explícito “Día / Noche” que pisa el del sistema (las dos productoras lo van a querer).

Ventana de referencia (como HitmanICAMapper de este usuario): `WindowGroup` + `windowResizability(.contentSize)` + defaultSize ~960×720. Helper `Color(hex:)`.

---

## Árbol del repo (PROMPT 00 lo crea)

```
/Users/andreibarwood/Public/kuwagga/renoise/2026/emodolls_studio/
  PROMPTS_IMPLEMENTACION.md    ← este archivo
  README.md
  LICENSE                      MIT
  EmodollsStudio/
    EmodollsStudio.xcodeproj
    EmodollsStudio/
      App/EmodollsStudioApp.swift
      App/Info.plist
      App/EmodollsStudio.entitlements
      Models/
      DSP/
      Services/
      Theme/
      Views/
      Resources/               ← lame o decoder helper si se embebe
    EmodollsStudioTests/
```

Organización a propósito parecida a HitmanICAMapper para que sea cómoda en este disco.

Entitlements: sandbox ON, `com.apple.security.files.user-selected.read-write`, bookmarks de carpeta. Audio no necesita micrófono.

---

## PROMPT 00 — Scaffold Xcode + identidad

Crea el proyecto macOS SwiftUI `EmodollsStudio` bajo
`/Users/andreibarwood/Public/kuwagga/renoise/2026/emodolls_studio/EmodollsStudio/`.

- Product Name: `emodolls studio`
- Bundle ID: `studio.emodolls.app`
- Team: `T77VRM22PQ` (Andres Barbudo-Rodriguez)
- Signing: Automatic, Apple Development `andresbarbudo@icloud.com`
- Deployment: macOS 14.0, arm64 only
- SwiftUI lifecycle. Una WindowGroup.
- Entitlements de sandbox + user-selected file access.
- `Color(hex:)` helper en Theme.
- App vacía que abre una ventana “emodolls studio” con texto de bienvenida en español.
- `.gitignore` de Xcode estándar.
- No añadas DSP todavía.

Verificar: `xcodebuild -scheme EmodollsStudio -configuration Debug build` sale 0.

---

## PROMPT 01 — Modelo de dominio

Crea `Models/` con tipos explícitos, sin strings mágicos en las vistas.

```swift
enum Genre: String, CaseIterable { case breakcore, dubstep, vaporwave, kirtan }
enum CharacterID: String { /* Obsesión, Desu, Pegamento, Airi,
                              Subsoil, Drop, Molasses, Steel,
                              Mallsoft, Runway, Haze, Marbre,
                              aartiViva, shunya */ }
struct KnobIDs { let heat, bloom, fang } // labels localizados por género
enum ExportFormat { case dittopro, m4a, wav }
struct MetadataDraft { var title, artist, album, track, year, genre: String }
struct SessionLimits { static let maxTracks = 10 }
```

- Cada `Genre` expone `characters: [CharacterID]` (4, 4, 4, 2).
- Cada género expone `knobLabels: (heat:String, bloom:String, fang:String)` según la tabla.
- `ExportFormat` define extensión (`.mp3` / `.m4a` / `.wav`) y si duplica a stereo (solo dittopro).
- Tests unitarios: 4+4+4+2 caracteres; labels no contienen Drive, Push, Presence, Lurssen, T-RackS, IK.

---

## PROMPT 02 — Sistema de tema

`Theme/` con `Palette` por género × esquema.

- Tokens HEX de la tabla de este archivo, rebautizados (`Breakcore.bgNight`, etc.).
- `ThemeController`: género actual + override día/noche.
- SwiftUI: `.tint(primary)`, fondos, texto, knobs.
- Cambiar de género re-pinta toda la ventana sin recargar archivos.
- Contraste de texto sobre bg ≥ AA (los pares del atlas ya lo cumplen en noche).
- Cero nombres de personaje en símbolos públicos.

---

## PROMPT 03 — Motor DSP

`DSP/` 100 % Swift + Accelerate. Sin plugins.

Implementa, en este orden, procesando buffers mono Float32 a 44 100 Hz:

1. `MonoCollapse.mean(stereo) -> [Float]`
2. Biquad HPF
3. `TanhSaturator(heat)` con makeup para loudness aproximado constante
4. 5× peaking EQ (RBJ) cuyas ganancias se multiplican por `lerp(0.35, 1.65, bloom)`
5. Peaking `fang` (presencia)
6. Compressor (feed-forward, soft knee 3 dB, makeup)
7. High-frequency cap (detector 5–8 kHz, gain reduction suave)
8. True-peak limiter: oversample ×4, ceiling exactamente `ETPC` o `EDP`, lookahead 8 ms
9. TPDF dither a 16-bit

API:

```swift
struct RenderSettings { var genre, character, heat, bloom, fang
                        var format: ExportFormat
                        var estreno: Bool }
enum Engine {
  static func render(input: URL, settings: RenderSettings, output: URL) throws
}
```

Tests sintéticos (no hace falta oído todavía):

- Seno 0 dBFS stereo desfasado → salida mono, |L−R| = 0 si se duplica.
- True-peak de un pico calibrado termina en −1.11 ± 0.03 dBTP (WAV).
- Estreno off ⇒ no hay loudness target.
- heat=0 se oye casi lineal (THD bajo).

---

## PROMPT 04 — Recetas por carácter

Archivo `DSP/Recipes.swift`. Cada carácter es un struct de constantes (HPF, gains de las 5 bandas en dB, fang dB, ratio, attack ms, release ms, ceiling, anclas de knobs).

Anclas de knobs (0…1) al elegir el carácter — el usuario luego gira:

| Carácter | heat | bloom | fang |
|---|---|---|---|
| Obsesión / Subsoil / Mallsoft / Aarti viva | 0.48 | 0.40 | 0.44 |
| Desu / Drop / Runway | 0.62 | 0.50 | 0.55 |
| Pegamento / Molasses / Haze | 0.52 | 0.42 | 0.28 |
| Airi / Steel / Marbre / Shunya | 0.32 | 0.38 | 0.58 |

Shunya: ceiling −2.00, ratio ~1.8, HPF 50 Hz, b1 no refuerza 40–80 Hz.
Desu/Drop: attack más corto (5–8 ms). Pegamento/Molasses/Haze: ratio ~3.0, attack 15–25 ms.
Nada de números editables en UI. Cambiar de carácter carga anclas; girar knobs no cambia de carácter.

Tests: cada CharacterID tiene receta; Shunya.ceiling == -2.0; Estreno no vive en la receta.

---

## PROMPT 05 — I/O y DittoPRO

`Services/AudioIO.swift`

- FileImporter / panel nativo para archivos y carpetas.
- Decode → float32. Extensiones: wav, aiff, flac, m4a, mp3, opus. Ignorar `._*` y `.`.
- Encode:
  - wav: ExtAudioFile PCM 16-bit mono 44100
  - m4a: AudioToolbox AAC 256k mono 44100, `+faststart` equivalente (moov al inicio si se puede)
  - dittopro: LAME CBR 320, 44100, 2 ch L=R. Si no hay encoder nativo, embebe `lame` o un dylib LGPL *linkeado dinámicamente* (MIT del app + aviso LGPL en README). No pegues el source de lame dentro de archivos MIT sin el aviso.
- Nombre: `{stem}_MD.{ext}` en el espejo de carpetas.
- Metadatos del formulario → tags (ID3v2.3 en MP3, ilst en M4A; WAV BWF/iXML si es trivial, si no skip limpio).
- Tests con un wav corto sintético escrito a tmp.

---

## PROMPT 06 — Sesión, 10 temas, progreso

`Services/Session.swift` + `Processor.swift`

- Añadir archivos o una carpeta (recursivo, max 10; si hay más, avisar en español y tomar los 10 primeros por orden de path).
- Jobs: 1 (M1, estable). No ProcessPool.
- Checkbox `Sobrescribir`.
- Progress: archivo i/n + fracción 0…1. Publicar en MainActor.
- Fallos: lista `{path, mensaje}` al final; no abortar la cola.
- Cancelación cooperativa.
- Dry-run: lista destinos sin escribir (útil, un botón “Previsualizar”).

---

## PROMPT 07 — Ventana única

`Views/ContentView.swift` — español, modo avanzado único.

Layout (de arriba a abajo):

1. Título `emodolls studio`
2. Picker de género (breakcore / dubstep / vaporwave / kirtan) — cambia paleta
3. Picker de carácter (los del género)
4. Toggle Día / Noche
5. Tres knobs con **labels del género** (Yandere/Kizu/Kyun etc.)
6. Destino de formato: DittoPRO | M4A | WAV
7. Toggle **Estreno** (Apple Music, iTunes, YouTube Music, Spotify)
8. Checkbox Sobrescribir
9. Formulario metadatos (6 campos)
10. Carpeta de entrada + carpeta de salida (NSOpenPanel)
11. Lista de hasta 10 pistas (nombre)
12. Barra de progreso
13. Botón primario **Procesar**
14. Botón **Previsualizar**
15. Área de fallos

Sin menú de plugin. Sin YAML. Sin “custom”.
Atajos: ⌘O entrada, ⌘⇧O salida, ⌘↩ procesar, ⌘. cancelar.

---

## PROMPT 08 — Estreno (streaming universal)

Cuando `estreno == true`:

- Fuerza loudness −14.00 LUFS (ITU-R BS.1770-4, un pase o dos, LRA libre ~9)
- True-peak ETPC o EDP según formato
- No cambia heat/bloom/fang ni el carácter
- Copy en UI (español): “Estreno deja el master en −14 LUFS con techo emodolls, razonable en Apple Music, iTunes, YouTube Music y Spotify. Ellos igual normalizan.”

Test: tono −6 dBFS 1 kHz 5 s, Estreno on, integrado ≈ −14 ± 0.5 LUFS, TP ≤ −1.11.

---

## PROMPT 09 — Prueba de oído (v1 usable)

No hay v1 sin esto.

1. Genera o usa 4 archivos cortos (10–20 s) si no hay discografía a mano: un burst, un sub, un pad, un sitar-like. Ideal: un tema real por género si Andrei apunta carpetas.
2. Renderiza Obsesión, Subsoil, Mallsoft, Aarti viva, Shunya, más Estreno de uno de ellos.
3. Verifica con `afinfo` / un medidor:
   - WAV 44100 16-bit 1 ch
   - TP en el sello
   - sufijo `_MD`
4. Escucha en mono. Ajusta **solo recetas** (PROMPT 04) si algo aplasta transientes o ensucia el sub. No toques nombres ni UI salvo bugs.
5. Anota en este archivo, bajo ESTADO, 4 líneas de oído (una por género).

---

## PROMPT 10 — Empaquetado `.app`

- Release arm64. Destino: `dist/emodolls studio.app`
- Instrucción de uso: arrastrar a `/Applications`
- Si hay binario lame/ffmpeg, va en `Contents/Resources/` y se invoca por Bundle.main.url
- Sandbox no debe romper el encoder
- Icono: placeholder geométrico con primary breakcore `#EC078B` sobre `#1A0A10` (círculo, sin calavera de MH, sin wordmark ajeno). Se puede mejorar después.
- `xcodebuild -configuration Release` + copy a `dist/`

No notarices aquí.

---

## PROMPT 11 — README + higiene

`README.md` en español:

- Qué es (mastering true-mono, cadenas propias, 4 géneros)
- Qué no es (no es un plugin comercial, no requiere instalar nada de terceros de audio)
- Cómo abrir, límites (10 temas), formatos, sufijo `_MD`, sello −1.11 dBTP
- Licencia MIT
- Aviso LGPL si se embebe lame
- Firma: “en esta Mac, Apple Development; distribución Gatekeeper-limpia requiere Developer ID (PROMPT 12)”

Grep del repo (case insensitive) no debe encontrar: lurssen, t-racks, trakcs, ik multimedia, ozone, draculaura, clawdeen, mattel, monster high.

LICENSE MIT, copyright Andres Barbudo-Rodriguez / emodolls.

---

## PROMPT 12 — Firma y notarización (condicional)

Solo si existen **las dos** cosas:

1. Certificado `Developer ID Application: Andres Barbudo-Rodriguez (T77VRM22PQ)` (hoy NO está)
2. Credencial `notarytool` (App Store Connect API key o app-specific password). Hoy NO está. No la pidas al llavero en claro; usa `xcrun notarytool store-credentials` de forma interactiva con Andrei.

Pasos cuando existan:

```
codesign --force --options runtime --sign "Developer ID Application: …" "dist/emodolls studio.app"
ditto -c -k --keepParent "dist/emodolls studio.app" dist/emodolls-studio.zip
xcrun notarytool submit dist/emodolls-studio.zip --apple-id andresbarbudo@icloud.com --team-id T77VRM22PQ --wait
xcrun stapler staple "dist/emodolls studio.app"
```

Hasta entonces, documenta para mamá:

```
1. Arrastra emodolls studio.app a Aplicaciones
2. Primera vez: clic derecho → Abrir → Abrir
```

Si el Team sigue siendo Personal Team, no insistas: 7 días de caducidad. Dile a Andrei que el programa de pago es el único camino a un `.app` eterno.

---

## Criterio de “v1 usable”

Mamá (o Andrei) puede:

1. Abrir la app en un M1
2. Elegir género y carácter
3. Girar los tres knobs con nombres del género
4. Elegir carpeta in/out, hasta 10 temas
5. Exportar DittoPRO / M4A / WAV con `_MD`
6. Ver progreso y fallos
7. Oír un master mono que no clipa y respeta el techo de sello

No hace falta paridad con el CLI Python. Hace falta que suene a cadena de compositor, no a preset ajeno.

---

## Notas para el implementador

- Referencia de estilo Swift de este usuario: `Hitman - ICA mappers/.../HitmanICAMapper/` (Theme hex, WindowGroup, Services/). Copia la *higiene*, no el tema ICA.
- Atlas de color (privado, no se distribuye): `/Users/andreibarwood/Documents/Mega Doll/Monster_High_Complete_Color_Atlas.pdf`
- El CLI Python vive en `../01_mono_config/` y se queda. No lo borres. No lo importes.
- Prefiere Accelerate (`vDSP`, `vForce`) a loops ingenuos en buffers largos.
- Un archivo de audio grande: stream por chunks de ~3 s, con el limiter/compresor manteniendo estado.
- 16-bit es la *entrega*. El motor no cuantiza hasta el dither final.
- Si AVAudioFile no abre flac/opus, documenta el decoder embebido en PROMPT 05; no bloquees WAV/M4A/MP3 por eso.

---

## Prompt único de recuperación (si la sesión perdió el hilo)

```
Retoma emodolls studio.
Carpeta: /Users/andreibarwood/Public/kuwagga/renoise/2026/emodolls_studio/
Lee PROMPTS_IMPLEMENTACION.md, sección ESTADO.
Continúa en el primer PROMPT no marcado [x].
Respeta Prohibido y Decisiones cerradas.
Al terminar el prompt, actualiza ESTADO.
```
