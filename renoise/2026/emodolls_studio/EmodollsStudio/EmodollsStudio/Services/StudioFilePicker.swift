import AppKit
import UniformTypeIdentifiers

@MainActor
enum StudioFilePicker {
    static func pickAudioFiles() async -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = Self.audioTypes
        panel.message = "Elige hasta 10 archivos de audio."
        panel.prompt = "Abrir"
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.filter { $0.startAccessingSecurityScopedResource() || true }
    }

    static func pickDirectory(prompt: String) async -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = prompt
        panel.prompt = "Elegir"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    private static var audioTypes: [UTType] {
        var types: [UTType] = [.wav, .aiff, .mp3, .mpeg4Audio, .audio]
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        if let opus = UTType(filenameExtension: "opus") { types.append(opus) }
        if let aif = UTType(filenameExtension: "aif") { types.append(aif) }
        return types
    }
}
