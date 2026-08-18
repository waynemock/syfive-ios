import Foundation

struct Proficiency: Sendable {
    var strongest: [YatzyCategory]      // top-3 by efficiency (averageValue / maxPossible)
    var coldest:   [YatzyCategory]      // bottom-3 by efficiency
    // Upper-section only: player's average vs the bonus-pace value (face × 3).
    var upperPaceNotes: [YatzyCategory: (average: Decimal, pace: Decimal)]
}

func proficiency(playerID: UUID, matches: [Match]) -> Proficiency? {
    let completed = matches.filter { $0.status == .completed }
    guard !completed.isEmpty else { return nil }

    struct Entry { var category: YatzyCategory; var efficiency: Decimal; var average: Decimal }
    var entries: [Entry] = []
    var upperPaceNotes: [YatzyCategory: (average: Decimal, pace: Decimal)] = [:]

    for cat in YatzyCategory.allCases {
        guard let stats = categoryStats(category: cat, playerID: playerID, matches: completed),
              stats.timesFilled > 0 else { continue }
        let maxVal = maxCategoryValue(cat)
        let eff = maxVal > 0 ? stats.averageValue / maxVal : .zero
        entries.append(Entry(category: cat, efficiency: eff, average: stats.averageValue))
        if cat.isUpperSection {
            let pace = Decimal(upperFaceValue(cat) * 3)
            upperPaceNotes[cat] = (average: stats.averageValue, pace: pace)
        }
    }
    guard !entries.isEmpty else { return nil }

    let sorted  = entries.sorted { $0.efficiency > $1.efficiency }
    let cap     = min(3, sorted.count)
    return Proficiency(
        strongest:      Array(sorted.prefix(cap).map(\.category)),
        coldest:        Array(sorted.suffix(cap).reversed().map(\.category)),
        upperPaceNotes: upperPaceNotes
    )
}

private func maxCategoryValue(_ c: YatzyCategory) -> Decimal {
    switch c {
    case .ones:          return 5
    case .twos:          return 10
    case .threes:        return 15
    case .fours:         return 20
    case .fives:         return 25
    case .sixes:         return 30
    case .threeOfAKind:  return 30
    case .fourOfAKind:   return 30
    case .fullHouse:     return 25
    case .smallStraight: return 30
    case .largeStraight: return 40
    case .yatzy:       return 50
    case .chance:        return 30
    }
}

private func upperFaceValue(_ c: YatzyCategory) -> Int {
    switch c {
    case .ones:   return 1
    case .twos:   return 2
    case .threes: return 3
    case .fours:  return 4
    case .fives:  return 5
    case .sixes:  return 6
    default:      return 0
    }
}
