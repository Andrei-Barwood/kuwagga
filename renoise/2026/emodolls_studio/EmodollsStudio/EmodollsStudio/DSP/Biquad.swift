import Foundation

struct Biquad {
    var b0: Float = 1
    var b1: Float = 0
    var b2: Float = 0
    var a1: Float = 0
    var a2: Float = 0
    var z1: Float = 0
    var z2: Float = 0

    mutating func reset() {
        z1 = 0
        z2 = 0
    }

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    mutating func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        for i in input.indices {
            output[i] = process(input[i])
        }
        return output
    }

    static func highpass(sampleRate: Double, hz: Float, q: Float = 0.707) -> Biquad {
        rbj(sampleRate: sampleRate, hz: hz, q: q, gainDb: 0, type: .highpass)
    }

    static func peaking(sampleRate: Double, hz: Float, gainDb: Float, q: Float = 1.0) -> Biquad {
        rbj(sampleRate: sampleRate, hz: hz, q: q, gainDb: gainDb, type: .peaking)
    }

    static func bandpass(sampleRate: Double, hz: Float, q: Float) -> Biquad {
        rbj(sampleRate: sampleRate, hz: hz, q: q, gainDb: 0, type: .bandpass)
    }

    static func highShelf(sampleRate: Double, hz: Float, gainDb: Float, q: Float) -> Biquad {
        rbj(sampleRate: sampleRate, hz: hz, q: q, gainDb: gainDb, type: .highShelf)
    }

    private enum Kind { case highpass, peaking, bandpass, highShelf }

    private static func rbj(
        sampleRate: Double,
        hz: Float,
        q: Float,
        gainDb: Float,
        type: Kind
    ) -> Biquad {
        let sr = Float(sampleRate)
        let f = min(max(hz, 1), sr * 0.45)
        let w0 = 2 * Float.pi * f / sr
        let cosw = cos(w0)
        let sinw = sin(w0)
        let alpha = sinw / (2 * max(q, 0.05))
        let a = pow(10 as Float, gainDb / 40)

        var b0: Float = 1, b1: Float = 0, b2: Float = 0
        var a0: Float = 1, a1: Float = 0, a2: Float = 0

        switch type {
        case .highpass:
            b0 = (1 + cosw) / 2
            b1 = -(1 + cosw)
            b2 = (1 + cosw) / 2
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        case .peaking:
            b0 = 1 + alpha * a
            b1 = -2 * cosw
            b2 = 1 - alpha * a
            a0 = 1 + alpha / a
            a1 = -2 * cosw
            a2 = 1 - alpha / a
        case .bandpass:
            b0 = alpha
            b1 = 0
            b2 = -alpha
            a0 = 1 + alpha
            a1 = -2 * cosw
            a2 = 1 - alpha
        case .highShelf:
            let twoSqrtA = 2 * sqrt(a) * alpha
            b0 = a * ((a + 1) + (a - 1) * cosw + twoSqrtA)
            b1 = -2 * a * ((a - 1) + (a + 1) * cosw)
            b2 = a * ((a + 1) + (a - 1) * cosw - twoSqrtA)
            a0 = (a + 1) - (a - 1) * cosw + twoSqrtA
            a1 = 2 * ((a - 1) - (a + 1) * cosw)
            a2 = (a + 1) - (a - 1) * cosw - twoSqrtA
        }

        return Biquad(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }
}
