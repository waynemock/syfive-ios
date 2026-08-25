import Foundation
import SyLibCore

// App-layer, SyFive-specific. Does not enter the Domain layer or SyLib (§2.13, §6.12).
// All values compute-on-read from completed matches. No stored aggregates (§4.1, §6.5).
struct HouseRecords {

    private static let logger = AppLogger(category: "HouseRecords")

    // MARK: - Public types

    struct Holder: Identifiable {
        var id: String { "\(displayName)|\(displayThemeID)|\(heldSince.timeIntervalSince1970)" }
        let displayName: String
        let displayInitials: String
        let displayThemeID: String
        let playerID: UUID?
        let heldSince: Date
        var sampleCount: Int? = nil  // non-nil for Best Average only
    }

    enum TitleState {
        case claimed(holders: [Holder], displayValue: String)
        case unclaimed                 // metric exists but nobody has a qualifying value
        case unclaimedGated            // Best Average: nobody has reached 10 completed matches
    }

    struct Title: Identifiable {
        let id: String
        let name: String
        let category: Category
        let state: TitleState

        enum Category { case event, standing }
    }

    // MARK: - Entry point

    /// Returns all eight titles, computed from completed matches only.
    /// Matches need not be pre-filtered or sorted; this function handles both.
    static func compute(from matches: [Match]) -> [Title] {
        let sorted = matches
            .filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        let pvp = sorted.filter { $0.participants.count > 1 }

        return [
            bestGame(from: sorted),
            mostYatzysInGame(from: sorted),
            bestUpperSection(from: sorted),
            bestAverage(from: pvp),
            mostWins(from: pvp),
            mostGamesPlayed(from: pvp),
            mostYatzys(from: pvp),
            mostUpperBonuses(from: pvp),
        ]
    }

    // MARK: - Event records

    private static func bestGame(from sorted: [Match]) -> Title {
        eventRecord(
            id: "best_game", name: "Best Game",
            from: sorted,
            value: { $0.finalScore },
            displayValue: { formatScore($0) }
        )
    }

    private static func mostYatzysInGame(from sorted: [Match]) -> Title {
        var bestCount: Int? = nil
        var holderSet: [ParticipantIdentity: Holder] = [:]

        for match in sorted {
            guard let date = match.completedAt else { continue }

            for p in match.participants {
                let count = yatzyCount(for: p)
                guard count > 0 else { continue }
                let identity = participantIdentity(for: p)
                if let best = bestCount {
                    if count > best {
                        bestCount = count
                        holderSet = [identity: makeHolder(from: p, date: date)]
                    } else if count == best && holderSet[identity] == nil {
                        holderSet[identity] = makeHolder(from: p, date: date)
                    }
                } else {
                    bestCount = count
                    holderSet = [identity: makeHolder(from: p, date: date)]
                }
            }
        }

        let holders = Array(holderSet.values)
        logIdentityCollisions(holders, title: "Most Yatzys in a Single Game")
        return Title(
            id: "most_yatzys_game", name: "Most Yatzys in a Single Game", category: .event,
            state: bestCount.map { .claimed(holders: holders, displayValue: "\($0)") } ?? .unclaimed
        )
    }

    private static func bestUpperSection(from sorted: [Match]) -> Title {
        eventRecord(
            id: "best_upper", name: "Best Upper Section",
            from: sorted,
            value: { upperSubtotal(for: $0) },
            displayValue: { formatScore($0) }
        )
    }

    /// Generic event-record walk: highest value wins; ties accumulate with the current date.
    /// An identity already in the holder set keeps its original date (dedup across matches).
    private static func eventRecord(
        id: String,
        name: String,
        from sorted: [Match],
        value: (Participant) -> Decimal,
        displayValue: (Decimal) -> String
    ) -> Title {
        var bestValue: Decimal? = nil
        var holderSet: [ParticipantIdentity: Holder] = [:]

        for match in sorted {
            guard let date = match.completedAt else { continue }
            for p in match.participants {
                let v = value(p)
                let identity = participantIdentity(for: p)
                if let best = bestValue {
                    if v > best {
                        bestValue = v
                        holderSet = [identity: makeHolder(from: p, date: date)]
                    } else if v == best && holderSet[identity] == nil {
                        holderSet[identity] = makeHolder(from: p, date: date)
                    }
                } else {
                    bestValue = v
                    holderSet = [identity: makeHolder(from: p, date: date)]
                }
            }
        }

        let holders = Array(holderSet.values)
        logIdentityCollisions(holders, title: name)
        return Title(
            id: id, name: name, category: .event,
            state: bestValue.map { .claimed(holders: holders, displayValue: displayValue($0)) } ?? .unclaimed
        )
    }

    // MARK: - Standing records

    /// Mean finalScore, gate N ≥ 10 (§2.7). Tenure walk per §4.3.
    private static func bestAverage(from sorted: [Match]) -> Title {
        struct Accum { var sum: Decimal = 0; var count: Int = 0; var snap: ParticipantSnap }

        var accum: [ParticipantIdentity: Accum] = [:]
        var holderSet: [ParticipantIdentity: Date] = [:]
        var bestAvg: Decimal? = nil

        for match in sorted {
            guard let date = match.completedAt else { continue }

            for p in match.participants {
                let pid = participantIdentity(for: p)
                var a = accum[pid] ?? Accum(snap: ParticipantSnap(from: p))
                a.sum += p.finalScore
                a.count += 1
                a.snap = ParticipantSnap(from: p)
                accum[pid] = a
            }

            // Only participants with ≥ 10 games are eligible (§2.7).
            let eligible = accum.filter { $0.value.count >= 10 }
            guard !eligible.isEmpty else { continue }

            let currentBest = eligible.values.map { $0.sum / Decimal($0.count) }.max()!
            let currentIDs = Set(eligible.filter { $0.value.sum / Decimal($0.value.count) == currentBest }.map { $0.key })
            let previousIDs = Set(holderSet.keys)

            // Tenure walk: incumbents keep date, newcomers (including retakes) get current date.
            var newHolderSet: [ParticipantIdentity: Date] = [:]
            for pid in currentIDs {
                newHolderSet[pid] = previousIDs.contains(pid) ? holderSet[pid]! : date
            }

            bestAvg = currentBest
            holderSet = newHolderSet
        }

        let hasAnyEligible = accum.values.contains { $0.count >= 10 }
        guard !holderSet.isEmpty else {
            return Title(id: "best_average", name: "Best Average", category: .standing,
                         state: hasAnyEligible ? .unclaimed : .unclaimedGated)
        }

        var holders: [Holder] = []
        for (identity, date) in holderSet {
            guard let a = accum[identity] else { continue }
            var h = makeHolder(from: a.snap, date: date, identity: identity)
            h.sampleCount = a.count
            holders.append(h)
        }

        logIdentityCollisions(holders, title: "Best Average")
        return Title(
            id: "best_average", name: "Best Average", category: .standing,
            state: .claimed(holders: holders, displayValue: bestAvg.map { formatScore($0) } ?? "—")
        )
    }

    /// Count of rank == 1. Caller supplies PvP-only matches (§2.8).
    private static func mostWins(from sorted: [Match]) -> Title {
        tenureWalk(id: "most_wins", name: "Most Wins", from: sorted) { p, _ in p.rank == 1 ? 1 : 0 }
    }

    private static func mostGamesPlayed(from sorted: [Match]) -> Title {
        tenureWalk(id: "most_games", name: "Most Games Played", from: sorted) { _, _ in 1 }
    }

    private static func mostYatzys(from sorted: [Match]) -> Title {
        tenureWalk(id: "most_yatzys", name: "Most Yatzys", from: sorted) { p, _ in yatzyCount(for: p) }
    }

    private static func mostUpperBonuses(from sorted: [Match]) -> Title {
        tenureWalk(id: "most_upper_bonuses", name: "Most Upper Bonuses", from: sorted) { p, _ in
            upperSubtotal(for: p) >= 63 ? 1 : 0
        }
    }

    /// Generic tenure walk for additive integer metrics (§4.3).
    /// Incumbents keep their date; newcomers (or retakes after dropping out) get the current date.
    private static func tenureWalk(
        id: String,
        name: String,
        from sorted: [Match],
        delta: (Participant, Match) -> Int
    ) -> Title {
        struct Accum { var total: Int = 0; var snap: ParticipantSnap }

        var accum: [ParticipantIdentity: Accum] = [:]
        var holderSet: [ParticipantIdentity: Date] = [:]
        var bestTotal: Int = 0

        for match in sorted {
            guard let date = match.completedAt else { continue }

            for p in match.participants {
                let pid = participantIdentity(for: p)
                var a = accum[pid] ?? Accum(snap: ParticipantSnap(from: p))
                a.total += delta(p, match)
                a.snap = ParticipantSnap(from: p)
                accum[pid] = a
            }

            guard let currentBest = accum.values.map({ $0.total }).max(), currentBest > 0 else { continue }

            let currentIDs = Set(accum.filter { $0.value.total == currentBest }.map { $0.key })
            let previousIDs = Set(holderSet.keys)

            var newHolderSet: [ParticipantIdentity: Date] = [:]
            for pid in currentIDs {
                newHolderSet[pid] = previousIDs.contains(pid) ? holderSet[pid]! : date
            }

            bestTotal = currentBest
            holderSet = newHolderSet
        }

        guard !holderSet.isEmpty else {
            return Title(id: id, name: name, category: .standing, state: .unclaimed)
        }

        let holders = holderSet.compactMap { (identity, date) -> Holder? in
            accum[identity].map { makeHolder(from: $0.snap, date: date, identity: identity) }
        }

        logIdentityCollisions(holders, title: name)
        return Title(
            id: id, name: name, category: .standing,
            state: .claimed(holders: holders, displayValue: "\(bestTotal)")
        )
    }

    // MARK: - Identity & helpers

    private enum ParticipantIdentity: Hashable {
        case player(UUID)
        case team(UUID)
        case anonymous(String)
    }

    private struct ParticipantSnap {
        let displayName: String
        let displayInitials: String
        let displayThemeID: String

        init(from p: Participant) {
            displayName = p.displayName
            displayInitials = p.displayInitials
            displayThemeID = p.displayThemeID
        }
    }

    /// Logs any holders that share a displayName but have different playerIDs.
    /// Identity collisions (e.g. Game Night UUID ≠ roster UUID) surface as debug logs.
    private static func logIdentityCollisions(_ holders: [Holder], title: String) {
        var nameMap: [String: [UUID?]] = [:]
        for h in holders { nameMap[h.displayName, default: []].append(h.playerID) }
        for (name, ids) in nameMap where ids.count > 1 {
            let idStrings = ids.map { $0.map { $0.uuidString } ?? "nil" }.joined(separator: ", ")
            logger.debug(HouseRecords.self, "'\(title)': '\(name)' appears under \(ids.count) identities — playerIDs: \(idStrings)")
        }
    }

    private static func participantIdentity(for p: Participant) -> ParticipantIdentity {
        if let pid = p.playerID { return .player(pid) }
        if let tid = p.teamID   { return .team(tid) }
        return .anonymous(p.displayName)
    }

    private static func makeHolder(from p: Participant, date: Date) -> Holder {
        Holder(displayName: p.displayName, displayInitials: p.displayInitials,
               displayThemeID: p.displayThemeID, playerID: p.playerID, heldSince: date)
    }

    private static func makeHolder(from snap: ParticipantSnap, date: Date, identity: ParticipantIdentity) -> Holder {
        let playerID: UUID? = { if case .player(let id) = identity { return id } else { return nil } }()
        return Holder(displayName: snap.displayName, displayInitials: snap.displayInitials,
                      displayThemeID: snap.displayThemeID, playerID: playerID, heldSince: date)
    }

    /// Yatzy count per §4.2: base (scored 50) plus bonus rolls.
    /// Falls back to inferring yatzyBonus from the finalScore gap for any records
    /// not yet repaired by LegacyYahtzeeRepair.
    private static func yatzyCount(for p: Participant) -> Int {
        let entry = p.scoreEntries.first(where: { $0.slotKey == "yatzy" })
        let base = entry?.value == 50 ? 1 : 0

        let effectiveBonus: Int
        if p.bonusPoints > 0 {
            effectiveBonus = p.bonusPoints
        } else {
            let cardSum = p.scoreEntries.compactMap { $0.value }.reduce(Decimal(0), +)
            let upperSum = p.scoreEntries
                .filter { YatzyCategory(rawValue: $0.slotKey)?.isUpperSection == true }
                .compactMap { $0.value }
                .reduce(Decimal(0), +)
            let upperBonusPts: Decimal = upperSum >= 63 ? 35 : 0
            let gap = NSDecimalNumber(decimal: p.finalScore - cardSum - upperBonusPts).intValue
            effectiveBonus = (gap > 0 && gap % 100 == 0) ? gap : 0
        }

        return base + effectiveBonus / 100
    }

    /// Sum of Ones–Sixes, excluding the +35 bonus (which is not a ScoreEntry).
    private static func upperSubtotal(for p: Participant) -> Decimal {
        p.scoreEntries
            .filter { YatzyCategory(rawValue: $0.slotKey)?.isUpperSection == true }
            .compactMap { $0.value }
            .reduce(Decimal(0), +)
    }

    private static func formatScore(_ value: Decimal) -> String {
        "\(Int((value as NSDecimalNumber).doubleValue))"
    }
}
