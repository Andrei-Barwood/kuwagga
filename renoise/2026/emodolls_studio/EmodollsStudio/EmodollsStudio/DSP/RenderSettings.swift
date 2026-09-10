import Foundation

struct RenderSettings: Equatable, Sendable {
    var genre: Genre
    var character: CharacterID
    var heat: Float
    var bloom: Float
    var fang: Float
    var format: ExportFormat
    var estreno: Bool

    var loudnessTargetLUFS: Double? {
        estreno ? DSPSeal.estrenoLUFS : nil
    }

    var ceilingDb: Float {
        if format.duplicatesToStereo {
            return DSPSeal.edpDb
        }
        return Recipes.for(character).ceilingDb
    }

    static func defaults(genre: Genre = .breakcore, format: ExportFormat = .wav) -> RenderSettings {
        let character = genre.defaultCharacter
        let anchors = Recipes.for(character).anchors
        return RenderSettings(
            genre: genre,
            character: character,
            heat: anchors.heat,
            bloom: anchors.bloom,
            fang: anchors.fang,
            format: format,
            estreno: false
        )
    }
}
