# 🎮 ICA Controller Mapper — Hitman: Codename 47

Juega el clásico del sigilo **con mando (gamepad)** como si fuera teclado y ratón.  
Briefings por misión, ajustes en vivo y estética ICA.

**No necesitas saber programar.** Solo seguir estos pasos.

---

## ✅ Qué necesitas

- PC con **Windows 10/11** o **macOS**
- **Python 3.10+** (gratis, instalación en 2 minutos)
- Un **mando** (EasySMX X15, Xbox, o similar)
- Copia de **Hitman: Codename 47**

---

## 📥 Paso 1 — Descargar este proyecto

**Opción A (recomendada):** clona el repo con Git.

**Opción B:** en GitHub, pulsa **Code → Download ZIP**, descomprime y entra en esta carpeta:

`Hitman - ICA mappers/01 - Codename 47`

---

## 🐍 Paso 2 — Instalar Python (solo la primera vez)

### Windows

1. Ve a [python.org/downloads](https://www.python.org/downloads/)
2. Descarga **Python 3.12** (o superior)
3. Al instalar, marca ✅ **“Add Python to PATH”**
4. Pulsa **Install Now**

### macOS

1. Abre **Terminal** (Cmd + Espacio → escribe “Terminal”)
2. Si tienes Homebrew:
   ```bash
   brew install python@3.12
   ```
3. Si no tienes Homebrew, instala Python desde [python.org/downloads](https://www.python.org/downloads/)

**Comprueba que funciona:**

```bash
python --version
```

(o en Mac: `python3 --version`)

Deberías ver algo como `Python 3.12.x`.

---

## 📦 Paso 3 — Instalar dependencias del mapper

Abre **Terminal** (Mac) o **CMD / PowerShell** (Windows) y ejecuta:

### Windows

```bash
cd "ruta\a\kuwagga\Hitman - ICA mappers\01 - Codename 47"
python -m pip install -r requirements.txt
```

### macOS

```bash
cd "/ruta/a/kuwagga/Hitman - ICA mappers/01 - Codename 47"
pip3 install -r requirements.txt
```

> 💡 **Tip gamer:** esto descarga 3 librerías (`customtkinter`, `pygame`, `pynput`).  
> Es como instalar un mod: una vez y listo.

---

## 🔐 Paso 4 — Permisos (importante)

El mapper simula teclado y ratón. Sin permisos, el mando se detecta pero el juego no recibe inputs.

### Windows

- Ejecuta Terminal/CMD **como administrador** si el juego no responde
- Algunos antivirus pueden bloquear `pynput`: añade una excepción si hace falta

### macOS

1. **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**
2. Activa el permiso para **Terminal** (o **Python** / tu IDE)
3. Reinicia el mapper si ya estaba abierto

---

## 🕹️ Paso 5 — Conectar el mando y lanzar el mapper

1. **Conecta el gamepad** (USB o Bluetooth)
2. En la misma carpeta del proyecto, ejecuta:

### Windows

```bash
python hitman_ica_controller_mapper.py
```

### macOS

```bash
python3 hitman_ica_controller_mapper.py
```

3. Se abrirá la ventana **ICA // Codename 47 Controller Mapper**

---

## 🎯 Paso 6 — Jugar (orden correcto)

1. En el mapper, elige tu **misión** en el desplegable
2. Lee el **briefing** y las recomendaciones de mando
3. Ajusta **sensibilidad**, **deadzone** y **umbral de correr** si quieres
4. Pulsa **▶ INICIAR MAPPER**
5. **Después** abre Hitman: Codename 47
6. Juega con el mando como si fuera teclado + ratón

Para parar: pulsa **■ DETENER MAPPER** o cierra la ventana.

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
| “No se detectó ningún control” | Conecta el mando antes de iniciar el mapper |
| El juego no responde al mando | Revisa permisos (Paso 4) e inicia el mapper **antes** del juego |
| `python` no se reconoce (Windows) | Reinstala Python con **Add to PATH** marcado |
| `pip` no funciona | Usa `python -m pip install -r requirements.txt` |
| Movimiento del ratón muy rápido/lento | Baja o sube **Sensibilidad ratón** en la app |

---

## 🏷️ Tags

`Hitman` `Codename 47` `Agent 47` `ICA` `gamepad` `controller mapper` `retro gaming` `stealth` `Python` `customtkinter`

---

*Buena caza, 47.* 🕵️