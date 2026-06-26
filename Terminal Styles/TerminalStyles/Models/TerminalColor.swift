import AppKit
import SwiftUI

/// Representa un color parseado desde hexadecimal con utilidades para Terminal y SwiftUI.
struct TerminalColor: Equatable, Hashable {
    let red: Int
    let green: Int
    let blue: Int
    let alpha: Double

    init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parsea cadenas `#RRGGBB` o `RRGGBB`.
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else { return nil }

        red = Int((value >> 16) & 0xFF)
        green = Int((value >> 8) & 0xFF)
        blue = Int(value & 0xFF)
        alpha = 1.0
    }

    var swiftUIColor: Color {
        Color(
            red: Double(red) / 255.0,
            green: Double(green) / 255.0,
            blue: Double(blue) / 255.0,
            opacity: alpha
        )
    }

    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: CGFloat(alpha)
        )
    }

    /// Formato NSKeyedArchiver requerido por los archivos `.terminal` de macOS Terminal.
    func archivedData() throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
    }

    /// Mezcla lineal con otro color (útil para SelectionColor derivado).
    func blended(with other: TerminalColor, ratio: Double) -> TerminalColor {
        let t = min(max(ratio, 0), 1)
        return TerminalColor(
            red: Int(Double(red) * (1 - t) + Double(other.red) * t),
            green: Int(Double(green) * (1 - t) + Double(other.green) * t),
            blue: Int(Double(blue) * (1 - t) + Double(other.blue) * t),
            alpha: alpha * (1 - t) + other.alpha * t
        )
    }

    /// Aclara el color para TextBoldColor cuando la paleta no provee uno explícito.
    func brightened(by amount: Double = 0.18) -> TerminalColor {
        TerminalColor(
            red: min(255, Int(Double(red) + 255 * amount)),
            green: min(255, Int(Double(green) + 255 * amount)),
            blue: min(255, Int(Double(blue) + 255 * amount)),
            alpha: alpha
        )
    }
}