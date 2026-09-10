import Foundation

struct Compressor {
    var thresholdDb: Float = -16
    var ratio: Float = 2.6
    var kneeDb: Float = DSPSeal.compressorKneeDb
    var makeupDb: Float = 0
    var attackCoeff: Float
    var releaseCoeff: Float
    var envelopeDb: Float = -120

    init(
        sampleRate: Double,
        thresholdDb: Float = -16,
        ratio: Float = 2.6,
        attackSeconds: Double = 0.010,
        releaseSeconds: Double = 0.065,
        makeupDb: Float = 0
    ) {
        self.thresholdDb = thresholdDb
        self.ratio = max(ratio, 1)
        self.makeupDb = makeupDb
        attackCoeff = 1 - exp(-1 / Float(max(attackSeconds * sampleRate, 1)))
        releaseCoeff = 1 - exp(-1 / Float(max(releaseSeconds * sampleRate, 1)))
    }

    mutating func process(_ input: [Float]) -> [Float] {
        let makeup = DSPSeal.dbToLinear(makeupDb)
        var output = [Float](repeating: 0, count: input.count)
        for i in input.indices {
            let x = input[i]
            let levelDb = DSPSeal.linearToDb(x)
            let coeff = levelDb > envelopeDb ? attackCoeff : releaseCoeff
            envelopeDb += coeff * (levelDb - envelopeDb)
            let grDb = gainReductionDb(levelDb: envelopeDb)
            output[i] = x * DSPSeal.dbToLinear(-grDb) * makeup
        }
        return output
    }

    private func gainReductionDb(levelDb: Float) -> Float {
        let halfKnee = kneeDb / 2
        let kneeStart = thresholdDb - halfKnee
        let kneeEnd = thresholdDb + halfKnee
        let slope = 1 - 1 / ratio
        if levelDb <= kneeStart {
            return 0
        }
        if levelDb >= kneeEnd {
            return (levelDb - thresholdDb) * slope
        }
        let x = levelDb - kneeStart
        return slope * (x * x) / (2 * kneeDb)
    }
}
