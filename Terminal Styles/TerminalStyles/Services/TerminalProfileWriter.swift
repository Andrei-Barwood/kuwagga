import AppKit
import Foundation

enum TerminalProfileError: LocalizedError {
    case templateNotFound
    case invalidTemplate
    case writeFailed(Error)
    case openFailed(Error)
    case defaultsUnavailable

    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "No se encontró la plantilla base de Terminal.app."
        case .invalidTemplate:
            return "La plantilla .terminal no tiene un formato válido."
        case .writeFailed(let error):
            return "Error al escribir el perfil: \(error.localizedDescription)"
        case .openFailed(let error):
            return "No se pudo abrir el archivo en Terminal: \(error.localizedDescription)"
        case .defaultsUnavailable:
            return "No se pudo acceder a las preferencias de Terminal.app."
        }
    }
}

/// Genera archivos `.terminal` compatibles con la importación nativa de Terminal.app.
struct TerminalProfileWriter {
    private static let templatePath =
        "/System/Applications/Utilities/Terminal.app/Contents/Resources/Initial Settings/Grass.terminal"

    /// Crea el plist del perfil a partir de un tema mapeado.
    static func buildProfileDictionary(for theme: TerminalTheme) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: templatePath) else {
            throw TerminalProfileError.templateNotFound
        }

        let templateURL = URL(fileURLWithPath: templatePath)
        let templateData = try Data(contentsOf: templateURL)
        var format = PropertyListSerialization.PropertyListFormat.xml

        guard var profile = try PropertyListSerialization.propertyList(
            from: templateData,
            options: [],
            format: &format
        ) as? [String: Any] else {
            throw TerminalProfileError.invalidTemplate
        }

        let mapped = theme.mapped

        profile["name"] = theme.name
        profile["type"] = "Window Settings"
        profile["ProfileCurrentVersion"] = 2.07
        profile["useBrightBold"] = true
        profile["CursorType"] = 0

        profile["BackgroundColor"] = try mapped.background.archivedData()
        profile["TextColor"] = try mapped.text.archivedData()
        profile["TextBoldColor"] = try mapped.textBold.archivedData()
        profile["CursorColor"] = try mapped.cursor.archivedData()
        profile["SelectionColor"] = try mapped.selection.archivedData()

        for slot in mapped.ansiColors {
            profile[slot.key] = try slot.color.archivedData()
        }

        return profile
    }

    /// Escribe el perfil en `NSTemporaryDirectory()` y devuelve la URL del archivo `.terminal`.
    static func writeToTemporaryDirectory(theme: TerminalTheme) throws -> URL {
        let profile = try buildProfileDictionary(for: theme)
        let fileName = "\(theme.name.replacingOccurrences(of: " ", with: "_")).terminal"
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: profile,
            format: .xml,
            options: 0
        )

        do {
            try plistData.write(to: fileURL, options: .atomic)
        } catch {
            throw TerminalProfileError.writeFailed(error)
        }

        return fileURL
    }

    /// Registra el perfil en las preferencias de Terminal y lo marca como predeterminado.
    static func registerAsDefaultProfile(theme: TerminalTheme) throws {
        guard let defaults = UserDefaults(suiteName: "com.apple.Terminal") else {
            throw TerminalProfileError.defaultsUnavailable
        }

        var windowSettings = defaults.dictionary(forKey: "Window Settings") as? [String: Any] ?? [:]
        windowSettings[theme.name] = try buildProfileDictionary(for: theme)

        defaults.set(windowSettings, forKey: "Window Settings")
        defaults.set(theme.name, forKey: "Default Window Settings")
        defaults.set(theme.name, forKey: "Startup Window Settings")
        defaults.synchronize()
    }

    /// Genera el `.terminal`, lo abre en Terminal.app e importa el perfil.
    @MainActor
    static func install(theme: TerminalTheme, setAsDefault: Bool = false) throws -> URL {
        let fileURL = try writeToTemporaryDirectory(theme: theme)

        if setAsDefault {
            try registerAsDefaultProfile(theme: theme)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(fileURL, configuration: configuration) { _, error in
            if let error {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .terminalInstallFailed,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
            }
        }

        return fileURL
    }
}

extension Notification.Name {
    static let terminalInstallFailed = Notification.Name("terminalInstallFailed")
}