import SwiftUI

/// Simula una ventana de Terminal con prompt zsh y salida `ls -la` coloreada con la paleta ANSI.
struct TerminalPreviewView: View {
    let theme: TerminalTheme

    private var mapped: MappedTerminalColors { theme.mapped }

    private func ansi(_ index: Int) -> TerminalColor {
        let colors = mapped.ansiColors
        guard !colors.isEmpty else { return mapped.text }
        return colors[index % colors.count].color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            terminalChrome
            terminalContent
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    private var terminalChrome: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red.opacity(0.85)).frame(width: 12, height: 12)
            Circle().fill(Color.yellow.opacity(0.85)).frame(width: 12, height: 12)
            Circle().fill(Color.green.opacity(0.85)).frame(width: 12, height: 12)
            Spacer()
            Text(theme.name)
                .font(.caption)
                .foregroundStyle(mapped.text.swiftUIColor.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(mapped.background.swiftUIColor.opacity(0.92))
    }

    private var terminalContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                promptLine
                lsOutput
                blankLine
                colorSwatchRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(minHeight: 280)
        .background(mapped.background.swiftUIColor)
    }

    private var promptLine: some View {
        HStack(spacing: 0) {
            Text("andreibarwood@mac")
                .foregroundStyle(ansi(5).swiftUIColor)
            Text(":")
                .foregroundStyle(mapped.text.swiftUIColor)
            Text("~/proyectos")
                .foregroundStyle(ansi(6).swiftUIColor)
            Text(" % ")
                .foregroundStyle(mapped.text.swiftUIColor)
            Text("ls -la")
                .foregroundStyle(mapped.textBold.swiftUIColor)
        }
        .font(.system(.body, design: .monospaced))
    }

    private var lsOutput: some View {
        VStack(alignment: .leading, spacing: 4) {
            lsLine(
                permissions: "drwxr-xr-x",
                links: "12",
                owner: "staff",
                size: "384",
                name: "Documents",
                nameColor: ansi(6)
            )
            lsLine(
                permissions: "drwxr-xr-x",
                links: "8",
                owner: "staff",
                size: "256",
                name: "Downloads",
                nameColor: ansi(6)
            )
            lsLine(
                permissions: "-rw-r--r--",
                links: "1",
                owner: "staff",
                size: "4.2K",
                name: "README.md",
                nameColor: mapped.text
            )
            lsLine(
                permissions: "-rwxr-xr-x",
                links: "1",
                owner: "staff",
                size: "2.1K",
                name: "deploy.sh",
                nameColor: ansi(2)
            )
            lsLine(
                permissions: "-rw-r--r--",
                links: "1",
                owner: "staff",
                size: "512B",
                name: ".env",
                nameColor: ansi(1)
            )
        }
        .font(.system(.callout, design: .monospaced))
    }

    private func lsLine(
        permissions: String,
        links: String,
        owner: String,
        size: String,
        name: String,
        nameColor: TerminalColor
    ) -> some View {
        HStack(spacing: 0) {
            Text(permissions + "  ")
                .foregroundStyle(ansi(3).swiftUIColor)
            Text("\(links) \(owner)  ")
                .foregroundStyle(mapped.text.swiftUIColor.opacity(0.85))
            Text("\(size.padding(toLength: 6, withPad: " ", startingAt: 0))  ")
                .foregroundStyle(ansi(4).swiftUIColor)
            Text(name)
                .foregroundStyle(nameColor.swiftUIColor)
        }
    }

    private var blankLine: some View {
        Text(" ")
            .font(.system(.body, design: .monospaced))
    }

    private var colorSwatchRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(mapped.ansiColors.prefix(8).enumerated()), id: \.offset) { _, slot in
                RoundedRectangle(cornerRadius: 3)
                    .fill(slot.color.swiftUIColor)
                    .frame(width: 22, height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
    }
}