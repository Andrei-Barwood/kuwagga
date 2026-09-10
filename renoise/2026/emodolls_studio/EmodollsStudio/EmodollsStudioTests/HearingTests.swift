import Accelerate
import XCTest
@testable import EmodollsStudio

final class HearingTests: XCTestCase {
    let sr = DSPSeal.sampleRate
    let seconds = 12.0

    func testHearingPassRendersSealedMonoWAV() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/emodolls-hearing", isDirectory: true)
        let inputDir = root.appendingPathComponent("in", isDirectory: true)
        let outputDir = root.appendingPathComponent("out", isDirectory: true)
        try FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        let burst = HearingSynth.burst(sr: sr, seconds: seconds)
        let sub = HearingSynth.sub(sr: sr, seconds: seconds)
        let pad = HearingSynth.pad(sr: sr, seconds: seconds)
        let sitar = HearingSynth.sitar(sr: sr, seconds: seconds)

        let sources: [(String, [Float])] = [
            ("burst", burst),
            ("sub", sub),
            ("pad", pad),
            ("sitar", sitar),
        ]
        for (name, samples) in sources {
            try AudioBufferIO.writePCM16(
                HearingSynth.stereoWiden(samples),
                channels: 2,
                sampleRate: sr,
                to: inputDir.appendingPathComponent("\(name).wav")
            )
        }

        let jobs: [(file: String, character: CharacterID, estreno: Bool)] = [
            ("burst", .obsesion, false),
            ("sub", .subsoil, false),
            ("pad", .mallsoft, false),
            ("sitar", .aartiViva, false),
            ("sitar", .shunya, false),
            ("pad", .mallsoft, true),
        ]

        var notes: [String] = []
        for job in jobs {
            let input = inputDir.appendingPathComponent("\(job.file).wav")
            let tag = job.estreno ? "\(job.character.rawValue)_estreno" : job.character.rawValue
            let namedInput = inputDir.appendingPathComponent("\(job.file)__\(tag).wav")
            try? FileManager.default.removeItem(at: namedInput)
            try FileManager.default.copyItem(at: input, to: namedInput)
            let dest = AudioIO.outputURL(
                for: namedInput,
                inputRoot: inputDir,
                outputRoot: outputDir,
                format: .wav
            )

            var settings = RenderSettings.defaults(genre: job.character.genre, format: .wav)
            settings.character = job.character
            let recipe = Recipes.for(job.character)
            settings.heat = recipe.anchors.heat
            settings.bloom = recipe.anchors.bloom
            settings.fang = recipe.anchors.fang
            settings.estreno = job.estreno

            try Engine.render(input: namedInput, settings: settings, output: dest)

            XCTAssertTrue(dest.lastPathComponent.hasSuffix("_MD.wav"), dest.lastPathComponent)
            let header = try wavHeader(dest)
            XCTAssertEqual(header.sampleRate, 44100)
            XCTAssertEqual(header.channels, 1)
            XCTAssertEqual(header.bits, 16)

            let decoded = try AudioIO.decode(dest)
            XCTAssertEqual(decoded.channels, 1)
            XCTAssertEqual(decoded.sampleRate, sr, accuracy: 0.5)
            let tp = Oversampler.truePeakDb(decoded.interleaved)
            let ceiling = job.estreno ? DSPSeal.etpcDb : recipe.ceilingDb
            XCTAssertLessThanOrEqual(tp, ceiling + 0.05, "\(tag) TP \(tp)")

            let srcMono = MonoCollapse.mean(
                HearingSynth.stereoWiden(sources.first { $0.0 == job.file }!.1),
                channels: 2
            )
            let inCrest = HearingSynth.crestDb(srcMono)
            let outCrest = HearingSynth.crestDb(decoded.interleaved)
            let subIn = HearingSynth.bandEnergy(srcMono, sr: sr, low: 30, high: 80)
            let subOut = HearingSynth.bandEnergy(decoded.interleaved, sr: sr, low: 30, high: 80)
            let lufs = Loudness.integrated(decoded.interleaved, sampleRate: sr)

            if job.estreno {
                XCTAssertEqual(lufs, DSPSeal.estrenoLUFS, accuracy: 1.0)
            }

            notes.append(
                String(
                    format: "%@: TP=%.2f crest in/out=%.1f/%.1f sub=%.2f→%.2f LUFS=%.1f file=%@",
                    tag, tp, inCrest, outCrest, subIn, subOut, lufs, dest.lastPathComponent
                )
            )

            if job.character == .obsesion {
                XCTAssertGreaterThan(outCrest, 6, "Obsesión aplastó transientes (crest \(outCrest) dB)")
            }
            if job.character == .subsoil {
                XCTAssertGreaterThan(subOut, subIn * 0.25, "Subsoil vació el sub")
            }
        }

        let report = notes.joined(separator: "\n")
        let reportURL = outputDir.appendingPathComponent("hearing-report.txt")
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        NSLog("HEARING REPORT\n\(report)")
    }
}

enum HearingSynth {
    static func burst(sr: Double, seconds: Double) -> [Float] {
        let n = Int(sr * seconds)
        var x = [Float](repeating: 0, count: n)
        let srF = Float(sr)
        for i in 0..<n {
            let t = Float(i) / srF
            let kickPhase = t.truncatingRemainder(dividingBy: 0.45)
            let kick = sin(2 * .pi * 52 * kickPhase) * exp(-kickPhase * 18)
            let click = kickPhase < 0.004 ? (1 - kickPhase / 0.004) * 0.4 : 0
            var noise: Float = 0
            if kickPhase > 0.08, kickPhase < 0.14 {
                noise = (Float.random(in: -1...1)) * 0.22 * sin(2 * .pi * 3500 * t)
            }
            x[i] = 0.72 * kick + click + noise
        }
        return x
    }

    static func sub(sr: Double, seconds: Double) -> [Float] {
        let n = Int(sr * seconds)
        var x = [Float](repeating: 0, count: n)
        let srF = Float(sr)
        for i in 0..<n {
            let t = Float(i) / srF
            let wobble = 0.55 + 0.45 * sin(2 * .pi * 3.2 * t)
            let fundamental = sin(2 * .pi * 46 * t) * wobble
            let second = 0.18 * sin(2 * .pi * 92 * t) * wobble
            x[i] = 0.65 * (fundamental + second)
        }
        return x
    }

    static func pad(sr: Double, seconds: Double) -> [Float] {
        let n = Int(sr * seconds)
        var x = [Float](repeating: 0, count: n)
        let srF = Float(sr)
        let freqs: [Float] = [220, 277.2, 329.6, 440]
        for i in 0..<n {
            let t = Float(i) / srF
            let env = min(1, t / 1.8) * (0.7 + 0.3 * sin(2 * .pi * 0.12 * t))
            var s: Float = 0
            for (k, f) in freqs.enumerated() {
                let detune = f * (1 + 0.003 * Float(k - 1))
                s += sin(2 * .pi * detune * t + 0.4 * sin(2 * .pi * 0.2 * t))
            }
            x[i] = 0.18 * s * env
        }
        return x
    }

    static func sitar(sr: Double, seconds: Double) -> [Float] {
        let n = Int(sr * seconds)
        var x = [Float](repeating: 0, count: n)
        let srF = Float(sr)
        let pluckTimes: [Float] = [0.2, 1.5, 2.7, 4.1, 5.6, 7.0, 8.4, 9.8, 11.0]
        let root: Float = 146.8
        for i in 0..<n {
            let t = Float(i) / srF
            var s: Float = 0.08 * sin(2 * .pi * (root / 2) * t)
            s += 0.05 * sin(2 * .pi * (root * 1.5) * t)
            for p in pluckTimes {
                let dt = t - p
                if dt >= 0, dt < 1.4 {
                    var pluck: Float = 0
                    for h in 1...8 {
                        let inharm = 1 + 0.0008 * Float(h * h)
                        pluck += (1 / Float(h)) * sin(2 * .pi * root * Float(h) * inharm * dt)
                    }
                    s += pluck * exp(-dt * 3.2) * 0.22
                }
            }
            x[i] = s
        }
        return x
    }

    static func stereoWiden(_ mono: [Float]) -> [Float] {
        var stereo = [Float](repeating: 0, count: mono.count * 2)
        for i in mono.indices {
            stereo[i * 2] = mono[i] * 0.98
            stereo[i * 2 + 1] = mono[i] * 1.02
        }
        return stereo
    }

    static func crestDb(_ x: [Float]) -> Float {
        var peak: Float = 0
        var ms: Float = 0
        vDSP_maxmgv(x, 1, &peak, vDSP_Length(x.count))
        vDSP_measqv(x, 1, &ms, vDSP_Length(x.count))
        let rms = sqrt(max(ms, 1e-12))
        return 20 * log10(max(peak, 1e-12) / rms)
    }

    static func bandEnergy(_ x: [Float], sr: Double, low: Float, high: Float) -> Float {
        var bp = Biquad.bandpass(sampleRate: sr, hz: sqrt(low * high), q: sqrt(high / low))
        let y = bp.process(x)
        var ms: Float = 0
        vDSP_measqv(y, 1, &ms, vDSP_Length(y.count))
        return ms
    }
}

private struct WAVHeader {
    var sampleRate: Int
    var channels: Int
    var bits: Int
}

private func wavHeader(_ url: URL) throws -> WAVHeader {
    let data = try Data(contentsOf: url)
    guard data.count > 44 else { throw EngineError.cannotRead }
    let ch = Int(data[22]) | (Int(data[23]) << 8)
    let sr = Int(data[24]) | (Int(data[25]) << 8) | (Int(data[26]) << 16) | (Int(data[27]) << 24)
    let bits = Int(data[34]) | (Int(data[35]) << 8)
    return WAVHeader(sampleRate: sr, channels: ch, bits: bits)
}
