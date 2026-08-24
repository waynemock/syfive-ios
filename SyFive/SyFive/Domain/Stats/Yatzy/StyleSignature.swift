import Foundation

enum SectionLean: String, Sendable {
    case upperFirst   // > 55% of first-7 fills are upper section
    case lowerFirst   // < 43% of first-7 fills are upper section
    case balanced
}

enum BonusApproach: String, Sendable {
    case lockEarly  // upper categories average position ≤ 5.5 (front half)
    case backfill   // upper categories average position 5.5–7.5
    case neglect    // upper categories average position > 7.5 (late or skipped)
}

struct StyleSignature: Sendable {
    var sectionOrder:      SectionLean
    var bonusApproach:     BonusApproach
    var averageYatzyTurn:  Double?         // 1-indexed; nil if rarely filled non-zero
    var typicalOpening:    YatzyCategory?  // modal first category filled
}

func styleSignature(playerID: UUID, matches: [Match]) -> StyleSignature? {
    let completed = matches.filter { $0.status == .completed }

    struct FillData {
        var order:      [YatzyCategory]   // 13 categories in fill order
        var yatzyIndex: Int?              // 0-indexed position of non-zero Yatzy
    }

    var dataPoints: [FillData] = []

    for match in completed {
        guard let p = match.participants.first(where: { $0.playerID == playerID }) else { continue }

        let sorted: [YatzyCategory] = p.scoreEntries
            .compactMap { entry -> (YatzyCategory, Date)? in
                guard let cat = YatzyCategory(rawValue: entry.slotKey),
                      let at  = entry.recordedAt else { return nil }
                return (cat, at)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        guard sorted.count == 13 else { continue }

        var yatzyIdx: Int? = nil
        if let idx = sorted.firstIndex(of: .yatzy) {
            let yatzyValue = p.scoreEntries
                .first { $0.slotKey == YatzyCategory.yatzy.slotKey }?.value
            if let v = yatzyValue, v != Decimal(0) {
                yatzyIdx = idx
            }
        }

        dataPoints.append(FillData(order: sorted, yatzyIndex: yatzyIdx))
    }

    guard !dataPoints.isEmpty else { return nil }

    // SectionLean: fraction of upper-section fills in the first 7 turns.
    let avgUpperRatio = dataPoints.map { data -> Double in
        Double(data.order.prefix(7).filter(\.isUpperSection).count) / 7.0
    }.reduce(0, +) / Double(dataPoints.count)

    let sectionOrder: SectionLean = avgUpperRatio > 0.55 ? .upperFirst
                                  : avgUpperRatio < 0.43 ? .lowerFirst
                                  : .balanced

    // BonusApproach: average 0-indexed position of upper-section fills.
    let upperPositions = dataPoints.flatMap { data in
        data.order.enumerated().filter { $0.element.isUpperSection }.map { Double($0.offset) }
    }
    let avgUpperPos = upperPositions.isEmpty ? 6.0
        : upperPositions.reduce(0, +) / Double(upperPositions.count)

    let bonusApproach: BonusApproach = avgUpperPos <= 5.5 ? .lockEarly
                                     : avgUpperPos > 7.5  ? .neglect
                                     : .backfill

    // Average Yatzy turn (1-indexed) across non-zero fills.
    let yatzyTurns = dataPoints.compactMap { $0.yatzyIndex.map { Double($0 + 1) } }
    let averageYatzyTurn: Double? = yatzyTurns.isEmpty ? nil
        : yatzyTurns.reduce(0, +) / Double(yatzyTurns.count)

    // Typical opening: modal first category.
    let openings = dataPoints.compactMap { $0.order.first }
    let typicalOpening = openings.isEmpty ? nil : modalCategory(in: openings)

    return StyleSignature(
        sectionOrder:     sectionOrder,
        bonusApproach:    bonusApproach,
        averageYatzyTurn: averageYatzyTurn,
        typicalOpening:   typicalOpening
    )
}

private func modalCategory(in categories: [YatzyCategory]) -> YatzyCategory? {
    categories
        .reduce(into: [YatzyCategory: Int]()) { $0[$1, default: 0] += 1 }
        .max(by: { $0.value < $1.value })?.key
}
