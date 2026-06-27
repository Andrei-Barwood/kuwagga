# 🕵️ ICA Controller Mapper — Hitman: Codename 47 (macOS Swift)

**Versión nativa para macOS** escrita en Swift + SwiftUI.  
✅ Interfaz **responsive** + **remapeo completo de controles** del juego.

Esta es la aplicación **recomendada** para usuarios de **Mac**.  
La versión Python se mantiene **solo para Windows**.

---

## ✨ Novedades

- 🎨 Interfaz completamente **responsive** (se adapta al redimensionar la ventana)
- 🎮 **Lista oficial de controles** del juego (extraída de `keybindings_WASD.pdf` + `manual.pdf`)
- 🔧 **Remapeo total**: asigna cualquier acción del juego a cualquier botón de tu mando
- 🕹️ Soporte especial para usar **D-Pad como puntero** o sticks para navegación
- 🚀 Proyecto listo con `.xcodeproj` incluido
- 📦 App precompilada incluida

---

## ✅ Requisitos

- **macOS 13 Ventura** o superior (recomendado Sonoma/Sequoia)
- Un mando compatible (Xbox, EasySMX X15, PlayStation, etc.)
- Hitman: Codename 47 instalado (normalmente vía **Porting Kit** + GOG)

---

## 🚀 Inicio rápido

### Opción 1: Usar la app ya compilada

1. Abre directamente:
   ```bash
   open "01 - Codename 47 (macOS Swift)/HitmanICAMapper.app"
   ```
2. La primera vez te pedirá permisos.

### Opción 2: Abrir en Xcode

```bash
open "01 - Codename 47 (macOS Swift)/HitmanICAMapper.xcodeproj"
```

Presiona **Cmd + R** para compilar y ejecutar.

---

## 🔐 Permisos obligatorios

Para simular ratón y teclado necesitas:

### Accesibilidad
**Ajustes del Sistema → Privacidad y seguridad → Accesibilidad** → Activa la app.

### Input Monitoring
**Ajustes del Sistema → Privacidad y seguridad → Input Monitoring** → Activa la app.

> Sin estos permisos el mando se detecta pero **no envía inputs** al juego.

---

## 🔐 Permisos obligatorios (muy importante)

Para que el mapper pueda controlar el ratón y el teclado necesitas dar dos permisos:

### Accesibilidad
1. Abre **Ajustes del Sistema → Privacidad y seguridad → Accesibilidad**
2. Añade y activa `HitmanICAMapper` (o Xcode mientras desarrollas)

### Input Monitoring
1. Ve a **Privacidad y seguridad → Input Monitoring**
2. Añade y activa la app

> Sin estos permisos el mando se detecta pero el juego no recibe ningún input.

---

## 🎮 Cómo usar

1. (Recomendado) Ejecuta el setup del juego:
   ```bash
   cd ~/Documents/kuwagga/Hitman\ -\ ICA\ mappers
   ./01_setup_Codename47_macos.sh
   ```

2. Abre **HitmanICAMapper.app** o compila desde Xcode.

3. Selecciona la misión y lee el briefing.

4. **Configura tus controles** (lo más potente):
   - En **Configuración de Controles** verás la lista completa de acciones del juego.
   - Asigna cualquier acción a cualquier botón de tu mando.
   - Ejemplos útiles:
     - D-Pad → Flechas (controlar puntero con cruceta)
     - Stick derecho → Flechas o cualquier otra acción
     - Botones sobrantes → Mapa (M), F1, F2, etc.

5. Ajusta sensibilidad, deadzones y umbral de correr.

6. Pulsa **▶ INICIAR MAPPER**

7. Abre Hitman: Codename 47 y ¡a cazar!

Para parar: **■ DETENER MAPPER** o cierra la ventana.

---

## 🗺️ Controles por defecto (fáciles de cambiar)

| Entrada del mando       | Acción por defecto             |
|-------------------------|--------------------------------|
| A / RT                  | Click Izquierdo (Disparar)     |
| B                       | Click Derecho                  |
| X                       | Recargar (R)                   |
| Y                       | Soltar arma (G)                |
| LB / RB                 | Inclinarse Izq / Der (Q/E)     |
| Stick Izquierdo         | Movimiento WASD + Shift        |
| Stick Derecho           | Mirar con ratón                |
| D-Pad                   | Flechas de navegación          |
| Back                    | Esc (Menú)                     |
| Start                   | Enter                          |

---

## 🛠️ Características técnicas

- **Framework nativo**: GameController + CoreGraphics
- **UI responsive**: Se adapta perfectamente al tamaño de ventana
- **Remapeo completo**: Más de 15 acciones del juego asignables
- **Calibración anti-drift** del stick derecho
- **Sin dependencias**: No requiere Python

---

## 📁 Estructura del proyecto

```
01 - Codename 47 (macOS Swift)/
├── HitmanICAMapper.xcodeproj/     ← Ábrelo directamente
├── HitmanICAMapper/               ← Fuentes
│   ├── HitmanICAMapperApp.swift
│   ├── Models/                    ← GameAction, ControllerInput...
│   ├── Services/                  ← Lógica del mapper
│   └── Views/                     ← ContentView + RemappingView
├── HitmanICAMapper.app            ← App ya compilada
└── README.md
```

---

Buena caza, 47. 🕵️‍♂️🔫
```

---

*Proyecto actualizado con interfaz responsive y sistema de remapeo completo.*
