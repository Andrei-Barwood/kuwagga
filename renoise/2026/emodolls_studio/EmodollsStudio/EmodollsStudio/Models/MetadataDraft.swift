import Foundation

struct MetadataDraft: Equatable, Hashable, Sendable {
    var title: String
    var artist: String
    var album: String
    var track: String
    var year: String
    var genre: String

    init(
        title: String = "",
        artist: String = "",
        album: String = "",
        track: String = "",
        year: String = "",
        genre: String = ""
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.track = track
        self.year = year
        self.genre = genre
    }

    var isEmpty: Bool {
        [title, artist, album, track, year, genre].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
