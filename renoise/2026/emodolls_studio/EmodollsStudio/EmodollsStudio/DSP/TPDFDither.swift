import Foundation

enum TPDFDither {
    static let lsb: Float = 1.0 / 32768.0

    static func apply(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)
        for i in input.indices {
            let triangle = Float.random(in: 0..<1) - Float.random(in: 0..<1)
            let dithered = input[i] + triangle * lsb
            let clipped = max(-1, min(1, dithered))
            output[i] = round(clipped * 32767) / 32767
        }
        return output
    }
}
