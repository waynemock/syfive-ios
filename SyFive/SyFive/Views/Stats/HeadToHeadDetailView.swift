import SwiftUI

struct HeadToHeadDetailView: View {
    let profilePlayerName: String
    let profileThemeType: Theme.ThemeType
    let opponentName: String
    let opponentThemeType: Theme.ThemeType
    let h2h: HeadToHead

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var profileTheme: Theme { Theme(type: profileThemeType, colorScheme: colorScheme) }
    private var opponentTheme: Theme { Theme(type: opponentThemeType, colorScheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    winsCard
                    scoresCard
                    if showsPairwise { pairwiseCard }
                    if abs(h2h.currentStreakA) >= 1 { streakCard }
                }
                .padding(16)
            }
            .background(profileTheme.backgroundColor)
            .navigationTitle("\(profilePlayerName) vs \(opponentName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(profileTheme.primaryAccent)
        .environment(\.theme, profileTheme)
    }

    // MARK: - Cards

    private var winsCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                winsPillar(name: profilePlayerName, wins: h2h.matchWinsA,
                           isLeader: h2h.matchWinsA > h2h.matchWinsB,
                           accent: profileTheme.primaryAccent)
                Text("–")
                    .font(.title2.weight(.thin))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                winsPillar(name: opponentName, wins: h2h.matchWinsB,
                           isLeader: h2h.matchWinsB > h2h.matchWinsA,
                           accent: opponentTheme.primaryAccent)
            }
            winsMetaText
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(profileTheme.cellBackgroundColor))
    }

    private func winsPillar(name: String, wins: Int, isLeader: Bool, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(wins)")
                .font(.title2.weight(.bold))
                .foregroundStyle(isLeader ? accent : Color.primary.opacity(0.55))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var winsMetaText: Text {
        var parts: [String] = [h2h.sharedMatches == 1 ? "1 game" : "\(h2h.sharedMatches) games"]
        if h2h.sharedTies > 0 {
            parts.append(h2h.sharedTies == 1 ? "1 shared win" : "\(h2h.sharedTies) shared wins")
        }
        if let last = h2h.lastMeeting {
            parts.append("Last: \(last.formatted(date: .abbreviated, time: .omitted))")
        }
        return Text(parts.joined(separator: " · "))
    }

    private var scoresCard: some View {
        detailCard(title: "Average Score") {
            HStack(spacing: 0) {
                scorePillar(name: profilePlayerName, avg: h2h.averageScoreA,
                            isHigher: h2h.averageScoreA > h2h.averageScoreB,
                            accent: profileTheme.primaryAccent)
                Spacer()
                scorePillar(name: opponentName, avg: h2h.averageScoreB,
                            isHigher: h2h.averageScoreB > h2h.averageScoreA,
                            accent: opponentTheme.primaryAccent)
            }
        }
    }

    private func scorePillar(name: String, avg: Decimal, isHigher: Bool, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(avg.displayInt)")
                .font(.title3.weight(.bold))
                .foregroundStyle(isHigher ? accent : Color.primary.opacity(0.7))
            Text("avg pts")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // Pairwise placement is only distinct from the win record when a third player
    // won at least one game — otherwise pairwise == wins and adds no info.
    private var showsPairwise: Bool {
        h2h.matchWinsA + h2h.matchWinsB + h2h.sharedTies < h2h.sharedMatches
    }

    private var pairwiseCard: some View {
        detailCard(title: "Head-to-Head Placement") {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(profilePlayerName) finished ahead in \(h2h.pairwiseAheadA) of \(h2h.sharedMatches) shared games.")
                    .font(.subheadline)
                if h2h.pairwiseTies > 0 {
                    Text("Tied placement \(h2h.pairwiseTies) time\(h2h.pairwiseTies == 1 ? "" : "s").")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var streakCard: some View {
        detailCard(title: "Current Streak") {
            Text(streakText).font(.subheadline)
        }
    }

    private var streakText: String {
        let s = h2h.currentStreakA
        if s >= 2  { return "\(profilePlayerName) is on a \(s)-game winning streak." }
        if s == 1  { return "\(profilePlayerName) won the last matchup." }
        if s <= -2 { return "\(opponentName) is on a \(abs(s))-game winning streak." }
        return "\(opponentName) won the last matchup."
    }

    @ViewBuilder
    private func detailCard<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.horizontal, 2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(profileTheme.cellBackgroundColor))
    }
}

// MARK: - Decimal display

private extension Decimal {
    var displayInt: Int { Int((self as NSDecimalNumber).doubleValue) }
}

#Preview {
    let h2h = HeadToHead(
        playerA: UUID(), playerB: UUID(),
        sharedMatches: 7, matchWinsA: 4, matchWinsB: 2, sharedTies: 0,
        pairwiseAheadA: 5, pairwiseAheadB: 2, pairwiseTies: 0,
        averageScoreA: 247, averageScoreB: 231,
        lastMeeting: Date(), currentStreakA: 2
    )
    return HeadToHeadDetailView(
        profilePlayerName: "Wayne",
        profileThemeType: .midnight,
        opponentName: "Robin",
        opponentThemeType: .forest,
        h2h: h2h
    )
}
