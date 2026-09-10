import XCTest
@testable import EmodollsStudio

final class EstrenoTests: XCTestCase {
    func testEstrenoSineHitsMinus14AndRespectsTruePeak() {
        let sr = DSPSeal.sampleRate
        let amplitude = DSPSeal.dbToLinear(-6)
        let n = Int(sr * 5)
        let w = 2 * Float.pi * 1000 / Float(sr)
        let sine = (0..<n).map { amplitude * sin(w * Float($0)) }

        var settings = RenderSettings.defaults(format: .wav)
        let heat = settings.heat
        let bloom = settings.bloom
        let fang = settings.fang
        let character = settings.character
        settings.estreno = true

        let out = Engine.processMono(sine, settings: settings)
        let integrated = Loudness.integrated(out, sampleRate: sr)
        let tp = Oversampler.truePeakDb(out)

        XCTAssertEqual(integrated, DSPSeal.estrenoLUFS, accuracy: 0.5)
        XCTAssertLessThanOrEqual(tp, DSPSeal.etpcDb + 0.03)

        XCTAssertEqual(settings.heat, heat)
        XCTAssertEqual(settings.bloom, bloom)
        XCTAssertEqual(settings.fang, fang)
        XCTAssertEqual(settings.character, character)
    }

    func testEstrenoOffLeavesLoudnessUntargeted() {
        let sr = DSPSeal.sampleRate
        let amplitude = DSPSeal.dbToLinear(-20)
        let n = Int(sr * 1)
        let w = 2 * Float.pi * 1000 / Float(sr)
        let sine = (0..<n).map { amplitude * sin(w * Float($0)) }

        var off = RenderSettings.defaults(format: .wav)
        off.estreno = false
        off.heat = 0
        let out = Engine.processMono(sine, settings: off)
        let integrated = Loudness.integrated(out, sampleRate: sr)
        XCTAssertNotEqual(integrated, DSPSeal.estrenoLUFS, accuracy: 0.5)
        XCTAssertNil(off.loudnessTargetLUFS)
    }
}
