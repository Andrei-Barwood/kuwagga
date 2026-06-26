import Foundation

/// Perfil de tema con paleta hexadecimal y mapeo inteligente a claves de Terminal.app.
struct TerminalTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let hexColors: [String]
    let mapped: MappedTerminalColors

    init(id: String, name: String, hexColors: [String]) {
        self.id = id
        self.name = name
        self.hexColors = hexColors
        self.mapped = ColorMapper.map(hexColors: hexColors)
    }

    static let catalog: [TerminalTheme] = [
        TerminalTheme(
            id: "remar-nocturna",
            name: "Remar Nocturna",
            hexColors: [
                "#12162C", "#363E7A", "#090E1D", "#282D5A", "#844FDE", "#4B37CA",
                "#1C4CC2", "#FFFFFF", "#0C6182", "#00B6A3", "#67E6D0", "#9CFBFF",
                "#7796EC", "#000000", "#5684E5", "#6E66C0", "#000000", "#9990F2",
                "#C4BEF7", "#7770B9", "#9995BF"
            ]
        ),
        TerminalTheme(
            id: "somos-rich",
            name: "Somos Rich",
            hexColors: [
                "#A46BBD", "#CC9CDF", "#9156A9", "#BF89D1", "#132248", "#243870",
                "#652D87", "#EA428B", "#1E093C", "#662F89", "#8D5DA4", "#CCB2D3",
                "#EA428B", "#FFFFFF", "#EA428B"
            ]
        ),
        TerminalTheme(
            id: "limonada-triple",
            name: "Limonada Triple",
            hexColors: [
                "#EFBD3B", "#FBFC63", "#F7E253", "#3695B5", "#68B5CF", "#7BCBE1",
                "#580D36", "#BC1D75", "#D9539D", "#FCB6DF", "#63B5CB", "#A2D7E1",
                "#96DC51", "#BAEF85", "#D9539D"
            ]
        ),
        TerminalTheme(
            id: "shemel-krass",
            name: "Shemel Krass",
            hexColors: [
                "#BEB789", "#F9FAED", "#E0DEC1", "#DE83CD", "#F8AAE5", "#015B56",
                "#6BF0ED", "#B1F0F4", "#D5F9FB", "#B6E0F7", "#6BF0ED"
            ]
        )
    ]
}

/// Resultado del mapeo: colores principales + 16 slots ANSI estándar.
struct MappedTerminalColors: Equatable, Hashable {
    let background: TerminalColor
    let text: TerminalColor
    let cursor: TerminalColor
    let textBold: TerminalColor
    let selection: TerminalColor
    let ansiColors: [ANSIColorSlot]
}

struct ANSIColorSlot: Equatable, Hashable {
    let key: String
    let color: TerminalColor
    let label: String
}

/// Distribuye paletas de longitud variable entre Background, Text, Cursor y ANSI.
enum ColorMapper {
    /// Orden canónico de claves ANSI en archivos `.terminal`.
    static let ansiKeys: [(key: String, label: String)] = [
        ("ANSIBlackColor", "Black"),
        ("ANSIRedColor", "Red"),
        ("ANSIGreenColor", "Green"),
        ("ANSIYellowColor", "Yellow"),
        ("ANSIBlueColor", "Blue"),
        ("ANSIMagentaColor", "Magenta"),
        ("ANSICyanColor", "Cyan"),
        ("ANSIWhiteColor", "White"),
        ("ANSIBrightBlackColor", "Bright Black"),
        ("ANSIBrightRedColor", "Bright Red"),
        ("ANSIBrightGreenColor", "Bright Green"),
        ("ANSIBrightYellowColor", "Bright Yellow"),
        ("ANSIBrightBlueColor", "Bright Blue"),
        ("ANSIBrightMagentaColor", "Bright Magenta"),
        ("ANSIBrightCyanColor", "Bright Cyan"),
        ("ANSIBrightWhiteColor", "Bright White")
    ]

    static func map(hexColors: [String]) -> MappedTerminalColors {
        let parsed = hexColors.compactMap(TerminalColor.init(hex:))
        guard parsed.count >= 3 else {
            let fallback = TerminalColor(red: 0, green: 0, blue: 0)
            return MappedTerminalColors(
                background: fallback,
                text: TerminalColor(red: 200, green: 200, blue: 200),
                cursor: fallback,
                textBold: TerminalColor(red: 255, green: 255, blue: 255),
                selection: fallback,
                ansiColors: ansiKeys.map { ANSIColorSlot(key: $0.key, color: fallback, label: $0.label) }
            )
        }

        let background = parsed[0]
        let text = parsed[1]
        let cursor = parsed[2]

        // Colores restantes destinados a la tabla ANSI; si faltan, se reutilizan cíclicamente.
        let ansiPool = parsed.count > 3 ? Array(parsed[3...]) : [text]
        let ansiColors = ansiKeys.enumerated().map { index, entry in
            ANSIColorSlot(
                key: entry.key,
                color: ansiPool[index % ansiPool.count],
                label: entry.label
            )
        }

        // Colores auxiliares: usar posiciones 19 y 20 si existen, si no derivar del texto/fondo.
        let textBold: TerminalColor
        if parsed.count > 19 {
            textBold = parsed[19]
        } else {
            textBold = text.brightened()
        }

        let selection: TerminalColor
        if parsed.count > 20 {
            selection = parsed[20]
        } else {
            selection = background.blended(with: text, ratio: 0.35)
        }

        return MappedTerminalColors(
            background: background,
            text: text,
            cursor: cursor,
            textBold: textBold,
            selection: selection,
            ansiColors: ansiColors
        )
    }
}