import SwiftUI

@MainActor
final class ThemeController: ObservableObject {
    @Published var genre: Genre = .breakcore {
        didSet {
            guard oldValue != genre else { return }
            character = genre.defaultCharacter
        }
    }

    @Published var character: CharacterID = Genre.breakcore.defaultCharacter {
        didSet {
            guard oldValue != character else { return }
            loadAnchors()
        }
    }

    @Published var appearanceMode: AppearanceMode = .system
    @Published var heat: Float
    @Published var bloom: Float
    @Published var fang: Float

    init() {
        let anchors = Recipes.for(Genre.breakcore.defaultCharacter).anchors
        heat = anchors.heat
        bloom = anchors.bloom
        fang = anchors.fang
    }

    var recipe: Recipe { Recipes.for(character) }

    func loadAnchors() {
        let anchors = Recipes.for(character).anchors
        heat = anchors.heat
        bloom = anchors.bloom
        fang = anchors.fang
    }

    func renderSettings(format: ExportFormat, estreno: Bool) -> RenderSettings {
        RenderSettings(
            genre: genre,
            character: character,
            heat: heat,
            bloom: bloom,
            fang: fang,
            format: format,
            estreno: estreno
        )
    }

    func appearance(matching system: ColorScheme) -> Appearance {
        appearanceMode.resolved(system: system)
    }

    func palette(matching system: ColorScheme) -> Palette {
        Palette.resolved(genre: genre, appearance: appearance(matching: system))
    }

    func hex(matching system: ColorScheme) -> PaletteHex {
        Palette.hex(genre: genre, appearance: appearance(matching: system))
    }

    var forcedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .day: return .light
        case .night: return .dark
        }
    }
}
