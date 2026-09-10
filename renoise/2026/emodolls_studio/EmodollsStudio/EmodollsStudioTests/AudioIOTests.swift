import XCTest
@testable import EmodollsStudio

final class AudioIOTests: XCTestCase {
    let sr = DSPSeal.sampleRate

    func testIgnoresAppleDoubleAndDotfiles() throws {
        let root = scratch("collect")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writeTone(to: root.appendingPathComponent("keep.wav"))
        try Data([0]).write(to: root.appendingPathComponent("._keep.wav"))
        try Data([0]).write(to: root.appendingPathComponent(".hidden.wav"))
        try Data([0]).write(to: root.appendingPathComponent("notes.txt"))

        let files = AudioIO.collectAudioFiles(under: root)
        XCTAssertEqual(files.map(\.lastPathComponent), ["keep.wav"])
        XCTAssertFalse(AudioIO.isSupportedAudioFile(root.appendingPathComponent("._keep.wav")))
        XCTAssertFalse(AudioIO.isSupportedAudioFile(root.appendingPathComponent(".hidden.wav")))
    }

    func testOutputNameUsesMDSuffixAndMirrorsFolders() {
        let inputRoot = URL(fileURLWithPath: "/in")
        let outputRoot = URL(fileURLWithPath: "/out")
        let input = URL(fileURLWithPath: "/in/Album/track.flac")
        let wav = AudioIO.outputURL(
            for: input,
            inputRoot: inputRoot,
            outputRoot: outputRoot,
            format: .wav
        )
        XCTAssertEqual(wav.lastPathComponent, "track_MD.wav")
        XCTAssertEqual(wav.path, "/out/Album/track_MD.wav")

        let mp3 = AudioIO.outputURL(
            for: input,
            inputRoot: inputRoot,
            outputRoot: outputRoot,
            format: .dittopro
        )
        XCTAssertEqual(mp3.pathExtension, "mp3")
        XCTAssertTrue(mp3.lastPathComponent.hasSuffix("_MD.mp3"))
    }

    func testDecodeEncodeWavRoundTrip() throws {
        let root = scratch("wav")
        let input = root.appendingPathComponent("tone.wav")
        let output = AudioIO.outputURL(for: input, inputRoot: root, outputRoot: root, format: .wav)
        try writeTone(to: input, seconds: 0.12)

        let decoded = try AudioIO.decode(input)
        XCTAssertEqual(decoded.sampleRate, sr, accuracy: 0.5)
        XCTAssertGreaterThan(decoded.interleaved.count, 100)

        var settings = RenderSettings.defaults(format: .wav)
        settings.heat = 0
        try Engine.render(input: input, settings: settings, output: output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(output.lastPathComponent, "tone_MD.wav")

        let roundtrip = try AudioIO.decode(output)
        XCTAssertEqual(roundtrip.channels, 1)
        XCTAssertEqual(roundtrip.sampleRate, sr, accuracy: 0.5)
    }

    func testEncodeM4AWritesAAC() throws {
        let root = scratch("m4a")
        let input = root.appendingPathComponent("tone.wav")
        let output = root.appendingPathComponent("tone_MD.m4a")
        try writeTone(to: input, seconds: 0.2)
        let decoded = try AudioIO.decode(input)
        let mono = MonoCollapse.mean(decoded.interleaved, channels: decoded.channels)
        let meta = MetadataDraft(title: "Prueba", artist: "emodolls", album: "Studio", track: "1", year: "2026", genre: "breakcore")
        try AudioIO.encode(mono: mono, format: .m4a, metadata: meta, to: output)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertGreaterThan((try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0, 200)
        let again = try AudioIO.decode(output)
        XCTAssertEqual(again.channels, 1)
    }

    func testEncodeDittoPROWritesMP3WithID3() throws {
        let root = scratch("mp3")
        let input = root.appendingPathComponent("tone.wav")
        let output = root.appendingPathComponent("tone_MD.mp3")
        try writeTone(to: input, seconds: 0.25)
        let decoded = try AudioIO.decode(input)
        let mono = MonoCollapse.mean(decoded.interleaved, channels: decoded.channels)
        let meta = MetadataDraft(title: "Ditto", artist: "emodolls")
        try AudioIO.encode(mono: mono, format: .dittopro, metadata: meta, to: output)

        let data = try Data(contentsOf: output)
        XCTAssertGreaterThan(data.count, 400)
        let header = String(data: data.prefix(3), encoding: .ascii)
        XCTAssertEqual(header, "ID3")
        let blob = String(data: data.prefix(200), encoding: .isoLatin1) ?? ""
        XCTAssertTrue(blob.contains("Ditto"))
        XCTAssertTrue(blob.contains("emodolls"))
    }

    private func scratch(_ name: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/emodolls-tests/\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeTone(to url: URL, seconds: Double = 0.08) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let n = Int(sr * seconds)
        let w = 2 * Float.pi * 440 / Float(sr)
        let samples = (0..<n).map { 0.2 * sin(w * Float($0)) }
        try AudioBufferIO.writePCM16(samples, channels: 1, sampleRate: sr, to: url)
    }
}
