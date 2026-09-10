import Accelerate
import Foundation

enum TanhSaturator {
    /// heat = 0 is identity. heat > 0 blends a normalized tanh with makeup
    /// so RMS stays roughly in the same neighborhood.
    static func process(_ input: [Float], heat: Float) -> [Float] {
        let amount = min(max(heat, 0), 1)
        if amount <= 0 {
            return input
        }

        let drive = 1 + amount * 7
        var scaled = vDSP.multiply(drive, input)
        var wet = [Float](repeating: 0, count: input.count)
        var count = Int32(input.count)
        vvtanhf(&wet, &scaled, &count)

        let norm = tanhf(drive)
        let makeup = (norm > 1e-6) ? (1 / norm) : 1
        vDSP.multiply(makeup, wet, result: &wet)

        if amount >= 1 {
            return wet
        }

        let dry = vDSP.multiply(1 - amount, input)
        let wetMix = vDSP.multiply(amount, wet)
        return vDSP.add(dry, wetMix)
    }
}
