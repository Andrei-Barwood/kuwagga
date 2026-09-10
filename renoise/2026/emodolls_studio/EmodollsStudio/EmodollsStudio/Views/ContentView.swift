import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeController
    @EnvironmentObject private var session: Session
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    @State private var format: ExportFormat = .wav
    @State private var estreno = false
    @State private var metadata = MetadataDraft()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                genrePicker
                characterPicker
                dayNightToggle
                knobs
                formatPicker
                estrenoToggle
                overwriteRow
                metadataForm
                folders
                if let warning = session.truncatedWarning {
                    Text(warning)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.highlight)
                }
                trackList
                if !session.preview.isEmpty {
                    previewList
                }
                progressBlock
                actions
                failures
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .frame(minWidth: 700, minHeight: 640)
        .background(palette.bg)
        .background(shortcutButtons)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("emodolls studio")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(palette.primary)
            Text("Mastering true-mono. Un carácter, tres knobs, una carpeta.")
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
        }
    }

    private var genrePicker: some View {
        labeled("Género") {
            Picker("Género", selection: $theme.genre) {
                ForEach(Genre.allCases) { genre in
                    Text(genre.displayName).tag(genre)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var characterPicker: some View {
        labeled("Carácter") {
            Picker("Carácter", selection: $theme.character) {
                ForEach(theme.genre.characters) { character in
                    Text(character.displayName).tag(character)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var dayNightToggle: some View {
        HStack(spacing: 12) {
            Text("Día")
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
            Toggle("Noche", isOn: nightBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(palette.primary)
            Text("Noche")
                .font(.system(size: 13))
                .foregroundStyle(palette.text)
        }
    }

    private var knobs: some View {
        VStack(alignment: .leading, spacing: 14) {
            knob(theme.genre.knobLabels.heat, value: heatBinding)
            knob(theme.genre.knobLabels.bloom, value: bloomBinding)
            knob(theme.genre.knobLabels.fang, value: fangBinding)
        }
    }

    private var formatPicker: some View {
        labeled("Formato") {
            Picker("Formato", selection: $format) {
                ForEach(ExportFormat.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var estrenoToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Estreno", isOn: $estreno)
                .tint(palette.primary)
            Text("Estreno deja el master en −14 LUFS con techo emodolls, razonable en Apple Music, iTunes, YouTube Music y Spotify. Ellos igual normalizan.")
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var overwriteRow: some View {
        Toggle("Sobrescribir", isOn: $session.overwrite)
            .tint(palette.primary)
    }

    private var metadataForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metadatos")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.muted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metaField("Título", text: $metadata.title)
                metaField("Artista", text: $metadata.artist)
                metaField("Álbum", text: $metadata.album)
                metaField("Pista", text: $metadata.track)
                metaField("Año", text: $metadata.year)
                metaField("Género", text: $metadata.genre)
            }
        }
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 10) {
            folderRow(
                title: "Entrada",
                path: session.inputRoot,
                action: { Task { await pickInput() } }
            )
            folderRow(
                title: "Salida",
                path: session.outputRoot,
                action: { Task { await pickOutput() } }
            )
        }
    }

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pistas")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.muted)
                Spacer()
                Text("\(session.tracks.count)/\(SessionLimits.maxTracks)")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(palette.muted)
            }
            if session.tracks.isEmpty {
                Text("Elige una carpeta de entrada.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.muted)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(session.tracks, id: \.path) { url in
                        Text(url.lastPathComponent)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Previsualización")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.muted)
            ForEach(session.preview, id: \.path) { url in
                Text(url.lastPathComponent)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
            }
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: session.progress.fraction, total: 1)
                .tint(palette.primary)
            HStack {
                if session.progress.total > 0 {
                    Text(session.progress.label)
                        .font(.system(size: 12).monospacedDigit())
                }
                if !session.progress.currentName.isEmpty {
                    Text(session.progress.currentName)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(palette.muted)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Previsualizar") {
                Processor.preview(session: session, format: format)
            }
            .disabled(session.isRunning || session.tracks.isEmpty || session.outputRoot == nil)
            .keyboardShortcut("p", modifiers: .command)

            if session.isRunning {
                Button("Cancelar") {
                    session.requestCancel()
                }
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button("Procesar") {
                    Task { await process() }
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.primary)
                .disabled(!canProcess)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    private var failures: some View {
        Group {
            if !session.failures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Fallos")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.highlight)
                    ForEach(session.failures) { failure in
                        Text("\(failure.path.lastPathComponent) — \(failure.message)")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var shortcutButtons: some View {
        Group {
            Button("Entrada") { Task { await pickInput() } }
                .keyboardShortcut("o", modifiers: .command)
            Button("Salida") { Task { await pickOutput() } }
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var canProcess: Bool {
        !session.tracks.isEmpty && session.outputRoot != nil && !session.isRunning
    }

    private var nightBinding: Binding<Bool> {
        Binding(
            get: {
                if theme.appearanceMode == .system {
                    return colorScheme == .dark
                }
                return theme.appearanceMode == .night
            },
            set: { theme.appearanceMode = $0 ? .night : .day }
        )
    }

    private var heatBinding: Binding<Double> {
        Binding(get: { Double(theme.heat) }, set: { theme.heat = Float($0) })
    }

    private var bloomBinding: Binding<Double> {
        Binding(get: { Double(theme.bloom) }, set: { theme.bloom = Float($0) })
    }

    private var fangBinding: Binding<Double> {
        Binding(get: { Double(theme.fang) }, set: { theme.fang = Float($0) })
    }

    private func pickInput() async {
        guard let url = await StudioFilePicker.pickDirectory(prompt: "Carpeta de entrada") else { return }
        session.clearTracks()
        session.addFolder(url)
    }

    private func pickOutput() async {
        guard let url = await StudioFilePicker.pickDirectory(prompt: "Carpeta de salida") else { return }
        session.outputRoot = url
    }

    private func process() async {
        let settings = theme.renderSettings(format: format, estreno: estreno)
        await Processor.run(
            session: session,
            settings: settings,
            metadata: metadata,
            dryRun: false
        )
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.muted)
            content()
        }
    }

    private func knob(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.text)
            Slider(value: value, in: 0...1)
                .tint(palette.primary)
        }
    }

    private func metaField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(palette.muted)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func folderRow(title: String, path: URL?, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(title, action: action)
            Text(path?.path ?? "—")
                .font(.system(size: 12))
                .foregroundStyle(palette.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#Preview("Noche") {
    ContentView()
        .emodollsTheme()
        .environmentObject({
            let theme = ThemeController()
            theme.appearanceMode = .night
            return theme
        }())
        .environmentObject(Session())
}

#Preview("Día") {
    ContentView()
        .emodollsTheme()
        .environmentObject({
            let theme = ThemeController()
            theme.appearanceMode = .day
            theme.genre = .vaporwave
            return theme
        }())
        .environmentObject(Session())
}
