import Foundation
import AppKit

// Función para crear NSColor archivado
func createArchivedColor(r: Int, g: Int, b: Int, a: Double = 1.0) -> Data {
    let color = NSColor(
        calibratedRed: CGFloat(r) / 255.0,
        green: CGFloat(g) / 255.0,
        blue: CGFloat(b) / 255.0,
        alpha: CGFloat(a)
    )
    return try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
}

// Leer preferencias actuales de Terminal
let defaults = UserDefaults(suiteName: "com.apple.Terminal")!
guard var windowSettings = defaults.dictionary(forKey: "Window Settings") else {
    print("❌ No se pudieron leer las preferencias de Terminal")
    exit(1)
}

// Obtener o crear el perfil Tank
var tank: [String: Any]

if let existingTank = windowSettings["Tank"] as? [String: Any] {
    tank = existingTank
    print("📝 Modificando perfil 'Tank' existente...")
} else if let grass = windowSettings["Grass"] as? [String: Any] {
    tank = grass
    tank["name"] = "Tank"
    print("🌿 Creando 'Tank' basado en 'Grass'...")
} else if let basic = windowSettings["Basic"] as? [String: Any] {
    tank = basic
    tank["name"] = "Tank"
    print("📄 Creando 'Tank' basado en 'Basic'...")
} else {
    print("❌ No se encontró perfil base")
    exit(1)
}

print("🎨 Configurando paleta Forest Green...")

// Paleta Forest Green - Colores principales
tank["BackgroundColor"] = createArchivedColor(r: 14, g: 28, b: 15)       // #0E1C0F
tank["TextColor"] = createArchivedColor(r: 103, g: 194, b: 148)          // #67C294
tank["TextBoldColor"] = createArchivedColor(r: 170, g: 247, b: 151)      // #AAF797
tank["CursorColor"] = createArchivedColor(r: 170, g: 247, b: 151)        // #AAF797
tank["SelectionColor"] = createArchivedColor(r: 43, g: 77, b: 51, a: 0.85) // #2B4D33

// Colores ANSI Normal
tank["ANSIBlackColor"] = createArchivedColor(r: 14, g: 28, b: 15)        // #0E1C0F
tank["ANSIRedColor"] = createArchivedColor(r: 62, g: 115, b: 82)         // #3E7352
tank["ANSIGreenColor"] = createArchivedColor(r: 103, g: 194, b: 148)     // #67C294
tank["ANSIYellowColor"] = createArchivedColor(r: 220, g: 255, b: 147)    // #DCFF93
tank["ANSIBlueColor"] = createArchivedColor(r: 82, g: 155, b: 111)       // #529B6F
tank["ANSIMagentaColor"] = createArchivedColor(r: 103, g: 194, b: 148)   // #67C294
tank["ANSICyanColor"] = createArchivedColor(r: 170, g: 247, b: 151)      // #AAF797
tank["ANSIWhiteColor"] = createArchivedColor(r: 170, g: 247, b: 151)     // #AAF797

// Colores ANSI Bright
tank["ANSIBrightBlackColor"] = createArchivedColor(r: 43, g: 77, b: 51)      // #2B4D33
tank["ANSIBrightRedColor"] = createArchivedColor(r: 103, g: 194, b: 148)     // #67C294
tank["ANSIBrightGreenColor"] = createArchivedColor(r: 170, g: 247, b: 151)   // #AAF797
tank["ANSIBrightYellowColor"] = createArchivedColor(r: 220, g: 255, b: 147)  // #DCFF93
tank["ANSIBrightBlueColor"] = createArchivedColor(r: 103, g: 194, b: 148)    // #67C294
tank["ANSIBrightMagentaColor"] = createArchivedColor(r: 170, g: 247, b: 151) // #AAF797
tank["ANSIBrightCyanColor"] = createArchivedColor(r: 220, g: 255, b: 147)    // #DCFF93
tank["ANSIBrightWhiteColor"] = createArchivedColor(r: 220, g: 255, b: 147)   // #DCFF93

// Guardar cambios
windowSettings["Tank"] = tank
defaults.set(windowSettings, forKey: "Window Settings")

// Establecer como perfil por defecto
defaults.set("Tank", forKey: "Default Window Settings")
defaults.set("Tank", forKey: "Startup Window Settings")

defaults.synchronize()

print("")
print("✅ Perfil 'Tank' configurado con paleta Forest Green")
print("✅ Establecido como perfil por defecto")
print("")
print("╔════════════════════════════════════════════════════════╗")
print("║  🔄 CIERRA Y VUELVE A ABRIR Terminal.app              ║")
print("║     para ver los cambios                              ║")
print("╚════════════════════════════════════════════════════════╝")
