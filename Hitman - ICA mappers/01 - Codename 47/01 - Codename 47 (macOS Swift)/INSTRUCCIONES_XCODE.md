# Instrucciones rápidas para Xcode

## Crear el proyecto desde cero

1. Abre Xcode.
2. **File → New → Project**
3. Selecciona:
   - macOS → App
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Organization identifier: lo que quieras (ej: `com.ica`)
4. Nombre: `HitmanICAMapper` (recomendado)
5. Ubicación: puedes guardarlo dentro de `01 - Codename 47 (macOS Swift)/`

## Reemplazar archivos

Borra los archivos por defecto que crea Xcode:
- `HitmanICAMapperApp.swift`
- `ContentView.swift`
- Assets.xcassets (puedes mantenerlo y solo reemplazar contenidos)

Copia todo lo que hay en esta carpeta `HitmanICAMapper/` al proyecto.

Estructura final esperada dentro del proyecto:

```
HitmanICAMapper/
├── HitmanICAMapperApp.swift
├── Theme.swift
├── Models/
│   ├── Mission.swift
│   └── Mapping.swift
├── Services/
│   └── ControllerMapper.swift
├── Views/
│   └── ContentView.swift
└── Assets.xcassets/
```

## Configuración recomendada

- Ve al target → **General**:
  - Deployment Target: macOS 13.0 o superior
- **Signing & Capabilities**:
  - Activa **Hardened Runtime**

## Probar

1. Compila (Cmd+B)
2. Ejecuta (Cmd+R)
3. Conecta un mando antes de pulsar INICIAR MAPPER
4. La primera vez que pulses INICIAR MAPPER te pedirá permisos.

## Si no compila

Asegúrate de que todos los archivos están añadidos al target (clic derecho → Add to Target).

## Icono

Puedes generar un icono y arrastrarlo a `AppIcon` en Assets.

---

¡Listo! La app debería comportarse igual que la versión Python pero de forma nativa.
