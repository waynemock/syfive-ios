import Foundation

// Chart-ready output types emitted by the stats layer.
// The domain emits bare Foundation value types; the App layer maps them
// to Swift Charts marks and applies theme. This file must never import
// Charts, SwiftUI, or any framework beyond Foundation.

struct SeriesPoint: Sendable {
    var x: Decimal
    var y: Decimal
    var label: String?
}

struct DatedPoint: Sendable {
    var at: Date
    var value: Decimal
}

// A count per bin — e.g. rank→count for placement distribution,
// score-bucket→count for score histograms.
struct Distribution: Sendable {
    var bins: [Int: Int]

    var isEmpty: Bool { bins.isEmpty }
    var total: Int { bins.values.reduce(0, +) }
}
