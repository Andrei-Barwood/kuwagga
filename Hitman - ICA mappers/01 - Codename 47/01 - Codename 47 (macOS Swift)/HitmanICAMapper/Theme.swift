import SwiftUI

// MARK: - ICA Color Palette (ported from Python version)
enum Theme {
    static let primaryBlue   = Color(hex: "#485199")
    static let secondaryBlue = Color(hex: "#5A64BF")
    static let gold          = Color(hex: "#CCB244")
    static let lightGold     = Color(hex: "#E3CA75")
    static let darkBG        = Color(hex: "#303030")
    static let mediumGray    = Color(hex: "#4F4F4F")
    static let lightBG       = Color(hex: "#D7E0EC")
    static let textPrimary   = Color(hex: "#D7E0EC")
    static let textSecondary = Color(hex: "#A0A8B8")
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
