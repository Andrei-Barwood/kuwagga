import SwiftUI

enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case day
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day: return "Día"
        case .night: return "Noche"
        }
    }

    var colorScheme: ColorScheme {
        self == .day ? .light : .dark
    }

    static func matching(_ scheme: ColorScheme) -> Appearance {
        scheme == .dark ? .night : .day
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case day
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .day: return Appearance.day.displayName
        case .night: return Appearance.night.displayName
        }
    }

    func resolved(system: ColorScheme) -> Appearance {
        switch self {
        case .system: return Appearance.matching(system)
        case .day: return .day
        case .night: return .night
        }
    }
}

struct PaletteHex: Equatable, Sendable {
    var bg: String
    var primary: String
    var secondary: String
    var accent: String
    var highlight: String
    var text: String
    var muted: String
}

struct Palette: Equatable {
    var bg: Color
    var primary: Color
    var secondary: Color
    var accent: Color
    var highlight: Color
    var text: Color
    var muted: Color

    init(hex: PaletteHex) {
        bg = Color(hex: hex.bg)
        primary = Color(hex: hex.primary)
        secondary = Color(hex: hex.secondary)
        accent = Color(hex: hex.accent)
        highlight = Color(hex: hex.highlight)
        text = Color(hex: hex.text)
        muted = Color(hex: hex.muted)
    }

    static func hex(genre: Genre, appearance: Appearance) -> PaletteHex {
        switch (genre, appearance) {
        case (.breakcore, .night): return Breakcore.night
        case (.breakcore, .day): return Breakcore.day
        case (.dubstep, .night): return Dubstep.night
        case (.dubstep, .day): return Dubstep.day
        case (.vaporwave, .night): return Vaporwave.night
        case (.vaporwave, .day): return Vaporwave.day
        case (.kirtan, .night): return Kirtan.night
        case (.kirtan, .day): return Kirtan.day
        }
    }

    static func resolved(genre: Genre, appearance: Appearance) -> Palette {
        Palette(hex: hex(genre: genre, appearance: appearance))
    }
}

enum Breakcore {
    static let bgNight = "#1A0A10"
    static let bgDay = "#FFF5F8"
    static let primaryNight = "#EC078B"
    static let primaryDay = "#EC078B"
    static let secondaryNight = "#B02171"
    static let secondaryDay = "#B02171"
    static let accentNight = "#E786B7"
    static let accentDay = "#E786B7"
    static let highlightNight = "#F952A8"
    static let highlightDay = "#F952A8"
    static let textNight = "#FFF5F8"
    static let textDay = "#1A0A10"
    static let mutedNight = "#7E5B70"
    static let mutedDay = "#6A3953"

    static let night = PaletteHex(
        bg: bgNight, primary: primaryNight, secondary: secondaryNight,
        accent: accentNight, highlight: highlightNight, text: textNight, muted: mutedNight
    )
    static let day = PaletteHex(
        bg: bgDay, primary: primaryDay, secondary: secondaryDay,
        accent: accentDay, highlight: highlightDay, text: textDay, muted: mutedDay
    )
}

enum Dubstep {
    static let bgNight = "#1A0C10"
    static let bgDay = "#F8EFE6"
    static let primaryNight = "#5A2476"
    static let primaryDay = "#5A2476"
    static let secondaryNight = "#CD793F"
    static let secondaryDay = "#CD793F"
    static let accentNight = "#A184BB"
    static let accentDay = "#A184BB"
    static let highlightNight = "#E29E8F"
    static let highlightDay = "#CC7A41"
    static let textNight = "#F8EFE6"
    static let textDay = "#1A0C10"
    static let mutedNight = "#3F2360"
    static let mutedDay = "#570D16"

    static let night = PaletteHex(
        bg: bgNight, primary: primaryNight, secondary: secondaryNight,
        accent: accentNight, highlight: highlightNight, text: textNight, muted: mutedNight
    )
    static let day = PaletteHex(
        bg: bgDay, primary: primaryDay, secondary: secondaryDay,
        accent: accentDay, highlight: highlightDay, text: textDay, muted: mutedDay
    )
}

enum Vaporwave {
    static let bgNight = "#14333A"
    static let bgDay = "#E8F6F4"
    static let primaryNight = "#6DC6C7"
    static let primaryDay = "#427981"
    static let secondaryNight = "#F19ABF"
    static let secondaryDay = "#E56B8A"
    static let accentNight = "#FDEA9A"
    static let accentDay = "#FDEA9A"
    static let highlightNight = "#DAEDE7"
    static let highlightDay = "#6DC6C7"
    static let textNight = "#E8F6F4"
    static let textDay = "#14333A"
    static let mutedNight = "#5AA0A4"
    static let mutedDay = "#427981"

    static let night = PaletteHex(
        bg: bgNight, primary: primaryNight, secondary: secondaryNight,
        accent: accentNight, highlight: highlightNight, text: textNight, muted: mutedNight
    )
    static let day = PaletteHex(
        bg: bgDay, primary: primaryDay, secondary: secondaryDay,
        accent: accentDay, highlight: highlightDay, text: textDay, muted: mutedDay
    )
}

enum Kirtan {
    static let bgNight = "#140C06"
    static let bgDay = "#FBF3E4"
    static let primaryNight = "#C7913A"
    static let primaryDay = "#C7913A"
    static let secondaryNight = "#25786E"
    static let secondaryDay = "#25786E"
    static let accentNight = "#8FC6C8"
    static let accentDay = "#8FC6C8"
    static let highlightNight = "#FADF92"
    static let highlightDay = "#FADF92"
    static let textNight = "#FBF3E4"
    static let textDay = "#140C06"
    static let mutedNight = "#9D693B"
    static let mutedDay = "#422717"

    static let night = PaletteHex(
        bg: bgNight, primary: primaryNight, secondary: secondaryNight,
        accent: accentNight, highlight: highlightNight, text: textNight, muted: mutedNight
    )
    static let day = PaletteHex(
        bg: bgDay, primary: primaryDay, secondary: secondaryDay,
        accent: accentDay, highlight: highlightDay, text: textDay, muted: mutedDay
    )
}
