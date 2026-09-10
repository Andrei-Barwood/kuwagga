import Accelerate
import Foundation

struct TruePeakLimiter {
    var ceiling: Float
    private let lookahead: Int
    private let releaseCoeff: Float

    init(sampleRate: Double, ceilingDb: Float) {
        ceiling = DSPSeal.dbToLinear(ceilingDb)
        let osRate = sampleRate * Double(Oversampler.factor)
        lookahead = max(Int((DSPSeal.lookaheadSeconds * osRate).rounded()), 1)
        let releaseSamples = max(DSPSeal.limiterReleaseSeconds * osRate, 1)
        releaseCoeff = 1 - exp(-1 / Float(releaseSamples))
    }

    func process(_ input: [Float]) -> [Float] {
        let os = Oversampler.upsample(input)
        let limited = limitOversampled(os)
        var down = Oversampler.downsample(limited)
        if down.count > input.count {
            down = Array(down.prefix(input.count))
        } else if down.count < input.count {
            down += [Float](repeating: 0, count: input.count - down.count)
        }
        // FIR decimation can reconstruct inter-sample peaks above the
        // oversampled ceiling (kicks). Scale the whole buffer so measured
        // TP lands on the seal; crest is unchanged.
        return clampTruePeak(down)
    }

    private func clampTruePeak(_ x: [Float]) -> [Float] {
        guard !x.isEmpty else { return x }
        let measured = Oversampler.upsample(x)
        var maxMag: Float = 0
        vDSP_maxmgv(measured, 1, &maxMag, vDSP_Length(measured.count))
        if maxMag <= ceiling || maxMag < 1e-12 {
            return x
        }
        var out = [Float](repeating: 0, count: x.count)
        vDSP.multiply(ceiling / maxMag, x, result: &out)
        return out
    }

    private func limitOversampled(_ os: [Float]) -> [Float] {
        let n = os.count
        let pad = lookahead
        var padded = os
        padded.append(contentsOf: repeatElement(Float(0), count: pad))

        var delay = [Float](repeating: 0, count: pad)
        var delayIndex = 0
        var running = RunningMax(window: pad + 1)
        var gain: Float = 1
        var delayedOut = [Float](repeating: 0, count: padded.count)

        for i in padded.indices {
            let x = padded[i]
            let delayed = delay[delayIndex]
            delay[delayIndex] = x
            delayIndex += 1
            if delayIndex == pad { delayIndex = 0 }

            let windowMax = running.push(abs(x))
            let needed = min(1, ceiling / max(windowMax, 1e-12))
            if needed < gain {
                gain = needed
            } else {
                gain += releaseCoeff * (needed - gain)
            }
            delayedOut[i] = delayed * gain
        }

        if pad >= delayedOut.count {
            return Array(delayedOut.prefix(n))
        }
        let trimmed = Array(delayedOut[pad..<min(pad + n, delayedOut.count)])
        if trimmed.count < n {
            return trimmed + [Float](repeating: 0, count: n - trimmed.count)
        }
        return trimmed
    }
}

private struct RunningMax {
    let window: Int
    private var deque: [(index: Int, value: Float)] = []
    private var index = 0

    init(window: Int) {
        self.window = max(window, 1)
    }

    mutating func push(_ value: Float) -> Float {
        let i = index
        index += 1
        while let last = deque.last, last.value <= value {
            deque.removeLast()
        }
        deque.append((i, value))
        let oldest = i - window + 1
        while let first = deque.first, first.index < oldest {
            deque.removeFirst()
        }
        return deque.first?.value ?? value
    }
}
