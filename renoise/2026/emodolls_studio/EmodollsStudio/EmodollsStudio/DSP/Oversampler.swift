import Accelerate
import Foundation

enum Oversampler {
    static let factor = DSPSeal.oversampleFactor
    static let taps: [Float] = makeTaps(count: 63)

    static func upsample(_ input: [Float]) -> [Float] {
        var stuffed = [Float](repeating: 0, count: input.count * factor)
        for i in input.indices {
            stuffed[i * factor] = input[i]
        }
        return convSame(stuffed, vDSP.multiply(Float(factor), taps))
    }

    static func downsample(_ oversampled: [Float]) -> [Float] {
        let filtered = convSame(oversampled, taps)
        let n = filtered.count / factor
        var output = [Float](repeating: 0, count: n)
        for i in 0..<n {
            output[i] = filtered[i * factor]
        }
        return output
    }

    static func truePeakDb(_ input: [Float]) -> Float {
        let os = upsample(input)
        var maxMag: Float = 0
        vDSP_maxmgv(os, 1, &maxMag, vDSP_Length(os.count))
        return DSPSeal.linearToDb(maxMag)
    }

    private static func makeTaps(count: Int) -> [Float] {
        let n = count | 1
        let mid = (n - 1) / 2
        let fc = 0.5 / Double(factor)
        var taps = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i - mid)
            let sinc: Double
            if t == 0 {
                sinc = 2 * fc
            } else {
                sinc = sin(2 * Double.pi * fc * t) / (Double.pi * t)
            }
            let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(n - 1))
            taps[i] = Float(sinc * window)
        }
        var sum: Float = 0
        vDSP_sve(taps, 1, &sum, vDSP_Length(n))
        if abs(sum) > 1e-12 {
            vDSP.divide(taps, sum, result: &taps)
        }
        return taps
    }

    private static func convSame(_ x: [Float], _ h: [Float]) -> [Float] {
        let p = h.count
        let n = x.count
        var padded = [Float](repeating: 0, count: n + p - 1)
        let pre = p / 2
        for i in 0..<n {
            padded[pre + i] = x[i]
        }
        var y = [Float](repeating: 0, count: n)
        vDSP_conv(padded, 1, h, 1, &y, 1, vDSP_Length(n), vDSP_Length(p))
        return y
    }
}
