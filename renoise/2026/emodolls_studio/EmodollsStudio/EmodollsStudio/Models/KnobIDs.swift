import Foundation

enum KnobID: String, CaseIterable, Identifiable, Hashable, Sendable {
    case heat
    case bloom
    case fang

    var id: String { rawValue }
}

struct KnobIDs: Equatable, Hashable, Sendable {
    let heat: String
    let bloom: String
    let fang: String

    var allLabels: [String] { [heat, bloom, fang] }

    func label(for id: KnobID) -> String {
        switch id {
        case .heat: return heat
        case .bloom: return bloom
        case .fang: return fang
        }
    }
}
