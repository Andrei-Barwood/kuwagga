import XCTest
@testable import EmodollsStudio

@MainActor
final class SessionTests: XCTestCase {
    let sr = DSPSeal.sampleRate

    func testFolderOverTenTakesFirstTenAndWarnsInSpanish() throws {
        let root = scratch("over-ten")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for i in 0..<12 {
            try writeTone(to: root.appendingPathComponent(String(format: "t%02d.wav", i)))
        }

        let session = Session()
        session.addFolder(root)

        XCTAssertEqual(session.tracks.count, 10)
        XCTAssertEqual(session.tracks.first?.lastPathComponent, "t00.wav")
        XCTAssertEqual(session.tracks.last?.lastPathComponent, "t09.wav")
        XCTAssertNotNil(session.truncatedWarning)
        XCTAssertTrue(session.truncatedWarning?.contains("12") == true)
        XCTAssertTrue(session.truncatedWarning?.contains("10") == true)
        XCTAssertTrue(session.truncatedWarning?.contains("primeros") == true)
    }

    func testDryRunListsDestinationsWithoutWriting() async throws {
        let root = scratch("dry")
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writeTone(to: root.appendingPathComponent("a.wav"))
        try writeTone(to: root.appendingPathComponent("b.wav"))

        let session = Session()
        session.addFolder(root)
        session.outputRoot = output

        Processor.preview(session: session, format: .wav)
        XCTAssertEqual(session.preview.count, 2)
        XCTAssertTrue(session.preview.allSatisfy { $0.lastPathComponent.hasSuffix("_MD.wav") })
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.preview[0].path))

        await Processor.run(
            session: session,
            settings: RenderSettings.defaults(format: .wav),
            metadata: MetadataDraft(),
            dryRun: true
        )
        XCTAssertEqual(session.preview.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.preview[0].path))
        XCTAssertTrue(session.failures.isEmpty)
        XCTAssertEqual(session.progress.fraction, 1, accuracy: 0.001)
    }

    func testOverwriteFalseSkipsExisting() async throws {
        let root = scratch("skip")
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try writeTone(to: root.appendingPathComponent("keep.wav"))

        let session = Session()
        session.addFolder(root)
        session.outputRoot = output
        session.overwrite = false

        let dest = AudioIO.outputURL(
            for: session.tracks[0],
            inputRoot: root,
            outputRoot: output,
            format: .wav
        )
        try Data("placeholder".utf8).write(to: dest)
        let before = try Data(contentsOf: dest)

        var settings = RenderSettings.defaults(format: .wav)
        settings.heat = 0
        await Processor.run(session: session, settings: settings, metadata: MetadataDraft(), dryRun: false)

        let after = try Data(contentsOf: dest)
        XCTAssertEqual(before, after)
        XCTAssertTrue(session.failures.isEmpty)
    }

    func testQueueContinuesAfterFailure() async throws {
        let root = scratch("fail-continue")
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let good = root.appendingPathComponent("good.wav")
        try writeTone(to: good)

        let session = Session()
        session.addFiles([root.appendingPathComponent("missing.wav"), good])
        session.tracks = [root.appendingPathComponent("missing.wav"), good]
        session.outputRoot = output
        session.overwrite = true

        var settings = RenderSettings.defaults(format: .wav)
        settings.heat = 0
        await Processor.run(session: session, settings: settings, metadata: MetadataDraft(), dryRun: false)

        XCTAssertEqual(session.failures.count, 1)
        XCTAssertEqual(session.failures[0].path.lastPathComponent, "missing.wav")
        let dest = AudioIO.outputURL(for: good, inputRoot: nil, outputRoot: output, format: .wav)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
    }

    func testCancelIsCooperative() {
        let session = Session()
        XCTAssertFalse(session.cancelRequested)
        session.requestCancel()
        XCTAssertTrue(session.cancelRequested)
        session.resetCancel()
        XCTAssertFalse(session.cancelRequested)
    }

    func testProgressPublishedOnMainActor() async throws {
        let root = scratch("progress")
        let output = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try writeTone(to: root.appendingPathComponent("p.wav"), seconds: 0.05)

        let session = Session()
        session.addFolder(root)
        session.outputRoot = output
        session.overwrite = true

        var settings = RenderSettings.defaults(format: .wav)
        settings.heat = 0
        await Processor.run(session: session, settings: settings, metadata: MetadataDraft(), dryRun: false)

        XCTAssertEqual(session.progress.total, 1)
        XCTAssertEqual(session.progress.index, 1)
        XCTAssertEqual(session.progress.fraction, 1, accuracy: 0.001)
        XCTAssertFalse(session.isRunning)
    }

    private func scratch(_ name: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/emodolls-tests/\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func writeTone(to url: URL, seconds: Double = 0.06) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let n = Int(sr * seconds)
        let w = 2 * Float.pi * 440 / Float(sr)
        let samples = (0..<n).map { 0.2 * sin(w * Float($0)) }
        try AudioBufferIO.writePCM16(samples, channels: 1, sampleRate: sr, to: url)
    }
}
