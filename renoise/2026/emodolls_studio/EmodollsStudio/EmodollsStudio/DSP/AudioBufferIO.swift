import AVFoundation
import Foundation

enum AudioBufferIO {
    struct Decoded {
        var interleaved: [Float]
        var channels: Int
        var sampleRate: Double
    }

    static func read(_ url: URL) throws -> Decoded {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(file.length)
        guard frames > 0 else { throw EngineError.empty }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw EngineError.cannotRead
        }
        try file.read(into: buffer)
        let channels = Int(format.channelCount)
        let n = Int(buffer.frameLength)
        var interleaved = [Float](repeating: 0, count: n * channels)
        if let floats = buffer.floatChannelData {
            for c in 0..<channels {
                for i in 0..<n {
                    interleaved[i * channels + c] = floats[c][i]
                }
            }
        } else if let ints = buffer.int16ChannelData {
            let scale: Float = 1.0 / 32768.0
            for c in 0..<channels {
                for i in 0..<n {
                    interleaved[i * channels + c] = Float(ints[c][i]) * scale
                }
            }
        } else {
            throw EngineError.cannotRead
        }
        return Decoded(interleaved: interleaved, channels: channels, sampleRate: format.sampleRate)
    }

    static func writePCM16(
        _ interleaved: [Float],
        channels: Int,
        sampleRate: Double,
        to url: URL
    ) throws {
        let frames = interleaved.count / max(channels, 1)
        var samples = [Int16](repeating: 0, count: interleaved.count)
        for i in interleaved.indices {
            let x = max(-1 as Float, min(1, interleaved[i]))
            samples[i] = Int16(clamping: Int(round(x * 32767)))
        }

        let byteRate = UInt32(sampleRate) * UInt32(channels) * 2
        let blockAlign = UInt16(channels * 2)
        let dataBytes = UInt32(samples.count * 2)
        var riff = Data()
        func ascii(_ s: String) { riff.append(contentsOf: s.utf8) }
        func u16(_ v: UInt16) {
            var le = v.littleEndian
            riff.append(Data(bytes: &le, count: 2))
        }
        func u32(_ v: UInt32) {
            var le = v.littleEndian
            riff.append(Data(bytes: &le, count: 4))
        }

        ascii("RIFF")
        u32(36 + dataBytes)
        ascii("WAVE")
        ascii("fmt ")
        u32(16)
        u16(1)
        u16(UInt16(channels))
        u32(UInt32(sampleRate))
        u32(byteRate)
        u16(blockAlign)
        u16(16)
        ascii("data")
        u32(dataBytes)
        samples.withUnsafeBytes { riff.append(contentsOf: $0) }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try riff.write(to: url, options: .atomic)
    }

    static func resample(
        _ interleaved: [Float],
        channels: Int,
        from: Double,
        to: Double
    ) throws -> [Float] {
        guard let inFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: from,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        ),
            let outFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: to,
                channels: AVAudioChannelCount(channels),
                interleaved: false
            )
        else {
            throw EngineError.convertFailed
        }

        let inFrames = interleaved.count / channels
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: AVAudioFrameCount(inFrames)) else {
            throw EngineError.convertFailed
        }
        inBuf.frameLength = AVAudioFrameCount(inFrames)
        guard let src = inBuf.floatChannelData else { throw EngineError.convertFailed }
        for i in 0..<inFrames {
            for c in 0..<channels {
                src[c][i] = interleaved[i * channels + c]
            }
        }

        let ratio = to / from
        let outFrames = Int((Double(inFrames) * ratio).rounded(.up)) + 16
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: AVAudioFrameCount(outFrames)) else {
            throw EngineError.convertFailed
        }

        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw EngineError.convertFailed
        }
        var provided = false
        let status = converter.convert(to: outBuf, error: nil) { _, outStatus in
            if provided {
                outStatus.pointee = .endOfStream
                return nil
            }
            provided = true
            outStatus.pointee = .haveData
            return inBuf
        }
        if status == .error { throw EngineError.convertFailed }

        let n = Int(outBuf.frameLength)
        var out = [Float](repeating: 0, count: n * channels)
        guard let dst = outBuf.floatChannelData else { throw EngineError.convertFailed }
        for i in 0..<n {
            for c in 0..<channels {
                out[i * channels + c] = dst[c][i]
            }
        }
        return out
    }
}
