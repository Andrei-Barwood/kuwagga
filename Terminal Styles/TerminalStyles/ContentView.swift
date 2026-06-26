import SwiftUI

struct ContentView: View {
    @State private var selectedThemeID: TerminalTheme.ID = TerminalTheme.catalog.first?.id ?? ""
    @State private var isInstalling = false
    @State private var setAsDefault = false
    @State private var statusMessage: String?
    @State private var showError = false
    @State private var errorMessage = ""

    private var selectedTheme: TerminalTheme {
        TerminalTheme.catalog.first(where: { $0.id == selectedThemeID })
            ?? TerminalTheme.catalog[0]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailPanel
        }
        .frame(minWidth: 820, minHeight: 560)
        .alert("Error de instalación", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .terminalInstallFailed)) { notification in
            if let error = notification.userInfo?["error"] as? Error {
                errorMessage = error.localizedDescription
                showError = true
                isInstalling = false
            }
        }
    }

    private var sidebar: some View {
        List(TerminalTheme.catalog, selection: $selectedThemeID) { theme in
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                    Text("\(theme.hexColors.count) colores")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                ThemeSwatchIcon(theme: theme)
            }
            .tag(theme.id)
        }
        .listStyle(.sidebar)
        .navigationTitle("Temas")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
    }

    private var detailPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                TerminalPreviewView(theme: selectedTheme)
                paletteSection
                installSection
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(selectedTheme.name)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vista previa del tema")
                .font(.title2.weight(.semibold))
            Text("Selecciona un perfil y previsualiza cómo se verá en Terminal.app antes de instalarlo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paleta ANSI")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                PaletteChip(label: "Fondo", color: selectedTheme.mapped.background)
                PaletteChip(label: "Texto", color: selectedTheme.mapped.text)
                PaletteChip(label: "Cursor", color: selectedTheme.mapped.cursor)

                ForEach(selectedTheme.mapped.ansiColors, id: \.key) { slot in
                    PaletteChip(label: slot.label, color: slot.color)
                }
            }
        }
    }

    private var installSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Establecer como perfil predeterminado de Terminal", isOn: $setAsDefault)
                .toggleStyle(.checkbox)

            Button(action: installTheme) {
                HStack(spacing: 8) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "terminal.fill")
                    }
                    Text("Instalar Tema en Terminal")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isInstalling)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Se generará un archivo `.terminal` temporal y Terminal.app lo importará automáticamente en Preferencias → Perfiles.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if setAsDefault {
                Text("El perfil también se registrará como ventana predeterminada y de inicio en Terminal.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func installTheme() {
        isInstalling = true
        statusMessage = nil

        do {
            let fileURL = try TerminalProfileWriter.install(
                theme: selectedTheme,
                setAsDefault: setAsDefault
            )
            var message = "Perfil generado en \(fileURL.lastPathComponent). Terminal.app debería abrirse para importar «\(selectedTheme.name)»."
            if setAsDefault {
                message += " Se estableció como perfil predeterminado."
            }
            statusMessage = message
            isInstalling = false
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isInstalling = false
        }
    }
}

// MARK: - Componentes auxiliares

private struct ThemeSwatchIcon: View {
    let theme: TerminalTheme

    var body: some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.mapped.background.swiftUIColor)
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.mapped.text.swiftUIColor)
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.mapped.cursor.swiftUIColor)
        }
        .frame(width: 28, height: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
    }
}

private struct PaletteChip: View {
    let label: String
    let color: TerminalColor

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.swiftUIColor)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                )

            Text(label)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

#Preview {
    ContentView()
}