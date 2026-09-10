import AVFoundation
import AudioToolbox
import Foundation

enum AudioIO {
    static let inputExtensions: Set<String> = [
        "wav", "wave", "aiff", "aif", "flac", "m4a", "mp3", "opus",
    ]

    static func isSupportedAudioFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") || name.hasPrefix("._") { return false }
        return inputExtensions.contains(url.pathExtension.lowercased())
    }

    static func collectAudioFiles(under root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if isSupportedAudioFile(url) {
                files.append(url)
            }
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func outputURL(
        for input: URL,
        inputRoot: URL?,
        outputRoot: URL,
        format: ExportFormat
    ) -> URL {
        let stem = input.deletingPathExtension().lastPathComponent + ExportFormat.filenameSuffix
        let folder: URL
        if let inputRoot {
            let parent = input.deletingLastPathComponent()
            let rel = relativePath(of: parent, to: inputRoot)
            folder = rel.isEmpty ? outputRoot : outputRoot.appendingPathComponent(rel, isDirectory: true)
        } else {
            folder = outputRoot
        }
        return folder.appendingPathComponent(stem).appendingPathExtension(format.pathExtension)
    }

    static func decode(_ url: URL) throws -> AudioBufferIO.Decoded {
        guard isSupportedAudioFile(url) else { throw EngineError.unsupportedFormat }
        let decoded = try AudioBufferIO.read(url)
        if abs(decoded.sampleRate - DSPSeal.sampleRate) < 0.5 {
            return decoded
        }
        let resampled = try AudioBufferIO.resample(
            decoded.interleaved,
            channels: decoded.channels,
            from: decoded.sampleRate,
            to: DSPSeal.sampleRate
        )
        return AudioBufferIO.Decoded(
            interleaved: resampled,
            channels: decoded.channels,
            sampleRate: DSPSeal.sampleRate
        )
    }

    static func encode(
        mono: [Float],
        format: ExportFormat,
        metadata: MetadataDraft,
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        switch format {
        case .wav:
            try writeWAV(mono: TPDFDither.apply(mono), to: url)
        case .m4a:
            try writeM4A(mono: mono, metadata: metadata, to: url)
        case .dittopro:
            try LameEncoder.encodeCBR320(
                left: mono,
                right: mono,
                metadata: metadata,
                to: url
            )
        }
    }

    static func writeWAV(mono: [Float], to url: URL) throws {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: DSPSeal.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var file: ExtAudioFileRef?
        let status = ExtAudioFileCreateWithURL(
            url as CFURL,
            kAudioFileWAVEType,
            &asbd,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &file
        )
        guard status == noErr, let file else { throw EngineError.cannotWrite }
        defer { ExtAudioFileDispose(file) }

        var client = AudioStreamBasicDescription(
            mSampleRate: DSPSeal.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let set = ExtAudioFileSetProperty(
            file,
            kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
            &client
        )
        guard set == noErr else { throw EngineError.cannotWrite }

        let count = mono.count
        let data = UnsafeMutablePointer<Float>.allocate(capacity: count)
        data.initialize(from: mono, count: count)
        defer { data.deallocate() }
        var buffer = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: UInt32(count * MemoryLayout<Float>.size),
            mData: data
        )
        var list = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        let write = ExtAudioFileWrite(file, UInt32(count), &list)
        if write != noErr { throw EngineError.cannotWrite }
    }

    private static func writeM4A(mono: [Float], metadata: MetadataDraft, to url: URL) throws {
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent("tmp-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: temp) }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: DSPSeal.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 256_000,
        ]
        do {
            let file = try AVAudioFile(
                forWriting: temp,
                settings: settings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: DSPSeal.sampleRate,
                channels: 1,
                interleaved: false
            ),
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(mono.count))
            else {
                throw EngineError.encodeFailed
            }
            buffer.frameLength = AVAudioFrameCount(mono.count)
            if let dest = buffer.floatChannelData {
                for i in mono.indices { dest[0][i] = mono[i] }
            }
            try file.write(from: buffer)
        }

        do {
            try optimizeM4A(from: temp, to: url, metadata: metadata)
        } catch {
            try? FileManager.default.removeItem(at: url)
            try FileManager.default.copyItem(at: temp, to: url)
        }
    }

    private static func optimizeM4A(from: URL, to: URL, metadata: MetadataDraft) throws {
        try? FileManager.default.removeItem(at: to)
        let asset = AVURLAsset(url: from)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw EngineError.encodeFailed
        }
        export.outputURL = to
        export.outputFileType = .m4a
        export.shouldOptimizeForNetworkUse = true
        if !metadata.isEmpty {
            export.metadata = avMetadata(metadata)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        export.exportAsynchronously {
            if export.status != .completed {
                exportError = export.error ?? EngineError.encodeFailed
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let exportError { throw exportError }
    }

    private static func avMetadata(_ meta: MetadataDraft) -> [AVMetadataItem] {
        func item(_ key: AVMetadataKey, _ value: String) -> AVMetadataItem? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = key as NSString
            item.value = trimmed as NSString
            return item
        }
        var items: [AVMetadataItem] = []
        if let v = item(.iTunesMetadataKeySongName, meta.title) { items.append(v) }
        if let v = item(.iTunesMetadataKeyArtist, meta.artist) { items.append(v) }
        if let v = item(.iTunesMetadataKeyAlbum, meta.album) { items.append(v) }
        if let v = item(.iTunesMetadataKeyTrackNumber, meta.track) { items.append(v) }
        if !meta.year.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let item = AVMutableMetadataItem()
            item.keySpace = .iTunes
            item.key = AVMetadataKey.iTunesMetadataKeyReleaseDate as NSString
            item.value = meta.year as NSString
            items.append(item)
        }
        if let v = item(.iTunesMetadataKeyUserGenre, meta.genre) { items.append(v) }
        return items
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let urlPath = url.standardizedFileURL.path
        if urlPath == rootPath { return "" }
        guard urlPath.hasPrefix(rootPath + "/") else { return "" }
        return String(urlPath.dropFirst(rootPath.count + 1))
    }
}
