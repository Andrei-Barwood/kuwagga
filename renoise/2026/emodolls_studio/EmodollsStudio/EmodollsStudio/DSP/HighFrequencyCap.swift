import Foundation

struct HighFrequencyCap {
    private var band: Biquad
    private var envelope: Float = 0
    private let attackCoeff: Float
    private let releaseCoeff: Float
    private let threshold: Float
    private let maxReduction: Float

    init(
        sampleRate: Double,
        lowHz: Float = 5000,
        highHz: Float = 8000,
        thresholdDb: Float = -18,
        maxReductionDb: Float = 6
    ) {
        let center = sqrt(lowHz * highHz)
        let q: Float = center / max(highHz - lowHz, 100)
        band = Biquad.bandpass(sampleRate: sampleRate, hz: center, q: min(max(q, 0.7), 2.2))
        attackCoeff = 1 - exp(-1 / Float(0.004 * sampleRate))
        releaseCoeff = 1 - exp(-1 / Float(0.080 * sampleRate))
        threshold = DSPSeal.dbToLinear(thresholdDb)
        maxReduction = 1 - DSPSeal.dbToLinear(-maxReductionDb)
    }

    mutating func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        for i in input.indices {
            let x = input[i]
            let hf = band.process(x)
            let level = abs(hf)
            let coeff = level > envelope ? attackCoeff : releaseCoeff
            envelope += coeff * (level - envelope)
            var duck: Float = 0
            if envelope > threshold {
                let over = (envelope - threshold) / max(envelope, 1e-6)
                duck = min(maxReduction, over * maxReduction)
            }
            output[i] = x - hf * duck
        }
        return output
    }
}
