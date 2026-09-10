import XCTest
@testable import EmodollsStudio

final class DSPTests: XCTestCase {
    let sr = DSPSeal.sampleRate

    func testOutOfPhaseStereoCollapsesAndDuplicatesIdentically() {
        let n = Int(sr * 0.25)
        var stereo = [Float](repeating: 0, count: n * 2)
        let w = 2 * Float.pi * 440 / Float(sr)
        for i in 0..<n {
            stereo[i * 2] = sin(w * Float(i))
            stereo[i * 2 + 1] = cos(w * Float(i))
        }

        let mono = MonoCollapse.mean(stereo, channels: 2)
        XCTAssertEqual(mono.count, n)

        var settings = RenderSettings.defaults()
        settings.format = .dittopro
        let processed = Engine.processMono(mono, settings: settings)
        let dual = MonoCollapse.duplicateToStereo(processed)
        XCTAssertEqual(dual.count, processed.count * 2)

        var maxDiff: Float = 0
        for i in 0..<processed.count {
            maxDiff = max(maxDiff, abs(dual[i * 2] - dual[i * 2 + 1]))
        }
        XCTAssertEqual(maxDiff, 0, accuracy: 1e-7)
        XCTAssertEqual(settings.format.channelCount, 2)
    }

    func testTruePeakLimiterLandsOnETPC() {
        let sine = tone(hz: 997, seconds: 0.35, amplitude: 1)
        var limiter = TruePeakLimiter(sampleRate: sr, ceilingDb: DSPSeal.etpcDb)
        let limited = limiter.process(sine)
        let tp = Oversampler.truePeakDb(limited)
        XCTAssertEqual(tp, DSPSeal.etpcDb, accuracy: 0.03)
    }

    func testTruePeakLimiterHoldsClickUnderCeiling() {
        let n = Int(sr * 0.25)
        var click = [Float](repeating: 0, count: n)
        click[64] = 1
        click[65] = -0.7
        var limiter = TruePeakLimiter(sampleRate: sr, ceilingDb: DSPSeal.etpcDb)
        let limited = limiter.process(click)
        let tp = Oversampler.truePeakDb(limited)
        XCTAssertLessThanOrEqual(tp, DSPSeal.etpcDb + 0.03)
    }

    func testCalibratedPeakEngineWAVTruePeak() throws {
        let sine = tone(hz: 997, seconds: 0.2, amplitude: 1)
        var settings = RenderSettings.defaults(format: .wav)
        settings.heat = 0
        settings.bloom = 0.5
        settings.fang = 0
        settings.estreno = false

        let processed = Engine.processMono(sine, settings: settings)
        let wavPath = TPDFDither.apply(processed)
        let tp = Oversampler.truePeakDb(wavPath)
        XCTAssertLessThanOrEqual(tp, DSPSeal.etpcDb + 0.03)

        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/emodolls-tests", isDirectory: true)
        let input = dir.appendingPathComponent("in.wav")
        let output = dir.appendingPathComponent("out.wav")
        try AudioBufferIO.writePCM16(sine, channels: 1, sampleRate: sr, to: input)
        try Engine.render(input: input, settings: settings, output: output)
        let decoded = try AudioBufferIO.read(output)
        XCTAssertEqual(decoded.channels, 1)
        let fileTp = Oversampler.truePeakDb(decoded.interleaved)
        XCTAssertLessThanOrEqual(fileTp, DSPSeal.etpcDb + 0.03)
        try? FileManager.default.removeItem(at: dir)
    }

    func testEstrenoOffHasNoLoudnessTarget() {
        var settings = RenderSettings.defaults()
        settings.estreno = false
        XCTAssertNil(settings.loudnessTargetLUFS)

        settings.estreno = true
        XCTAssertEqual(settings.loudnessTargetLUFS, DSPSeal.estrenoLUFS)
    }

    func testHeatZeroIsNearlyLinear() {
        let sine = tone(hz: 1000, seconds: 0.4, amplitude: DSPSeal.dbToLinear(-18))
        var settings = RenderSettings.defaults()
        settings.heat = 0
        settings.bloom = 0.5
        settings.fang = 0
        let out = Engine.processMono(sine, settings: settings)
        let thd = harmonicDistortion(out, sr: Float(sr), f0: 1000)
        XCTAssertLessThan(thd, 0.02, "THD at heat=0 should stay low, got \(thd)")
    }

    func testDittoPROUsesEDPCeiling() {
        var settings = RenderSettings.defaults(format: .dittopro)
        XCTAssertEqual(settings.ceilingDb, DSPSeal.edpDb, accuracy: 0.0001)
        var wav = RenderSettings.defaults(format: .wav)
        XCTAssertEqual(wav.ceilingDb, DSPSeal.etpcDb, accuracy: 0.0001)
        wav.format = .m4a
        XCTAssertEqual(wav.ceilingDb, DSPSeal.etpcDb, accuracy: 0.0001)
    }

    func testBloomScaleUnityAtHalf() {
        XCTAssertEqual(DSPSeal.bloomScale(0.5), 1.0, accuracy: 0.0001)
        XCTAssertEqual(DSPSeal.bloomScale(0), 0.35, accuracy: 0.0001)
        XCTAssertEqual(DSPSeal.bloomScale(1), 1.65, accuracy: 0.0001)
    }

    private func tone(hz: Float, seconds: Double, amplitude: Float) -> [Float] {
        let n = Int(sr * seconds)
        let w = 2 * Float.pi * hz / Float(sr)
        return (0..<n).map { amplitude * sin(w * Float($0)) }
    }

    private func harmonicDistortion(_ x: [Float], sr: Float, f0: Float) -> Float {
        func mag(_ freq: Float) -> Float {
            var re: Float = 0
            var im: Float = 0
            let w = 2 * Float.pi * freq / sr
            for i in x.indices {
                let t = Float(i)
                re += x[i] * cos(w * t)
                im -= x[i] * sin(w * t)
            }
            return sqrt(re * re + im * im)
        }
        let fund = mag(f0)
        var harm: Float = 0
        for h in 2...8 {
            let m = mag(f0 * Float(h))
            harm += m * m
        }
        return sqrt(harm) / max(fund, 1e-12)
    }
}
