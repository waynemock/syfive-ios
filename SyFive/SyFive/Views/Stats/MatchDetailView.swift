import SwiftUI
import SyLibFeel
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SwiftData

struct MatchDetailView: View {
    let matchModel: MatchModel

    private var match: Match { matchModel.toDomain() }

    private var sortedParticipants: [Participant] {
        match.participants.sorted { $0.rank < $1.rank }
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var scoreController = MatchController()
    @State private var scorecardContainerWidth: CGFloat = 0
    @State private var showsGNLogs = false

    // Scorecard layout — matches ScorecardView constants
    private let scoreColumnWidth: CGFloat = 64
    private let scoreRowHeight: CGFloat = 32
    private let headerRowHeight: CGFloat = 28
    private let scoreSectionSpacing: CGFloat = 14
    private let scoreRowSpacing: CGFloat = 6
    private let cardInset: CGFloat = 16
    private let cardGap: CGFloat = 16
    private let peekAmount: CGFloat = 24

    private var singleCardWidth: CGFloat {
        let width = scorecardContainerWidth > 0 ? scorecardContainerWidth : 300
        let playerCount = match.participants.count
        let usable = max(0, width - cardInset * 2)
        guard playerCount > 1 else { return max(260, usable) }
        let twoCardFit = (usable - cardGap) / 2
        if twoCardFit >= 260 { return twoCardFit }
        return max(260, width - cardInset - cardGap - peekAmount)
    }

    // Keyed by participantID (p.id), which is what MatchProgressionChart uses.
    private var playerNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: match.participants.map { p in
            (p.id, p.displayName)
        })
    }

    private var playerColors: [UUID: Color] {
        Dictionary(uniqueKeysWithValues: match.participants.map { p in
            return (p.id, Theme.accent(forThemeID: p.displayThemeID, colorScheme: colorScheme))
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                finalScoresCard
                if let prog = matchProgression(from: match) {
                    progressionCard(prog)
                }
                scorecardsCard
                if AppConfig.DebugGameNight.showLogs && matchModel.isGameNight
                    && GameNightLogBuffer.shared.hasLog(for: matchModel.id) {
                    Button {
                        showsGNLogs = true
                    } label: {
                        Label("Game Night Logs", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }
            }
            .padding(16)
        }
        .navigationTitle(match.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { scoreController.load(from: matchModel) }
        .sheet(isPresented: $showsGNLogs) {
            GameNightLogSheet(matchID: matchModel.id)
        }
    }


    private var finalScoresCard: some View {
        let winnerColor = sortedParticipants.first.flatMap { playerColors[$0.id] } ?? .primary
        return VStack(alignment: .leading, spacing: 12) {
            Text("Final Scores")
                .font(.headline)
                .foregroundStyle(winnerColor)
            ForEach(sortedParticipants) { participant in
                let color = playerColors[participant.id] ?? .primary
                HStack {
                    Text(rankLabel(participant.rank))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)
                    Text(participant.displayName)
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Spacer()
                    Text(Int(truncating: participant.finalScore as NSDecimalNumber),
                         format: .number)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func progressionCard(_ prog: MatchProgression) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match Progression")
                .font(.headline)
            MatchProgressionChart(progression: prog, playerNames: playerNames, playerColors: playerColors)
                .frame(height: 220)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private var scorecardsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Scorecards")
                .font(.headline)
                .padding(.horizontal, cardInset)
                .padding(.bottom, 10)

            // Width measurement probe — invisible, zero-height
            Color.clear
                .frame(height: 0)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: HistoryScorecardWidthKey.self, value: geo.size.width)
                })

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: cardGap) {
                    ForEach(sortedParticipants) { participant in
                        let cw = singleCardWidth
                        let m = PlayerScoreCardView.metrics(for: cw)
                        PlayerScoreCardView(
                            model: scoreController,
                            playerIndex: participant.seat,
                            scoreColumnWidth: scoreColumnWidth,
                            scoreRowHeight: scoreRowHeight,
                            headerRowHeight: headerRowHeight,
                            scoreSectionSpacing: scoreSectionSpacing,
                            scoreRowSpacing: scoreRowSpacing,
                            horizontalPadding: m.horizontalPadding,
                            sectionGap: m.sectionGap
                        )
                        .frame(width: cw)
                    }
                }
                .padding(.horizontal, cardInset)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .onPreferenceChange(HistoryScorecardWidthKey.self) { width in
            if width > 0 { scorecardContainerWidth = width }
        }
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(rank)th"
        }
    }
}

private struct HistoryScorecardWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let schema = Schema([
        PlayerModel.self, TeamModel.self, GameModel.self,
        MatchModel.self, ParticipantModel.self, AppSettingsModel.self,
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )

    let ctx = container.mainContext
    let now = Date()

    let match = MatchModel()
    match.statusRaw = "completed"
    match.startedAt = now.addingTimeInterval(-7_200)
    match.completedAt = now.addingTimeInterval(-5_400)
    ctx.insert(match)

    func entry(_ category: YatzyCategory, _ value: Int, minutesAgo: Int) -> ScoreEntry {
        ScoreEntry(
            slotKey: category.slotKey, value: Decimal(value),
            metadata: nil, recordedAt: now.addingTimeInterval(Double(-minutesAgo * 60))
        )
    }

    // Wayne — winner, 296 pts (upper bonus achieved: 70 upper + 35 bonus + 191 lower)
    let p1 = ParticipantModel()
    p1.seat = 0; p1.rank = 1; p1.finalScore = 296; p1.bonusPoints = 0
    p1.displayName = "Wayne"; p1.displayInitials = "WM"
    p1.displayThemeID = Theme.ThemeType.midnight.rawValue
    p1.scoreEntries = [
        entry(.ones, 3, minutesAgo: 110),        entry(.twos, 8, minutesAgo: 108),
        entry(.threes, 9, minutesAgo: 106),       entry(.fours, 12, minutesAgo: 104),
        entry(.fives, 20, minutesAgo: 102),       entry(.sixes, 18, minutesAgo: 100),
        entry(.threeOfAKind, 20, minutesAgo: 96), entry(.fourOfAKind, 0, minutesAgo: 92),
        entry(.fullHouse, 25, minutesAgo: 88),    entry(.smallStraight, 30, minutesAgo: 84),
        entry(.largeStraight, 40, minutesAgo: 80), entry(.yatzy, 50, minutesAgo: 76),
        entry(.chance, 26, minutesAgo: 72),
    ]
    p1.match = match
    ctx.insert(p1)

    // Sherida — runner-up, 164 pts (three scratches, no upper bonus)
    let p2 = ParticipantModel()
    p2.seat = 1; p2.rank = 2; p2.finalScore = 164; p2.bonusPoints = 0
    p2.displayName = "Sherida"; p2.displayInitials = "SM"
    p2.displayThemeID = Theme.ThemeType.forest.rawValue
    p2.scoreEntries = [
        entry(.ones, 2, minutesAgo: 109),         entry(.twos, 6, minutesAgo: 107),
        entry(.threes, 6, minutesAgo: 105),        entry(.fours, 8, minutesAgo: 103),
        entry(.fives, 10, minutesAgo: 101),        entry(.sixes, 12, minutesAgo: 99),
        entry(.threeOfAKind, 18, minutesAgo: 95),  entry(.fourOfAKind, 0, minutesAgo: 91),
        entry(.fullHouse, 0, minutesAgo: 87),      entry(.smallStraight, 30, minutesAgo: 83),
        entry(.largeStraight, 0, minutesAgo: 79),  entry(.yatzy, 50, minutesAgo: 75),
        entry(.chance, 22, minutesAgo: 71),
    ]
    p2.match = match
    ctx.insert(p2)

    return NavigationStack {
        MatchDetailView(matchModel: match)
    }
    .modelContainer(container)
    .environment(FeelDirector(catalog: .syFive))
    .preferredColorScheme(.dark)
}
