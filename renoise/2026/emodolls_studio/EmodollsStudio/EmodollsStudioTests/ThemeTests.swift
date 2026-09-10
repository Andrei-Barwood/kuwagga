import XCTest
@testable import EmodollsStudio

final class ThemeTests: XCTestCase {
    func testBreakcoreTokens() {
        XCTAssertEqual(Breakcore.bgNight, "#1A0A10")
        XCTAssertEqual(Breakcore.bgDay, "#FFF5F8")
        XCTAssertEqual(Breakcore.primaryNight, "#EC078B")
        XCTAssertEqual(Breakcore.primaryDay, "#EC078B")
        XCTAssertEqual(Breakcore.secondaryNight, "#B02171")
        XCTAssertEqual(Breakcore.accentNight, "#E786B7")
        XCTAssertEqual(Breakcore.highlightNight, "#F952A8")
        XCTAssertEqual(Breakcore.textNight, "#FFF5F8")
        XCTAssertEqual(Breakcore.textDay, "#1A0A10")
        XCTAssertEqual(Breakcore.mutedNight, "#7E5B70")
        XCTAssertEqual(Breakcore.mutedDay, "#6A3953")
    }

    func testDubstepTokens() {
        XCTAssertEqual(Dubstep.bgNight, "#1A0C10")
        XCTAssertEqual(Dubstep.bgDay, "#F8EFE6")
        XCTAssertEqual(Dubstep.primaryNight, "#5A2476")
        XCTAssertEqual(Dubstep.secondaryNight, "#CD793F")
        XCTAssertEqual(Dubstep.accentNight, "#A184BB")
        XCTAssertEqual(Dubstep.highlightNight, "#E29E8F")
        XCTAssertEqual(Dubstep.highlightDay, "#CC7A41")
        XCTAssertEqual(Dubstep.textNight, "#F8EFE6")
        XCTAssertEqual(Dubstep.textDay, "#1A0C10")
        XCTAssertEqual(Dubstep.mutedNight, "#3F2360")
        XCTAssertEqual(Dubstep.mutedDay, "#570D16")
    }

    func testVaporwaveTokens() {
        XCTAssertEqual(Vaporwave.bgNight, "#14333A")
        XCTAssertEqual(Vaporwave.bgDay, "#E8F6F4")
        XCTAssertEqual(Vaporwave.primaryNight, "#6DC6C7")
        XCTAssertEqual(Vaporwave.primaryDay, "#427981")
        XCTAssertEqual(Vaporwave.secondaryNight, "#F19ABF")
        XCTAssertEqual(Vaporwave.secondaryDay, "#E56B8A")
        XCTAssertEqual(Vaporwave.accentNight, "#FDEA9A")
        XCTAssertEqual(Vaporwave.highlightNight, "#DAEDE7")
        XCTAssertEqual(Vaporwave.highlightDay, "#6DC6C7")
        XCTAssertEqual(Vaporwave.textNight, "#E8F6F4")
        XCTAssertEqual(Vaporwave.textDay, "#14333A")
        XCTAssertEqual(Vaporwave.mutedNight, "#5AA0A4")
        XCTAssertEqual(Vaporwave.mutedDay, "#427981")
    }

    func testKirtanTokens() {
        XCTAssertEqual(Kirtan.bgNight, "#140C06")
        XCTAssertEqual(Kirtan.bgDay, "#FBF3E4")
        XCTAssertEqual(Kirtan.primaryNight, "#C7913A")
        XCTAssertEqual(Kirtan.secondaryNight, "#25786E")
        XCTAssertEqual(Kirtan.accentNight, "#8FC6C8")
        XCTAssertEqual(Kirtan.highlightNight, "#FADF92")
        XCTAssertEqual(Kirtan.textNight, "#FBF3E4")
        XCTAssertEqual(Kirtan.textDay, "#140C06")
        XCTAssertEqual(Kirtan.mutedNight, "#9D693B")
        XCTAssertEqual(Kirtan.mutedDay, "#422717")
    }

    func testCatalogCoversEveryGenreAndAppearance() {
        for genre in Genre.allCases {
            for appearance in Appearance.allCases {
                let hex = Palette.hex(genre: genre, appearance: appearance)
                XCTAssertTrue(hex.bg.hasPrefix("#"))
                XCTAssertEqual(hex.bg.count, 7)
            }
        }
    }

    func testTextOnBackgroundMeetsWCAG_AA() {
        for genre in Genre.allCases {
            for appearance in Appearance.allCases {
                let hex = Palette.hex(genre: genre, appearance: appearance)
                let ratio = Contrast.ratio(hex.text, hex.bg)
                XCTAssertGreaterThanOrEqual(
                    ratio,
                    4.5,
                    "\(genre.displayName) \(appearance.displayName) text/bg contrast \(ratio)"
                )
            }
        }
    }

    @MainActor
    func testChangingGenreRepaintsPaletteWithoutReload() {
        let theme = ThemeController()
        theme.appearanceMode = .night
        let before = theme.hex(matching: .dark)
        XCTAssertEqual(before.bg, Breakcore.bgNight)

        theme.genre = .kirtan
        let after = theme.hex(matching: .dark)
        XCTAssertEqual(after.bg, Kirtan.bgNight)
        XCTAssertNotEqual(before.bg, after.bg)
        XCTAssertEqual(theme.character, .aartiViva)
    }

    @MainActor
    func testAppearanceOverrideBeatsSystem() {
        let theme = ThemeController()
        theme.appearanceMode = .day
        XCTAssertEqual(theme.appearance(matching: .dark), .day)
        XCTAssertEqual(theme.forcedColorScheme, .light)

        theme.appearanceMode = .night
        XCTAssertEqual(theme.appearance(matching: .light), .night)
        XCTAssertEqual(theme.forcedColorScheme, .dark)

        theme.appearanceMode = .system
        XCTAssertEqual(theme.appearance(matching: .dark), .night)
        XCTAssertNil(theme.forcedColorScheme)
    }

    func testPublicThemeSymbolsHaveNoCharacterNames() {
        let forbidden = [
            "draculaura", "clawdeen", "lagoona", "cleo", "mattel",
            "monster high", "ghoulia", "abbey", "frankie",
        ]
        let symbols = [
            String(describing: Breakcore.self),
            String(describing: Dubstep.self),
            String(describing: Vaporwave.self),
            String(describing: Kirtan.self),
            String(describing: Palette.self),
            String(describing: ThemeController.self),
        ].joined(separator: " ").lowercased()

        for name in forbidden {
            XCTAssertFalse(symbols.contains(name), "public symbol dump contains \(name)")
        }
    }
}

private enum Contrast {
    static func ratio(_ hexA: String, _ hexB: String) -> Double {
        let l1 = luminance(hexA)
        let l2 = luminance(hexB)
        let (hi, lo) = l1 > l2 ? (l1, l2) : (l2, l1)
        return (hi + 0.05) / (lo + 0.05)
    }

    static func luminance(_ hex: String) -> Double {
        let rgb = parse(hex)
        return 0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    }

    static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    static func parse(_ hex: String) -> (Double, Double, Double) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            .scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return (r, g, b)
    }
}
