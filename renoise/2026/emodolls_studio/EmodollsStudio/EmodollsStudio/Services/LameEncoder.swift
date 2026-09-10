import Darwin
import Foundation

enum LameEncoder {
    static func encodeCBR320(
        left: [Float],
        right: [Float],
        sampleRate: Int32 = Int32(DSPSeal.sampleRate),
        metadata: MetadataDraft,
        to url: URL
    ) throws {
        precondition(left.count == right.count)
        let lame = try LameLibrary.load()
        let flags = lame.initFn()
        guard let flags else { throw EngineError.encodeFailed }
        defer { _ = lame.closeFn(flags) }

        _ = lame.setRate(flags, sampleRate)
        _ = lame.setChannels(flags, 2)
        _ = lame.setBrate(flags, 320)
        _ = lame.setMode(flags, 1) // joint stereo
        _ = lame.setQuality(flags, 0)
        _ = lame.setVBR(flags, 0) // cbr
        guard lame.initParams(flags) == 0 else { throw EngineError.encodeFailed }

        let frames = left.count
        let mp3Cap = Int(Double(frames) * 1.25) + 7200
        var mp3 = [UInt8](repeating: 0, count: mp3Cap)
        var written = 0

        let chunk = 1152
        var offset = 0
        while offset < frames {
            let n = min(chunk, frames - offset)
            let encoded: Int32 = left.withUnsafeBufferPointer { lBuf in
                right.withUnsafeBufferPointer { rBuf in
                    mp3.withUnsafeMutableBufferPointer { outBuf in
                        lame.encodeFloat(
                            flags,
                            lBuf.baseAddress?.advanced(by: offset),
                            rBuf.baseAddress?.advanced(by: offset),
                            Int32(n),
                            outBuf.baseAddress?.advanced(by: written),
                            Int32(mp3Cap - written)
                        )
                    }
                }
            }
            guard encoded >= 0 else { throw EngineError.encodeFailed }
            written += Int(encoded)
            offset += n
        }

        let flushed: Int32 = mp3.withUnsafeMutableBufferPointer { outBuf in
            lame.flushFn(flags, outBuf.baseAddress?.advanced(by: written), Int32(mp3Cap - written))
        }
        guard flushed >= 0 else { throw EngineError.encodeFailed }
        written += Int(flushed)

        var file = ID3v23.tag(from: metadata)
        file.append(contentsOf: mp3.prefix(written))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try file.write(to: url, options: .atomic)
    }
}

private final class LameLibrary {
    private static var cached: LameLibrary?

    static func load() throws -> LameLibrary {
        if let cached { return cached }
        let loaded = try LameLibrary()
        cached = loaded
        return loaded
    }

    let initFn: @convention(c) () -> OpaquePointer?
    let setRate: @convention(c) (OpaquePointer?, Int32) -> Int32
    let setChannels: @convention(c) (OpaquePointer?, Int32) -> Int32
    let setBrate: @convention(c) (OpaquePointer?, Int32) -> Int32
    let setMode: @convention(c) (OpaquePointer?, Int32) -> Int32
    let setQuality: @convention(c) (OpaquePointer?, Int32) -> Int32
    let setVBR: @convention(c) (OpaquePointer?, Int32) -> Int32
    let initParams: @convention(c) (OpaquePointer?) -> Int32
    let encodeFloat: @convention(c) (
        OpaquePointer?,
        UnsafePointer<Float>?,
        UnsafePointer<Float>?,
        Int32,
        UnsafeMutablePointer<UInt8>?,
        Int32
    ) -> Int32
    let flushFn: @convention(c) (OpaquePointer?, UnsafeMutablePointer<UInt8>?, Int32) -> Int32
    let closeFn: @convention(c) (OpaquePointer?) -> Int32

    private let handle: UnsafeMutableRawPointer

    init() throws {
        let url = try Self.dylibURL()
        guard let handle = dlopen(url.path, RTLD_NOW) else {
            throw EngineError.lameMissing
        }
        self.handle = handle
        initFn = try Self.symbol(handle, "lame_init")
        setRate = try Self.symbol(handle, "lame_set_in_samplerate")
        setChannels = try Self.symbol(handle, "lame_set_num_channels")
        setBrate = try Self.symbol(handle, "lame_set_brate")
        setMode = try Self.symbol(handle, "lame_set_mode")
        setQuality = try Self.symbol(handle, "lame_set_quality")
        setVBR = try Self.symbol(handle, "lame_set_VBR")
        initParams = try Self.symbol(handle, "lame_init_params")
        encodeFloat = try Self.symbol(handle, "lame_encode_buffer_ieee_float")
        flushFn = try Self.symbol(handle, "lame_encode_flush")
        closeFn = try Self.symbol(handle, "lame_close")
    }

    private static func dylibURL() throws -> URL {
        let bundle = Bundle.main
        let name = "libmp3lame.0"
        let ext = "dylib"
        if let url = bundle.url(forResource: name, withExtension: ext) {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Vendor") {
            return url
        }
        if let root = bundle.resourceURL {
            let direct = root.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: direct.path) {
                return direct
            }
            let vendor = root.appendingPathComponent("Vendor/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: vendor.path) {
                return vendor
            }
        }
        throw EngineError.lameMissing
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) throws -> T {
        guard let raw = dlsym(handle, name) else { throw EngineError.lameMissing }
        return unsafeBitCast(raw, to: T.self)
    }
}
