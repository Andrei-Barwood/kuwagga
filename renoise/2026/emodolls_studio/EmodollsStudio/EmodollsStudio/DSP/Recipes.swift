import Foundation

struct KnobAnchors: Equatable, Sendable {
    var heat: Float
    var bloom: Float
    var fang: Float
}

struct Recipe: Equatable, Sendable {
    var hpfHz: Float
    var bandGainsDb: [Float]
    var fangDb: Float
    var ratio: Float
    var attackMs: Float
    var releaseMs: Float
    var ceilingDb: Float
    var anchors: KnobAnchors
}

enum Recipes {
    private static let familyObsesion = KnobAnchors(heat: 0.48, bloom: 0.40, fang: 0.44)
    private static let familyDesu = KnobAnchors(heat: 0.62, bloom: 0.50, fang: 0.55)
    private static let familyPegamento = KnobAnchors(heat: 0.52, bloom: 0.42, fang: 0.28)
    private static let familyAiri = KnobAnchors(heat: 0.32, bloom: 0.38, fang: 0.58)

    static func `for`(_ character: CharacterID) -> Recipe {
        switch character {
        case .obsesion:
            return Recipe(
                hpfHz: 32,
                bandGainsDb: [-0.8, 0.8, 1.4, 0.4, 0.7],
                fangDb: 3.2,
                ratio: 2.6,
                attackMs: 10,
                releaseMs: 65,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyObsesion
            )
        case .desu:
            return Recipe(
                hpfHz: 32,
                bandGainsDb: [-1.2, 0.6, 2.2, 0.6, 0.9],
                fangDb: 4.2,
                ratio: 2.8,
                attackMs: 6,
                releaseMs: 55,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyDesu
            )
        case .pegamento:
            return Recipe(
                hpfHz: 32,
                bandGainsDb: [-0.6, 1.8, 0.8, 0.2, 0.3],
                fangDb: 1.6,
                ratio: 3.0,
                attackMs: 18,
                releaseMs: 80,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyPegamento
            )
        case .airi:
            return Recipe(
                hpfHz: 32,
                bandGainsDb: [-1.4, 0.2, 1.8, 0.8, 1.6],
                fangDb: 4.8,
                ratio: 2.0,
                attackMs: 12,
                releaseMs: 70,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyAiri
            )
        case .subsoil:
            return Recipe(
                hpfHz: 25,
                bandGainsDb: [1.2, -1.6, 0.6, 0.4, 0.3],
                fangDb: 2.8,
                ratio: 2.6,
                attackMs: 11,
                releaseMs: 70,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyObsesion
            )
        case .drop:
            return Recipe(
                hpfHz: 25,
                bandGainsDb: [1.6, -1.2, 0.8, 1.6, 0.6],
                fangDb: 4.0,
                ratio: 2.7,
                attackMs: 7,
                releaseMs: 50,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyDesu
            )
        case .molasses:
            return Recipe(
                hpfHz: 25,
                bandGainsDb: [2.2, -2.0, 0.4, 0.2, 0.2],
                fangDb: 1.4,
                ratio: 3.0,
                attackMs: 22,
                releaseMs: 90,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyPegamento
            )
        case .steel:
            return Recipe(
                hpfHz: 25,
                bandGainsDb: [0.4, -1.0, 0.3, 2.0, 1.2],
                fangDb: 4.6,
                ratio: 2.2,
                attackMs: 6,
                releaseMs: 45,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyAiri
            )
        case .mallsoft:
            return Recipe(
                hpfHz: 30,
                bandGainsDb: [0.8, 0.6, 0.5, -1.6, 0.4],
                fangDb: 2.4,
                ratio: 2.4,
                attackMs: 14,
                releaseMs: 85,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyObsesion
            )
        case .runway:
            return Recipe(
                hpfHz: 30,
                bandGainsDb: [1.0, 0.8, 1.2, -0.6, 0.8],
                fangDb: 3.6,
                ratio: 2.6,
                attackMs: 10,
                releaseMs: 60,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyDesu
            )
        case .haze:
            return Recipe(
                hpfHz: 30,
                bandGainsDb: [0.6, 0.8, 0.3, -1.2, 0.2],
                fangDb: 1.5,
                ratio: 3.0,
                attackMs: 20,
                releaseMs: 95,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyPegamento
            )
        case .marbre:
            return Recipe(
                hpfHz: 30,
                bandGainsDb: [0.2, 0.3, 0.8, -0.4, 1.8],
                fangDb: 3.8,
                ratio: 2.0,
                attackMs: 12,
                releaseMs: 75,
                ceilingDb: DSPSeal.meditationCeilingDb,
                anchors: familyAiri
            )
        case .aartiViva:
            return Recipe(
                hpfHz: 35,
                bandGainsDb: [0.8, 1.1, 2.0, 0.7, 1.0],
                fangDb: 3.4,
                ratio: 2.4,
                attackMs: 12,
                releaseMs: 80,
                ceilingDb: DSPSeal.etpcDb,
                anchors: familyObsesion
            )
        case .shunya:
            return Recipe(
                hpfHz: 50,
                bandGainsDb: [0.0, 0.7, 1.4, 0.5, 1.2],
                fangDb: 3.0,
                ratio: 1.8,
                attackMs: 16,
                releaseMs: 110,
                ceilingDb: DSPSeal.meditationCeilingDb,
                anchors: familyAiri
            )
        }
    }
}
