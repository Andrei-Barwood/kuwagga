import XCTest
@testable import EmodollsStudio

final class DomainTests: XCTestCase {
    func testCharacterCountsPerGenre() {
        XCTAssertEqual(Genre.breakcore.characters.count, 4)
        XCTAssertEqual(Genre.dubstep.characters.count, 4)
        XCTAssertEqual(Genre.vaporwave.characters.count, 4)
        XCTAssertEqual(Genre.kirtan.characters.count, 2)

        let all = Genre.allCases.flatMap(\.characters)
        XCTAssertEqual(all.count, 14)
        XCTAssertEqual(Set(all).count, 14)
        XCTAssertEqual(CharacterID.allCases.count, 14)
    }

    func testBreakcoreCharacters() {
        XCTAssertEqual(
            Genre.breakcore.characters,
            [.obsesion, .desu, .pegamento, .airi]
        )
    }

    func testDubstepCharacters() {
        XCTAssertEqual(
            Genre.dubstep.characters,
            [.subsoil, .drop, .molasses, .steel]
        )
    }

    func testVaporwaveCharacters() {
        XCTAssertEqual(
            Genre.vaporwave.characters,
            [.mallsoft, .runway, .haze, .marbre]
        )
    }

    func testKirtanCharacters() {
        XCTAssertEqual(
            Genre.kirtan.characters,
            [.aartiViva, .shunya]
        )
    }

    func testEachCharacterBelongsToExactlyOneGenre() {
        for character in CharacterID.allCases {
            let owners = Genre.allCases.filter { $0.characters.contains(character) }
            XCTAssertEqual(owners, [character.genre], "\(character.displayName)")
        }
    }

    func testKnobLabelsMatchTable() {
        XCTAssertEqual(Genre.breakcore.knobLabels, KnobIDs(heat: "Yandere", bloom: "Kizu", fang: "Kyun"))
        XCTAssertEqual(Genre.dubstep.knobLabels, KnobIDs(heat: "Pelt", bloom: "Howl", fang: "Fang"))
        XCTAssertEqual(Genre.vaporwave.knobLabels, KnobIDs(heat: "Chlorine", bloom: "Tide", fang: "Glare"))
        XCTAssertEqual(Genre.kirtan.knobLabels, KnobIDs(heat: "Seva", bloom: "Aarti", fang: "Naam"))
    }

    func testKnobLabelsContainNoForbiddenWords() {
        let forbiddenTokens: Set<String> = [
            "drive", "push", "presence", "lurssen", "ik",
        ]
        let forbiddenSubstrings = ["lurssen", "t-racks", "t_racks", "ik multimedia"]

        for genre in Genre.allCases {
            for label in genre.knobLabels.allLabels {
                let lower = label.lowercased()
                let tokens = Set(
                    lower.split { !$0.isLetter && $0 != "-" }.map(String.init)
                )
                XCTAssertTrue(
                    tokens.isDisjoint(with: forbiddenTokens),
                    "\(genre.displayName) label '\(label)' contains a forbidden token"
                )
                for sub in forbiddenSubstrings {
                    XCTAssertFalse(
                        lower.contains(sub),
                        "\(genre.displayName) label '\(label)' contains '\(sub)'"
                    )
                }
            }
        }
    }

    func testExportFormatExtensionsAndLayout() {
        XCTAssertEqual(ExportFormat.dittopro.pathExtension, "mp3")
        XCTAssertEqual(ExportFormat.dittopro.dottedExtension, ".mp3")
        XCTAssertTrue(ExportFormat.dittopro.duplicatesToStereo)
        XCTAssertEqual(ExportFormat.dittopro.channelCount, 2)

        XCTAssertEqual(ExportFormat.m4a.pathExtension, "m4a")
        XCTAssertFalse(ExportFormat.m4a.duplicatesToStereo)
        XCTAssertEqual(ExportFormat.m4a.channelCount, 1)

        XCTAssertEqual(ExportFormat.wav.pathExtension, "wav")
        XCTAssertFalse(ExportFormat.wav.duplicatesToStereo)
        XCTAssertEqual(ExportFormat.wav.channelCount, 1)

        XCTAssertEqual(ExportFormat.filenameSuffix, "_MD")
    }

    func testSessionLimits() {
        XCTAssertEqual(SessionLimits.maxTracks, 10)
        XCTAssertEqual(SessionLimits.sampleRate, 44_100)
    }

    func testMetadataDraftDefaultsEmpty() {
        XCTAssertTrue(MetadataDraft().isEmpty)
        XCTAssertFalse(MetadataDraft(title: "x").isEmpty)
    }
}
