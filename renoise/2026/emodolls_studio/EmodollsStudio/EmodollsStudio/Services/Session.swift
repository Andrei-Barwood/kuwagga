import Foundation

struct JobFailure: Equatable, Identifiable, Sendable {
    var path: URL
    var message: String

    var id: String { path.path }
}

struct SessionProgress: Equatable, Sendable {
    var index: Int = 0
    var total: Int = 0
    var fraction: Double = 0
    var currentName: String = ""

    var label: String {
        guard total > 0 else { return "" }
        return "\(index)/\(total)"
    }
}

@MainActor
final class Session: ObservableObject {
    @Published var tracks: [URL] = []
    @Published var inputRoot: URL?
    @Published var outputRoot: URL?
    @Published var overwrite = false
    @Published var truncatedWarning: String?
    @Published var progress = SessionProgress()
    @Published var failures: [JobFailure] = []
    @Published var preview: [URL] = []
    @Published var isRunning = false
    @Published private(set) var cancelRequested = false

    func addFiles(_ urls: [URL]) {
        let audio = urls.filter { AudioIO.isSupportedAudioFile($0) }
        ingest(audio, replacingRoot: nil)
    }

    func addFolder(_ url: URL) {
        inputRoot = url
        ingest(AudioIO.collectAudioFiles(under: url), replacingRoot: url)
    }

    func clearTracks() {
        tracks = []
        truncatedWarning = nil
        failures = []
        preview = []
        progress = SessionProgress()
    }

    func requestCancel() {
        cancelRequested = true
    }

    func resetCancel() {
        cancelRequested = false
    }

    private func ingest(_ urls: [URL], replacingRoot: URL?) {
        var combined = tracks + urls
        var seen = Set<String>()
        combined = combined.filter { url in
            let key = url.standardizedFileURL.path
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        combined.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

        if combined.count > SessionLimits.maxTracks {
            truncatedWarning =
                "Hay \(combined.count) archivos de audio. Solo se tomarán los \(SessionLimits.maxTracks) primeros, en orden de ruta."
            tracks = Array(combined.prefix(SessionLimits.maxTracks))
        } else {
            truncatedWarning = nil
            tracks = combined
        }

        if let replacingRoot {
            inputRoot = replacingRoot
        }
    }
}
