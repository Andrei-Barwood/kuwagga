import XCTest
@testable import EmodollsStudio

final class RecipeTests: XCTestCase {
    func testEveryCharacterHasARecipe() {
        for character in CharacterID.allCases {
            let recipe = Recipes.for(character)
            XCTAssertEqual(recipe.bandGainsDb.count, 5, character.displayName)
            XCTAssertGreaterThan(recipe.hpfHz, 0)
            XCTAssertGreaterThan(recipe.ratio, 1)
            XCTAssertGreaterThan(recipe.attackMs, 0)
            XCTAssertGreaterThan(recipe.releaseMs, 0)
            XCTAssertEqual(character.genre.characters.contains(character), true)
        }
        XCTAssertEqual(CharacterID.allCases.count, 14)
    }

    func testShunyaCeilingAndLowEnd() {
        let shunya = Recipes.for(.shunya)
        XCTAssertEqual(shunya.ceilingDb, -2.0, accuracy: 0.0001)
        XCTAssertEqual(shunya.ceilingDb, DSPSeal.meditationCeilingDb, accuracy: 0.0001)
        XCTAssertEqual(shunya.hpfHz, 50, accuracy: 0.01)
        XCTAssertEqual(shunya.ratio, 1.8, accuracy: 0.05)
        XCTAssertLessThanOrEqual(shunya.bandGainsDb[0], 0)

        let skeleton = FrequencyTable.skeleton(genre: .kirtan, character: .shunya)
        XCTAssertEqual(skeleton.hpfHz, 50, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(skeleton.bandsHz[0], 150)
        XCTAssertGreaterThan(skeleton.bandsHz[0], 80)
    }

    func testEstrenoDoesNotLiveInRecipe() {
        let recipe = Recipes.for(.obsesion)
        var settings = RenderSettings.defaults()
        settings.estreno = false
        XCTAssertNil(settings.loudnessTargetLUFS)
        XCTAssertEqual(settings.ceilingDb, recipe.ceilingDb, accuracy: 0.0001)

        settings.estreno = true
        XCTAssertEqual(settings.loudnessTargetLUFS, DSPSeal.estrenoLUFS)
        XCTAssertEqual(Recipes.for(.obsesion), recipe)
        XCTAssertEqual(settings.ceilingDb, recipe.ceilingDb, accuracy: 0.0001)
    }

    func testKnobAnchorsByFamily() {
        let obsesionFamily: [CharacterID] = [.obsesion, .subsoil, .mallsoft, .aartiViva]
        for id in obsesionFamily {
            XCTAssertEqual(Recipes.for(id).anchors, KnobAnchors(heat: 0.48, bloom: 0.40, fang: 0.44))
        }

        let desuFamily: [CharacterID] = [.desu, .drop, .runway]
        for id in desuFamily {
            XCTAssertEqual(Recipes.for(id).anchors, KnobAnchors(heat: 0.62, bloom: 0.50, fang: 0.55))
        }

        let glueFamily: [CharacterID] = [.pegamento, .molasses, .haze]
        for id in glueFamily {
            XCTAssertEqual(Recipes.for(id).anchors, KnobAnchors(heat: 0.52, bloom: 0.42, fang: 0.28))
        }

        let airFamily: [CharacterID] = [.airi, .steel, .marbre, .shunya]
        for id in airFamily {
            XCTAssertEqual(Recipes.for(id).anchors, KnobAnchors(heat: 0.32, bloom: 0.38, fang: 0.58))
        }
    }

    func testDesuDropShortAttack() {
        XCTAssertEqual(Recipes.for(.desu).attackMs, 6, accuracy: 0.1)
        XCTAssertEqual(Recipes.for(.drop).attackMs, 7, accuracy: 0.1)
        XCTAssertLessThanOrEqual(Recipes.for(.desu).attackMs, 8)
        XCTAssertGreaterThanOrEqual(Recipes.for(.desu).attackMs, 5)
        XCTAssertLessThanOrEqual(Recipes.for(.drop).attackMs, 8)
        XCTAssertGreaterThanOrEqual(Recipes.for(.drop).attackMs, 5)
    }

    func testPegamentoMolassesHazeGlue() {
        for id in [CharacterID.pegamento, .molasses, .haze] {
            let recipe = Recipes.for(id)
            XCTAssertEqual(recipe.ratio, 3.0, accuracy: 0.05, id.displayName)
            XCTAssertGreaterThanOrEqual(recipe.attackMs, 15, id.displayName)
            XCTAssertLessThanOrEqual(recipe.attackMs, 25, id.displayName)
        }
    }

    func testMarbreUsesMeditationCeiling() {
        XCTAssertEqual(Recipes.for(.marbre).ceilingDb, -2.0, accuracy: 0.0001)
        XCTAssertEqual(Recipes.for(.haze).ceilingDb, DSPSeal.etpcDb, accuracy: 0.0001)
    }

    func testDittoPROStillUsesEDPRegardlessOfRecipe() {
        var settings = RenderSettings.defaults(genre: .kirtan, format: .dittopro)
        settings.character = .shunya
        XCTAssertEqual(settings.ceilingDb, DSPSeal.edpDb, accuracy: 0.0001)
        settings.format = .wav
        XCTAssertEqual(settings.ceilingDb, -2.0, accuracy: 0.0001)
    }

    @MainActor
    func testChangingCharacterLoadsAnchorsWithoutKnobFeedback() {
        let theme = ThemeController()
        XCTAssertEqual(theme.character, .obsesion)
        XCTAssertEqual(theme.heat, 0.48, accuracy: 0.0001)

        theme.heat = 0.9
        XCTAssertEqual(theme.character, .obsesion)
        XCTAssertEqual(theme.heat, 0.9, accuracy: 0.0001)

        theme.character = .desu
        XCTAssertEqual(theme.heat, 0.62, accuracy: 0.0001)
        XCTAssertEqual(theme.bloom, 0.50, accuracy: 0.0001)
        XCTAssertEqual(theme.fang, 0.55, accuracy: 0.0001)
        XCTAssertEqual(theme.character, .desu)

        theme.heat = 0.1
        XCTAssertEqual(theme.character, .desu)
    }
}
