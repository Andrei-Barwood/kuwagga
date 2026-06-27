import Foundation
import GameController

/// Represents every useful input we can read from a standard gamepad via GameController framework.
enum ControllerInput: String, CaseIterable, Identifiable, Codable {
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case leftShoulder
    case rightShoulder
    case buttonOptions   // Back / View
    case buttonMenu      // Start / Menu
    case leftTrigger
    case rightTrigger
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftStickClick
    case rightStickClick

    // Special analog consumers (we treat them specially)
    case leftStick
    case rightStick

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .buttonA:          return "A"
        case .buttonB:          return "B"
        case .buttonX:          return "X"
        case .buttonY:          return "Y"
        case .leftShoulder:     return "LB (Left Bumper)"
        case .rightShoulder:    return "RB (Right Bumper)"
        case .buttonOptions:    return "Back / View"
        case .buttonMenu:       return "Start / Menu"
        case .leftTrigger:      return "LT (Left Trigger)"
        case .rightTrigger:     return "RT (Right Trigger)"
        case .dpadUp:           return "D-Pad Arriba"
        case .dpadDown:         return "D-Pad Abajo"
        case .dpadLeft:         return "D-Pad Izquierda"
        case .dpadRight:        return "D-Pad Derecha"
        case .leftStickClick:   return "Stick Izquierdo (pulsado)"
        case .rightStickClick:  return "Stick Derecho (pulsado)"
        case .leftStick:        return "Stick Izquierdo (ejes)"
        case .rightStick:       return "Stick Derecho (ejes)"
        }
    }

    var category: String {
        switch self {
        case .leftStick, .rightStick:
            return "Analógicos"
        case .leftTrigger, .rightTrigger:
            return "Gatillos"
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight:
            return "D-Pad"
        default:
            return "Botones"
        }
    }

    /// Whether this input is analog/continuous (sticks + triggers need special processing)
    var isAnalog: Bool {
        switch self {
        case .leftStick, .rightStick, .leftTrigger, .rightTrigger: return true
        default: return false
        }
    }
}

// Default mapping from ControllerInput → GameAction id
let defaultMappings: [ControllerInput: String] = [
    .buttonA: "fire",
    .buttonB: "alternate",
    .buttonX: "reload",
    .buttonY: "drop_weapon",
    .leftShoulder: "lean_left",
    .rightShoulder: "lean_right",
    .buttonOptions: "menu",
    .buttonMenu: "confirm",
    .dpadUp: "arrow_up",
    .dpadDown: "arrow_down",
    .dpadLeft: "arrow_left",
    .dpadRight: "arrow_right",
    .rightTrigger: "fire",
    .leftTrigger: "alternate",
    .leftStick: "movement",
    .rightStick: "mouse_look",
    .leftStickClick: "run",           // Bonus: clicking left stick = run (user had extra buttons)
    .rightStickClick: "drop_weapon",
]
