import Foundation

enum CharacterID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case obsesion = "Obsesión"
    case desu = "Desu"
    case pegamento = "Pegamento"
    case airi = "Airi"

    case subsoil = "Subsoil"
    case drop = "Drop"
    case molasses = "Molasses"
    case steel = "Steel"

    case mallsoft = "Mallsoft"
    case runway = "Runway"
    case haze = "Haze"
    case marbre = "Marbre"

    case aartiViva = "Aarti viva"
    case shunya = "Shunya"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var genre: Genre {
        switch self {
        case .obsesion, .desu, .pegamento, .airi:
            return .breakcore
        case .subsoil, .drop, .molasses, .steel:
            return .dubstep
        case .mallsoft, .runway, .haze, .marbre:
            return .vaporwave
        case .aartiViva, .shunya:
            return .kirtan
        }
    }
}
