import Accelerate
import Foundation

/// ITU-R BS.1770-4 K-weighted integrated loudness (mono).
/// LRA is left free — Estreno only targets integrated LUFS.
enum Loudness {
    static let offset = -0.691
    static let absoluteGateLUFS = -70.0
    static let relativeGateLU = 10.0
    static let blockSeconds = 0.400
    static let hopSeconds = 0.100

    static func integrated(_ samples: [Float], sampleRate: Double) -> Double {
        let weighted = kWeighted(samples, sampleRate: sampleRate)
        let block = max(Int((blockSeconds * sampleRate).rounded()), 1)
        let hop = max(Int((hopSeconds * sampleRate).rounded()), 1)
        if weighted.count < block {
            return lufs(fromMeanSquare: meanSquare(weighted))
        }

        var blockLUFS: [Double] = []
        var blockMS: [Double] = []
        var start = 0
        while start + block <= weighted.count {
            let slice = Array(weighted[start..<(start + block)])
            let ms = meanSquare(slice)
            blockMS.append(ms)
            blockLUFS.append(lufs(fromMeanSquare: ms))
            start += hop
        }

        let aboveAbs = zip(blockLUFS, blockMS).filter { $0.0 > absoluteGateLUFS }
        guard !aboveAbs.isEmpty else {
            return lufs(fromMeanSquare: meanSquare(weighted))
        }
        let absMeanMS = aboveAbs.map(\.1).reduce(0, +) / Double(aboveAbs.count)
        let relative = lufs(fromMeanSquare: absMeanMS) - relativeGateLU
        let gated = zip(blockLUFS, blockMS).filter { $0.0 > relative }
        let used = gated.isEmpty ? aboveAbs : gated
        let ms = used.map(\.1).reduce(0, +) / Double(used.count)
        return lufs(fromMeanSquare: ms)
    }

    static func normalize(
        _ samples: [Float],
        sampleRate: Double,
        targetLUFS: Double = DSPSeal.estrenoLUFS
    ) -> [Float] {
        let measured = integrated(samples, sampleRate: sampleRate)
        let delta = targetLUFS - measured
        let gain = DSPSeal.dbToLinear(Float(delta))
        return vDSP.multiply(gain, samples)
    }

    private static func kWeighted(_ samples: [Float], sampleRate: Double) -> [Float] {
        var shelf = Biquad.highShelf(
            sampleRate: sampleRate,
            hz: 1681.974450955533,
            gainDb: 3.999843853973347,
            q: 0.7071752369554196
        )
        var highpass = Biquad.highpass(
            sampleRate: sampleRate,
            hz: 38.13547087602444,
            q: 0.5003270373238773
        )
        return highpass.process(shelf.process(samples))
    }

    private static func meanSquare(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 1e-12 }
        var ms: Float = 0
        vDSP_measqv(samples, 1, &ms, vDSP_Length(samples.count))
        return max(Double(ms), 1e-12)
    }

    private static func lufs(fromMeanSquare ms: Double) -> Double {
        offset + 10 * log10(max(ms, 1e-12))
    }
}
