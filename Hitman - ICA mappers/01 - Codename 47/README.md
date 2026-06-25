# 🎮 ICA Controller Mapper — Hitman: Codename 47

Juega el clásico del sigilo **con mando (gamepad)** como si fuera teclado y ratón.  
Briefings por misión, ajustes en vivo y estética ICA.

**No necesitas saber programar.** Solo seguir estos pasos en orden.

---

## 🏛️ ¿Por qué necesitas un setup extra?

**Hitman: Codename 47** (2000) no es un juego cualquiera: es un **clásico de clásicos**, un **hit de hits** y el **señor de señores** entre los videojuegos de sigilo retro. Pero fue diseñado para PCs y GPUs de hace más de 25 años.

En **equipos modernos** (Windows 11, Mac con Apple Silicon, pantallas 4K, drivers actuales) suele fallar:

- **Pantalla negra** al iniciar
- Resoluciones que el motor no entiende
- Modo pantalla completa incompatible con monitores actuales
- Comportamiento errático en capas de emulación (Wine / Porting Kit en Mac)

Por eso este repo incluye dos scripts de configuración que **debes ejecutar una vez** (o cada vez que reinstales el juego) **antes de jugar**:

| Sistema | Script |
|---------|--------|
| 🍎 macOS | `01_setup_Codename47_macos.sh` |
| 🪟 Windows | `01_setup_Codename47_win.ps1` |

Ambos parchean `Hitman.ini` con **1280×720 en modo ventana** — el combo más estable en hardware moderno. **No tocan los controles**: para eso está el mapper.

---

## ✅ Qué necesitas

- PC con **Windows 10/11** o **macOS**
- **Copia legal** de Hitman: Codename 47 (GOG recomendado; Steam también)
- En Mac: instalación vía **Porting Kit** o similar (Wine)
- **Python 3.10+** para el mapper
- Un **mando** (EasySMX X15, Xbox, o similar)

---

## 📥 Paso 1 — Descargar este proyecto

**Opción A (recomendada):** clona el repo con Git.

**Opción B:** en GitHub, pulsa **Code → Download ZIP**, descomprime y localiza estas carpetas:

```
kuwagga/
└── Hitman - ICA mappers/
    ├── 01_setup_Codename47_macos.sh    ← setup Mac (ejecutar ANTES del juego)
    ├── 01_setup_Codename47_win.ps1     ← setup Windows (ejecutar ANTES del juego)
    └── 01 - Codename 47/
        ├── hitman_ica_controller_mapper.py
        └── requirements.txt
```

---

## 🛠️ Paso 2 — Configurar el juego en PC moderno (OBLIGATORIO)

> ⚠️ **Haz esto antes de abrir el juego por primera vez** (o si ves pantalla negra).

### 🍎 macOS — `01_setup_Codename47_macos.sh`

**Requisito previo:** tener Hitman: Codename 47 instalado (típicamente vía **Porting Kit** + GOG) como `Hitman Codename 47.app` en `Applications`.

1. Abre **Terminal** (Cmd + Espacio → escribe `Terminal`)
2. Ve a la carpeta del repo:
   ```bash
   cd "/ruta/a/kuwagga/Hitman - ICA mappers"
   ```
3. Dale permiso de ejecución (solo la primera vez):
   ```bash
   chmod +x 01_setup_Codename47_macos.sh
   ```
4. Ejecuta el script:
   ```bash
   ./01_setup_Codename47_macos.sh
   ```
5. Deberías ver:
   - `✅ Juego encontrado. Aplicando parche de pantalla negra (1280x720 + Window)...`
   - `🎉 ¡Parche visual aplicado!`

**¿Qué hace?** Busca tu instalación en `~/Applications` o `/Applications`, localiza `Hitman.ini` dentro del prefix de Wine y fuerza resolución **1280×720** + **modo ventana**.

**Si falla con “No se encontró la instalación”:**
- Confirma que el `.app` se llama exactamente `Hitman Codename 47.app`
- Si está en otra ruta, abre el script con un editor y ajusta la búsqueda, o mueve el juego a `Applications`

---

### 🪟 Windows — `01_setup_Codename47_win.ps1`

**Requisito previo:** Hitman: Codename 47 instalado por **GOG** o **Steam** en una ruta estándar.

1. Clic derecho en **Inicio** → **Terminal (Windows)** o **Windows PowerShell**
2. Ve a la carpeta del repo:
   ```powershell
   cd "C:\ruta\a\kuwagga\Hitman - ICA mappers"
   ```
3. Si Windows bloquea scripts, permite solo esta sesión:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. Ejecuta el setup:
   ```powershell
   .\01_setup_Codename47_win.ps1
   ```
5. Deberías ver:
   - `✅ Juego encontrado en C:\... Aplicando parche de pantalla negra...`
   - `🎉 ¡Parche visual aplicado!`
6. Pulsa una tecla cuando diga `Pause` para cerrar

**¿Qué hace?** Busca el juego en:
- `C:\GOG Games\Hitman Codename 47`
- `C:\Program Files (x86)\GOG Galaxy\Games\Hitman Codename 47`
- `C:\Program Files (x86)\Steam\steamapps\common\Hitman Codename 47`

y aplica el mismo parche a `Hitman.ini`.

**Si falla con “No se encontró la instalación”:**
- Localiza tu carpeta del juego manualmente
- Edita `$possiblePaths` al inicio del `.ps1` y añade tu ruta
- Vuelve a ejecutar el script

---

### ✅ Comprueba que el parche funcionó

1. Abre **Hitman: Codename 47**
2. Debe arrancar en **ventana 1280×720** sin pantalla negra
3. Si sigue en negro, ejecuta el setup otra vez y confirma que `Hitman.ini` contiene:
   ```
   Resolution 1280x720
   Window
   ```

---

## 🐍 Paso 3 — Instalar Python (solo la primera vez, para el mapper)

### Windows

1. Ve a [python.org/downloads](https://www.python.org/downloads/)
2. Descarga **Python 3.12** (o superior)
3. Al instalar, marca ✅ **“Add Python to PATH”**
4. Pulsa **Install Now**

### macOS

1. Abre **Terminal**
2. Con Homebrew:
   ```bash
   brew install python@3.12
   ```
3. Sin Homebrew: instala desde [python.org/downloads](https://www.python.org/downloads/)

**Comprueba:**

```bash
python --version
```

(o en Mac: `python3 --version`)

---

## 📦 Paso 4 — Instalar dependencias del mapper

### Windows

```bash
cd "C:\ruta\a\kuwagga\Hitman - ICA mappers\01 - Codename 47"
python -m pip install -r requirements.txt
```

### macOS

```bash
cd "/ruta/a/kuwagga/Hitman - ICA mappers/01 - Codename 47"
pip3 install -r requirements.txt
```

> 💡 Descarga 3 librerías (`customtkinter`, `pygame`, `pynput`). Una vez instaladas, no hace falta repetir.

---

## 🔐 Paso 5 — Permisos del mapper (importante)

El mapper simula teclado y ratón. Sin permisos, el mando se detecta pero el juego no recibe inputs.

### Windows

- Ejecuta Terminal **como administrador** si el juego no responde
- Algunos antivirus bloquean `pynput`: añade excepción si hace falta

### macOS

1. **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**
2. Activa el permiso para **Terminal** (o **Python**)
3. Reinicia el mapper si ya estaba abierto

---

## 🕹️ Paso 6 — Conectar el mando y lanzar el mapper

1. **Conecta el gamepad** (USB o Bluetooth)
2. Ejecuta:

### Windows

```bash
cd "C:\ruta\a\kuwagga\Hitman - ICA mappers\01 - Codename 47"
python hitman_ica_controller_mapper.py
```

### macOS

```bash
cd "/ruta/a/kuwagga/Hitman - ICA mappers/01 - Codename 47"
python3 hitman_ica_controller_mapper.py
```

3. Se abre la ventana **ICA // Codename 47 Controller Mapper**

---

## 🎯 Paso 7 — Orden correcto para jugar

Sigue esta secuencia **siempre**:

```
1. Ejecutar setup_codename (Paso 2)     ← solo si es primera vez o pantalla negra
2. Abrir el ICA Controller Mapper
3. Elegir misión y leer briefing
4. Ajustar sensibilidad / deadzone
5. Pulsar ▶ INICIAR MAPPER
6. Abrir Hitman: Codename 47
7. Jugar con el mando
```

Para parar: **■ DETENER MAPPER** o cierra la ventana del mapper.

---

## 🗺️ Misiones incluidas (10)

| Arco | Misiones |
|------|----------|
| 🇭🇰 Hong Kong | Kowloon Triads, Wang Fou, Cheung Chau, Lee Hong |
| 🇨🇴 Colombia | Find the U'wa Tribe, The Jungle God, Say Hello to My Little Friend |
| 🇭🇺 Hungría | Traditions of the Trade |
| 🇳🇱 Rotterdam | Gunrunner's Paradise, Plutonium Runs Loose |

Cada misión trae briefing en español + estilo de juego recomendado (sniper, sigilo, asalto…).

---

## 🎮 Mapeo del mando (layout Xbox / EasySMX X15)

| Botón | Acción |
|-------|--------|
| Stick izquierdo | Movimiento (WASD) |
| Stick derecho | Mirar (ratón) |
| RT (gatillo derecho) | Disparar (click izquierdo) |
| A | Click izquierdo / Interactuar |
| B | Click derecho |
| X | Recargar (R) |
| Y | Tirar arma (G) |
| LB / RB | Inclinarse (Q / E) |
| Stick adelante fuerte | Correr (Shift) |
| D-Pad | Flechas |
| Back | Esc |
| Start | Enter |

---

## ❓ Problemas frecuentes

| Problema | Solución |
|----------|----------|
| Pantalla negra al abrir el juego | Ejecuta `01_setup_Codename47_macos.sh` o `01_setup_Codename47_win.ps1` |
| El juego no arranca en Mac | Confirma instalación con Porting Kit; el `.app` debe estar en `Applications` |
| Setup no encuentra el juego | Verifica ruta de instalación; edita el script si está en carpeta custom |
| “No se detectó ningún control” | Conecta el mando antes de iniciar el mapper |
| El juego no responde al mando | Revisa permisos (Paso 5); inicia el mapper **antes** del juego |
| `python` no se reconoce (Windows) | Reinstala Python con **Add to PATH** marcado |
| Movimiento del ratón muy rápido/lento | Ajusta **Sensibilidad ratón** en la app |

---

## 🏷️ Tags

`Hitman` `Codename 47` `Agent 47` `ICA` `retro gaming` `classic games` `gamepad` `controller mapper` `GOG` `Porting Kit` `stealth` `Python`

---

*Buena caza, 47.* 🕵️