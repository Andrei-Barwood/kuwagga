# 🖥️ Terminal Styles

Aplicación nativa de **macOS** (SwiftUI) para previsualizar e instalar temas de color personalizados en **Terminal.app**.

Binario universal: **Intel** + **Apple Silicon** · Optimizada para **macOS Sequoia 15+**

---

## 📦 Descargar y ejecutar (sin compilar)

### Paso 1 — Descarga el binario

Obtén el `.zip` desde la sección **Releases** del repositorio:

👉 **[github.com/Andrei-Barwood/kuwagga/releases](https://github.com/Andrei-Barwood/kuwagga/releases)**

Archivo: `Terminal-Styles-v1.0-macOS-universal.zip`

También disponible en: `releases/Terminal-Styles-v1.0-macOS-universal.zip` (raíz del repo).

### Paso 2 — Descomprime

```bash
cd ~/Downloads
unzip Terminal-Styles-v1.0-macOS-universal.zip
```

Obtendrás `Terminal Styles.app`.

### Paso 3 — Abre la aplicación

```bash
open "Terminal Styles.app"
```

> ⚠️ **Primera ejecución:** macOS puede mostrar *"no se puede abrir porque proviene de un desarrollador no identificado"*.
>
> Solución: **Ajustes del Sistema → Privacidad y seguridad → Abrir de todas formas**
>
> O clic derecho sobre la app → **Abrir** → confirmar.

### Paso 4 — Instala un tema en Terminal

1. 🎨 Selecciona un tema en la **barra lateral** (Remar Nocturna, Somos Rich, Limonada Triple, Shemel Krass).
2. 👀 Revisa la **vista previa** con prompt zsh y colores ANSI.
3. ☑️ (Opcional) Marca **Establecer como perfil predeterminado de Terminal**.
4. 🚀 Pulsa **Instalar Tema en Terminal**.
5. ✅ Terminal.app se abrirá e importará el perfil en **Terminal → Ajustes → Perfiles**.

---

## 🛠️ Compilar desde el código fuente

### Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| 🍎 macOS | Sequoia 15.0+ |
| 🔨 Xcode | 16+ |
| 🧰 Swift | 5.9+ |

### Paso 1 — Clona el repositorio

```bash
git clone https://github.com/Andrei-Barwood/kuwagga.git
cd kuwagga/"Terminal Styles"
```

### Paso 2 — Compila con el script incluido

```bash
chmod +x Scripts/build.sh
./Scripts/build.sh
```

Esto:
- 🎨 Regenera los iconos de la app
- ⚙️ Compila binario universal (`arm64` + `x86_64`)
- 📁 Copia el resultado a `dist/Terminal Styles.app`

### Paso 3 — Ejecuta tu build local

```bash
open "dist/Terminal Styles.app"
```

### Alternativa: abrir en Xcode

```bash
open TerminalStyles.xcodeproj
```

Luego **Product → Run** (`⌘R`).

Para release universal desde Xcode:

```bash
xcodebuild -project TerminalStyles.xcodeproj \
  -scheme "Terminal Styles" \
  -configuration Release \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  clean build
```

---

## 🎨 Temas incluidos

| Tema | Colores |
|------|---------|
| 🌙 Remar Nocturna | 21 |
| 💜 Somos Rich | 15 |
| 🍋 Limonada Triple | 15 |
| ✨ Shemel Krass | 11 |

### Lógica de mapeo

| Índice | Destino |
|--------|---------|
| 0 | `BackgroundColor` |
| 1 | `TextColor` |
| 2 | `CursorColor` |
| 3…18 | 16 colores ANSI |
| 19 | `TextBoldColor` (si existe) |
| 20 | `SelectionColor` (si existe) |

Paleta corta → los slots ANSI restantes reutilizan colores cíclicamente.

---

## 📂 Estructura del proyecto

```
Terminal Styles/
├── TerminalStyles.xcodeproj
├── TerminalStyles/
│   ├── TerminalStylesApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   ├── Services/
│   └── Views/
├── Scripts/
│   ├── build.sh
│   └── generate_app_icon.swift
└── dist/                  # generado localmente (no versionado)
```

---

## 🔧 Scripts útiles

```bash
# Regenerar solo los iconos
./Scripts/generate_app_icon.swift

# Build completo
./Scripts/build.sh
```

---

## 📄 Licencia

Parte del repositorio [kuwagga](https://github.com/Andrei-Barwood/kuwagga) de Andrei Barwood.