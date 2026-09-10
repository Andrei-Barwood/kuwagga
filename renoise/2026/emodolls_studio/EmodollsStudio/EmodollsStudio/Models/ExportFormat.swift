import Foundation

enum ExportFormat: String, CaseIterable, Identifiable, Hashable, Sendable {
    case dittopro
    case m4a
    case wav

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dittopro: return "DittoPRO"
        case .m4a: return "M4A"
        case .wav: return "WAV"
        }
    }

    /// Path extension without a leading dot (`mp3`, `m4a`, `wav`).
    var pathExtension: String {
        switch self {
        case .dittopro: return "mp3"
        case .m4a: return "m4a"
        case .wav: return "wav"
        }
    }

    var dottedExtension: String { ".\(pathExtension)" }

    /// DittoPRO is true-mono content in a dual-mono stereo container (L=R).
    var duplicatesToStereo: Bool { self == .dittopro }

    var channelCount: Int { duplicatesToStereo ? 2 : 1 }

    static let filenameSuffix = "_MD"
}
