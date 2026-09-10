import Foundation

struct DSPGraph {
    private var hpf: Biquad
    private var eq: EQStage
    private var compressor: Compressor
    private var hfCap: HighFrequencyCap
    private var limiter: TruePeakLimiter
    private let heat: Float
    private let sampleRate: Double
    private let loudnessTarget: Double?

    init(settings: RenderSettings, sampleRate: Double = DSPSeal.sampleRate) {
        let recipe = Recipes.for(settings.character)
        let skeleton = FrequencyTable.skeleton(genre: settings.genre, character: settings.character)
        hpf = Biquad.highpass(sampleRate: sampleRate, hz: recipe.hpfHz)
        eq = EQStage.make(
            sampleRate: sampleRate,
            skeleton: skeleton,
            recipe: recipe,
            bloom: settings.bloom,
            fangAmount: settings.fang
        )
        compressor = Compressor(
            sampleRate: sampleRate,
            ratio: recipe.ratio,
            attackSeconds: Double(recipe.attackMs) / 1000,
            releaseSeconds: Double(recipe.releaseMs) / 1000
        )
        hfCap = HighFrequencyCap(sampleRate: sampleRate)
        limiter = TruePeakLimiter(sampleRate: sampleRate, ceilingDb: settings.ceilingDb)
        heat = settings.heat
        self.sampleRate = sampleRate
        loudnessTarget = settings.loudnessTargetLUFS
    }

    mutating func process(_ mono: [Float]) -> [Float] {
        var x = hpf.process(mono)
        x = TanhSaturator.process(x, heat: heat)
        x = eq.process(x)
        x = compressor.process(x)
        x = hfCap.process(x)
        if let target = loudnessTarget {
            x = Loudness.normalize(x, sampleRate: sampleRate, targetLUFS: target)
        }
        x = limiter.process(x)
        if let target = loudnessTarget {
            let after = Loudness.integrated(x, sampleRate: sampleRate)
            if after > target + 0.25 {
                x = Loudness.normalize(x, sampleRate: sampleRate, targetLUFS: target)
                x = limiter.process(x)
            }
        }
        return x
    }
}

enum Engine {
    static func processMono(_ samples: [Float], settings: RenderSettings) -> [Float] {
        var graph = DSPGraph(settings: settings)
        return graph.process(samples)
    }

    static func render(
        input: URL,
        settings: RenderSettings,
        output: URL,
        metadata: MetadataDraft = MetadataDraft()
    ) throws {
        let decoded = try AudioIO.decode(input)
        let mono = MonoCollapse.mean(decoded.interleaved, channels: decoded.channels)
        guard !mono.isEmpty else { throw EngineError.empty }
        let processed = processMono(mono, settings: settings)
        try AudioIO.encode(
            mono: processed,
            format: settings.format,
            metadata: metadata,
            to: output
        )
    }
}

enum EngineError: Error, LocalizedError {
    case cannotRead
    case cannotWrite
    case empty
    case convertFailed
    case unsupportedFormat
    case lameMissing
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .cannotRead: return "No se pudo leer el archivo."
        case .cannotWrite: return "No se pudo escribir el archivo."
        case .empty: return "El archivo de audio está vacío."
        case .convertFailed: return "No se pudo convertir el audio a 44 100 Hz."
        case .unsupportedFormat: return "Este formato de audio no está soportado."
        case .lameMissing: return "Falta el encoder MP3 (libmp3lame)."
        case .encodeFailed: return "Falló la codificación."
        }
    }
}
