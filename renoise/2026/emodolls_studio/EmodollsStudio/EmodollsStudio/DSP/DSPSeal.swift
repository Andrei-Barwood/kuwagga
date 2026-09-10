import Foundation

enum DSPSeal {
    static let sampleRate: Double = 44_100
    static let etpcDb: Float = -1.11
    static let edpDb: Float = -1.61
    static let meditationCeilingDb: Float = -2.00
    static let estrenoLUFS: Double = -14.00
    static let lookaheadSeconds: Double = 0.008
    static let limiterReleaseSeconds: Double = 0.080
    static let oversampleFactor = 4
    static let compressorKneeDb: Float = 3
    static let bloomScaleMin: Float = 0.35
    static let bloomScaleMax: Float = 1.65
    static let fangGainMaxDb: Float = 6

    static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    static func bloomScale(_ bloom: Float) -> Float {
        lerp(bloomScaleMin, bloomScaleMax, min(max(bloom, 0), 1))
    }

    static func dbToLinear(_ db: Float) -> Float {
        pow(10, db / 20)
    }

    static func linearToDb(_ x: Float) -> Float {
        20 * log10(max(abs(x), 1e-12))
    }

    static func ceilingDb(for format: ExportFormat) -> Float {
        format.duplicatesToStereo ? edpDb : etpcDb
    }
}
