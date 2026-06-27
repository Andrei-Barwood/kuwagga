import Foundation

// Represents a single controller button mapping (face buttons + shoulders + menu)
struct ButtonMapping: Identifiable {
    let id = UUID()
    let name: String          // "A", "B", "X", "Y", "LB", etc.
    let action: String        // Human readable action
}

// Base controller mappings (Xbox / EasySMX X15 style) - exact port from Python
let baseButtonMappings: [ButtonMapping] = [
    ButtonMapping(name: "A (Btn 0)",      action: "Click Izquierdo (Disparar / Interactuar)"),
    ButtonMapping(name: "B (Btn 1)",      action: "Click Derecho (Menú de acciones)"),
    ButtonMapping(name: "X (Btn 2)",      action: "Recargar (r)"),
    ButtonMapping(name: "Y (Btn 3)",      action: "Tirar arma (g)"),
    ButtonMapping(name: "LB (Btn 4)",     action: "Inclinarse Izquierda (q)"),
    ButtonMapping(name: "RB (Btn 5)",     action: "Inclinarse Derecha (e)"),
    ButtonMapping(name: "Back (Btn 6)",   action: "Menú / Pausa (Esc)"),
    ButtonMapping(name: "Start (Btn 7)",  action: "Aceptar / Continuar (Enter)"),
]

// Default settings (matching Python defaults)
struct MapperSettings: Equatable {
    var sensitivity: Double = 25          // mouse look multiplier
    var deadzone: Double = 0.20           // left stick movement deadzone
    var lookDeadzone: Double = 0.18       // right stick look deadzone
    var runThreshold: Double = 0.85       // how far forward on left stick to press Shift
}
