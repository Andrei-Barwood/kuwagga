import SwiftUI

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.resolved(genre: .breakcore, appearance: .night)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct Themed: ViewModifier {
    @EnvironmentObject private var theme: ThemeController
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let palette = theme.palette(matching: colorScheme)
        content
            .environment(\.palette, palette)
            .tint(palette.primary)
            .foregroundStyle(palette.text)
            .background(palette.bg)
            .preferredColorScheme(theme.forcedColorScheme)
            .animation(.easeInOut(duration: 0.18), value: theme.genre)
            .animation(.easeInOut(duration: 0.18), value: theme.appearanceMode)
    }
}

extension View {
    func emodollsTheme() -> some View {
        modifier(Themed())
    }
}
