import SwiftUI
import SyLibScoring
import SwiftData
import SyLibFeel
import SyLibScoringData

struct OpponentRecord: Identifiable {
    var id: UUID { opponentID }
    let opponentID: UUID
    let opponentName: String
    let opponentInitials: String
    let opponentThemeType: Theme.ThemeType
    let h2h: HeadToHead
}

struct OpponentSummaryRow: View {
    let profilePlayerName: String
    let profileThemeType: Theme.ThemeType
    let record: OpponentRecord

    @Environment(\.theme) private var profileTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsDetail = false

    private var opponentTheme: Theme { Theme(type: record.opponentThemeType, colorScheme: colorScheme) }

    var body: some View {
        Button { showsDetail = true } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showsDetail) {
            HeadToHeadDetailView(
                profilePlayerName: profilePlayerName,
                profileThemeType: profileThemeType,
                opponentName: record.opponentName,
                opponentThemeType: record.opponentThemeType,
                h2h: record.h2h
            )
        }
    }

    private var cardContent: some View {
        HStack(spacing: 10) {
            PlayerInitialsCircle(initials: record.opponentInitials, themeType: record.opponentThemeType)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.opponentName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            winsDisplay
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(profileTheme.cellBackgroundColor)
        )
    }

    private var winsDisplay: some View {
        HStack(spacing: 3) {
            Text("\(record.h2h.matchWinsA)")
                .font(.title3.weight(.bold))
                .foregroundStyle(record.h2h.matchWinsA >= record.h2h.matchWinsB
                    ? profileTheme.primaryAccent : Color.primary.opacity(0.5))
            VStack(spacing: 1) {
                Text("–")
                    .font(.title3.weight(.thin))
                    .foregroundStyle(.tertiary)
                if record.h2h.sharedTies > 0 {
                    Text("\(record.h2h.sharedTies)T")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(record.h2h.matchWinsB)")
                .font(.title3.weight(.bold))
                .foregroundStyle(record.h2h.matchWinsB > record.h2h.matchWinsA
                    ? opponentTheme.primaryAccent : Color.primary.opacity(0.5))
        }
    }

    private var metaLine: String {
        let count = record.h2h.sharedMatches
        var parts = [count == 1 ? "1 game" : "\(count) games"]
        if let last = record.h2h.lastMeeting {
            parts.append(last.formatted(date: .abbreviated, time: .omitted))
        }
        let streak = record.h2h.currentStreakA
        if abs(streak) >= 2 {
            parts.append(streak > 0 ? "↑\(streak) streak" : "↓\(abs(streak)) streak")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let h2h = HeadToHead(
        playerA: UUID(), playerB: UUID(),
        sharedMatches: 5, matchWinsA: 3, matchWinsB: 2, sharedTies: 0,
        pairwiseAheadA: 3, pairwiseAheadB: 2, pairwiseTies: 0,
        averageScoreA: 247, averageScoreB: 231,
        lastMeeting: Date(), currentStreakA: 2
    )
    let record = OpponentRecord(
        opponentID: UUID(), opponentName: "Sherida", opponentInitials: "RM",
        opponentThemeType: .forest, h2h: h2h
    )
    OpponentSummaryRow(profilePlayerName: "Wayne", profileThemeType: .midnight, record: record)
        .padding()
        .environment(\.theme, Theme(type: .midnight, colorScheme: .dark))
        .modelContainer(for: MatchModel.self, inMemory: true)
        .environment(FeelDirector(catalog: .syFive))
}
