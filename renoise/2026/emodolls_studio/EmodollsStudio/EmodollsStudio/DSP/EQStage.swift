import Foundation

struct PeakBand {
    var hz: Float
    var gainDb: Float
    var q: Float
}

struct EQStage {
    private var bands: [Biquad]
    private var fang: Biquad
    private let sampleRate: Double

    init(
        sampleRate: Double,
        bands: [PeakBand],
        fang: PeakBand
    ) {
        self.sampleRate = sampleRate
        self.bands = bands.map {
            Biquad.peaking(sampleRate: sampleRate, hz: $0.hz, gainDb: $0.gainDb, q: $0.q)
        }
        self.fang = Biquad.peaking(sampleRate: sampleRate, hz: fang.hz, gainDb: fang.gainDb, q: fang.q)
    }

    mutating func process(_ input: [Float]) -> [Float] {
        var x = input
        for i in bands.indices {
            x = bands[i].process(x)
        }
        x = fang.process(x)
        return x
    }

    static func make(
        sampleRate: Double,
        skeleton: FrequencySkeleton,
        recipe: Recipe,
        bloom: Float,
        fangAmount: Float
    ) -> EQStage {
        let unity = max(DSPSeal.bloomScale(recipe.anchors.bloom), 0.001)
        let scale = DSPSeal.bloomScale(min(max(bloom, 0), 1)) / unity
        let gains = recipe.bandGainsDb
        let bands: [PeakBand] = skeleton.bandsHz.enumerated().map { index, hz in
            let gain = index < gains.count ? gains[index] : 0
            return PeakBand(hz: hz, gainDb: gain * scale, q: 0.95)
        }
        let fangRef = max(recipe.anchors.fang, 0.001)
        let fangGain = recipe.fangDb * (min(max(fangAmount, 0), 1) / fangRef)
        let fang = PeakBand(hz: skeleton.fangHz, gainDb: fangGain, q: 1.2)
        return EQStage(sampleRate: sampleRate, bands: bands, fang: fang)
    }
}
