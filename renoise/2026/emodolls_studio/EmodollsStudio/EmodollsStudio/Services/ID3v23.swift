import Foundation

enum ID3v23 {
    static func tag(from meta: MetadataDraft) -> Data {
        if meta.isEmpty { return Data() }
        var frames = Data()
        appendText(&frames, id: "TIT2", value: meta.title)
        appendText(&frames, id: "TPE1", value: meta.artist)
        appendText(&frames, id: "TALB", value: meta.album)
        appendText(&frames, id: "TRCK", value: meta.track)
        appendText(&frames, id: "TYER", value: meta.year)
        appendText(&frames, id: "TCON", value: meta.genre)
        guard !frames.isEmpty else { return Data() }

        var tag = Data()
        tag.append(contentsOf: "ID3".utf8)
        tag.append(contentsOf: [3, 0, 0])
        tag.append(synchsafe(UInt32(frames.count)))
        tag.append(frames)
        return tag
    }

    private static func appendText(_ frames: inout Data, id: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let payload = Data([0]) + (trimmed.data(using: .isoLatin1) ?? Data(trimmed.utf8))
        frames.append(contentsOf: id.utf8)
        var size = UInt32(payload.count).bigEndian
        frames.append(Data(bytes: &size, count: 4))
        frames.append(contentsOf: [0, 0])
        frames.append(payload)
    }

    private static func synchsafe(_ value: UInt32) -> Data {
        let b0 = UInt8((value >> 21) & 0x7F)
        let b1 = UInt8((value >> 14) & 0x7F)
        let b2 = UInt8((value >> 7) & 0x7F)
        let b3 = UInt8(value & 0x7F)
        return Data([b0, b1, b2, b3])
    }
}
