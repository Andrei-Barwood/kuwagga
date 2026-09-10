import Foundation

struct FrequencySkeleton: Equatable, Sendable {
    var hpfHz: Float
    var bandsHz: [Float]
    var fangHz: Float
}

enum FrequencyTable {
    static func skeleton(genre: Genre, character: CharacterID) -> FrequencySkeleton {
        switch genre {
        case .breakcore:
            return FrequencySkeleton(
                hpfHz: 32,
                bandsHz: [85, 210, 3250, 6800, 11_000],
                fangHz: 3500
            )
        case .dubstep:
            return FrequencySkeleton(
                hpfHz: 25,
                bandsHz: [48, 120, 800, 2500, 8000],
                fangHz: 2400
            )
        case .vaporwave:
            return FrequencySkeleton(
                hpfHz: 30,
                bandsHz: [80, 400, 2000, 6000, 12_000],
                fangHz: 1800
            )
        case .kirtan:
            if character == .shunya {
                return FrequencySkeleton(
                    hpfHz: 50,
                    bandsHz: [200, 800, 3500, 8000, 12_000],
                    fangHz: 3200
                )
            }
            return FrequencySkeleton(
                hpfHz: 35,
                bandsHz: [90, 250, 2800, 6000, 12_000],
                fangHz: 2800
            )
        }
    }
}
