import Foundation
import CoreGraphics

/// Represents a game action that can be triggered by the controller.
/// Includes both high-level descriptions and exactly what it simulates.
struct GameAction: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let description: String
    let category: ActionCategory

    // What actually gets sent when this action is activated
    let simulation: Simulation

    enum ActionCategory: String, Codable, CaseIterable {
        case movement = "Movimiento"
        case combat = "Combate"
        case interaction = "Interacción"
        case ui = "Interfaz / Menús"
        case misc = "Otros"
    }

    enum Simulation: Codable, Hashable {
        case key(CGKeyCodeValue)
        case mouseLeft
        case mouseRight
        case mouseLook   // special: consumes right stick axes
        case movement    // special: consumes left stick + run
        case none
    }
}

// We use a simple raw value wrapper so we can Codable CGKeyCodes easily
struct CGKeyCodeValue: Codable, Hashable {
    let raw: UInt16

    var keyCode: CGKeyCode { CGKeyCode(raw) }
}

// All available actions the user can assign to controller inputs.
// This list is based on the official keybindings_WASD.pdf + manual.pdf included with the game.
let availableGameActions: [GameAction] = [
    // Movement
    GameAction(id: "move_forward", displayName: "Avanzar (W)", description: "Mover hacia adelante", category: .movement, simulation: .key(.w)),
    GameAction(id: "move_backward", displayName: "Retroceder (S)", description: "Mover hacia atrás", category: .movement, simulation: .key(.s)),
    GameAction(id: "strafe_left", displayName: "Esquivar Izquierda (A)", description: "Mover a la izquierda (strafe)", category: .movement, simulation: .key(.a)),
    GameAction(id: "strafe_right", displayName: "Esquivar Derecha (D)", description: "Mover a la derecha (strafe)", category: .movement, simulation: .key(.d)),
    GameAction(id: "run", displayName: "Correr (Shift)", description: "Correr (mantener)", category: .movement, simulation: .key(.shift)),
    GameAction(id: "lean_left", displayName: "Inclinarse Izquierda (Q)", description: "Asomarse por la izquierda", category: .movement, simulation: .key(.q)),
    GameAction(id: "lean_right", displayName: "Inclinarse Derecha (E)", description: "Asomarse por la derecha", category: .movement, simulation: .key(.e)),

    // Combat
    GameAction(id: "fire", displayName: "Disparar / Usar (Click Izq)", description: "Disparar arma o interactuar con objetos", category: .combat, simulation: .mouseLeft),
    GameAction(id: "alternate", displayName: "Acción Secundaria (Click Der)", description: "Click derecho (menú contextual o acción secundaria)", category: .combat, simulation: .mouseRight),
    GameAction(id: "reload", displayName: "Recargar (R)", description: "Recargar el arma", category: .combat, simulation: .key(.r)),
    GameAction(id: "drop_weapon", displayName: "Soltar Arma (G)", description: "Tirar el arma o objeto actual", category: .combat, simulation: .key(.g)),

    // Interaction
    GameAction(id: "interact", displayName: "Interactuar (Click Izq)", description: "Usar / Abrir / Coger", category: .interaction, simulation: .mouseLeft),

    // UI / Menus
    GameAction(id: "menu", displayName: "Menú / Pausa (Esc)", description: "Abrir menú de opciones o pausar", category: .ui, simulation: .key(.escape)),
    GameAction(id: "confirm", displayName: "Aceptar (Enter)", description: "Confirmar selección en menús", category: .ui, simulation: .key(.enter)),
    GameAction(id: "map", displayName: "Mapa (M)", description: "Abrir el mapa de la misión", category: .ui, simulation: .key(.m)),
    GameAction(id: "laptop", displayName: "Portátil de la Misión (F1)", description: "Abrir información de la misión", category: .ui, simulation: .key(.f1)),
    GameAction(id: "status", displayName: "Estado de la Misión (F2)", description: "Ver estado / objetivos", category: .ui, simulation: .key(.f2)),
    GameAction(id: "arrow_up", displayName: "Flecha Arriba", description: "Navegación en menús", category: .ui, simulation: .key(.up)),
    GameAction(id: "arrow_down", displayName: "Flecha Abajo", description: "Navegación en menús", category: .ui, simulation: .key(.down)),
    GameAction(id: "arrow_left", displayName: "Flecha Izquierda", description: "Navegación en menús o girar", category: .ui, simulation: .key(.left)),
    GameAction(id: "arrow_right", displayName: "Flecha Derecha", description: "Navegación en menús o girar", category: .ui, simulation: .key(.right)),

    // Special behaviors (axis consumers)
    GameAction(id: "mouse_look", displayName: "Mirar con Ratón", description: "Control de cámara con stick derecho (recomendado)", category: .movement, simulation: .mouseLook),
    GameAction(id: "movement", displayName: "Movimiento (WASD + Correr)", description: "Control de movimiento con stick izquierdo", category: .movement, simulation: .movement),
]

// Default / sensible starting profile (similar to previous hardcoded behavior)
let defaultActionForInput: [String: String] = [
    "buttonA": "fire",
    "buttonB": "alternate",
    "buttonX": "reload",
    "buttonY": "drop_weapon",
    "leftShoulder": "lean_left",
    "rightShoulder": "lean_right",
    "buttonOptions": "menu",      // Back
    "buttonMenu": "confirm",      // Start
    "dpadUp": "arrow_up",
    "dpadDown": "arrow_down",
    "dpadLeft": "arrow_left",
    "dpadRight": "arrow_right",
    "rightTrigger": "fire",
    "leftTrigger": "alternate",
    "leftStick": "movement",
    "rightStick": "mouse_look",
]

// Helper to resolve id → GameAction
extension GameAction {
    static func action(for id: String) -> GameAction? {
        availableGameActions.first { $0.id == id }
    }
}

// Convenience CGKeyCode constants
extension CGKeyCodeValue {
    static let w = CGKeyCodeValue(raw: 13)
    static let a = CGKeyCodeValue(raw: 0)
    static let s = CGKeyCodeValue(raw: 1)
    static let d = CGKeyCodeValue(raw: 2)
    static let r = CGKeyCodeValue(raw: 15)
    static let g = CGKeyCodeValue(raw: 5)
    static let q = CGKeyCodeValue(raw: 12)
    static let e = CGKeyCodeValue(raw: 14)
    static let m = CGKeyCodeValue(raw: 46)

    static let shift = CGKeyCodeValue(raw: 56)
    static let escape = CGKeyCodeValue(raw: 53)
    static let enter = CGKeyCodeValue(raw: 36)

    static let f1 = CGKeyCodeValue(raw: 122)
    static let f2 = CGKeyCodeValue(raw: 120)

    static let up = CGKeyCodeValue(raw: 126)
    static let down = CGKeyCodeValue(raw: 125)
    static let left = CGKeyCodeValue(raw: 123)
    static let right = CGKeyCodeValue(raw: 124)
}
