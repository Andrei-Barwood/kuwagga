import Accelerate
import Foundation

enum MonoCollapse {
    static func mean(_ samples: [Float], channels: Int) -> [Float] {
        precondition(channels >= 1)
        if channels == 1 { return samples }
        let frames = samples.count / channels
        var mono = [Float](repeating: 0, count: frames)
        let scale = 1 / Float(channels)
        for i in 0..<frames {
            var sum: Float = 0
            let base = i * channels
            for c in 0..<channels {
                sum += samples[base + c]
            }
            mono[i] = sum * scale
        }
        return mono
    }

    static func duplicateToStereo(_ mono: [Float]) -> [Float] {
        var stereo = [Float](repeating: 0, count: mono.count * 2)
        for i in mono.indices {
            stereo[i * 2] = mono[i]
            stereo[i * 2 + 1] = mono[i]
        }
        return stereo
    }
}
