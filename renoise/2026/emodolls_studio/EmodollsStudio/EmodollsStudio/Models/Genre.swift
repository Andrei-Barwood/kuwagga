import Foundation

enum Genre: String, CaseIterable, Identifiable, Hashable, Sendable {
    case breakcore
    case dubstep
    case vaporwave
    case kirtan

    var id: String { rawValue }

    var displayName: String { rawValue }

    var characters: [CharacterID] {
        switch self {
        case .breakcore:
            return [.obsesion, .desu, .pegamento, .airi]
        case .dubstep:
            return [.subsoil, .drop, .molasses, .steel]
        case .vaporwave:
            return [.mallsoft, .runway, .haze, .marbre]
        case .kirtan:
            return [.aartiViva, .shunya]
        }
    }

    var defaultCharacter: CharacterID { characters[0] }

    var knobLabels: KnobIDs {
        switch self {
        case .breakcore:
            return KnobIDs(heat: "Yandere", bloom: "Kizu", fang: "Kyun")
        case .dubstep:
            return KnobIDs(heat: "Pelt", bloom: "Howl", fang: "Fang")
        case .vaporwave:
            return KnobIDs(heat: "Chlorine", bloom: "Tide", fang: "Glare")
        case .kirtan:
            return KnobIDs(heat: "Seva", bloom: "Aarti", fang: "Naam")
        }
    }
}
