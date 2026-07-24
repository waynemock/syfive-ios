import SwiftUI
import SwiftData

struct UnfinishedMatchDetailView: View {
    let matchModel: MatchModel
    var onResume: (MatchModel) -> Void

    private var match: Match { matchModel.toDomain() }

    @Environment(\.colorScheme) private var colorScheme
    @State private var scoreController = MatchController()
    @State private var scorecardContainerWidth: CGFloat = 0

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

    private var playerNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: match.participants.map { ($0.id, $0.displayName) })
    }

    private var playerColors: [UUID: Color] {
        Dictionary(uniqueKeysWithValues: match.participants.map { p in
            let themeType = Theme.ThemeType(rawValue: p.displayThemeID) ?? .midnight
            return (p.id, Theme(type: themeType, colorScheme: colorScheme).primaryAccent)
        })
    }

    private var participantsByScore: [Participant] {
        match.participants.sorted {
            scoreController.totalScore(for: $0.seat) > scoreController.totalScore(for: $1.seat)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                currentScoresCard
                if let prog = matchProgression(from: match) {
                    progressionCard(prog)
                }
                scorecardsCard
            }
            .padding(16)
        }
        .navigationTitle(match.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Resume") { onResume(matchModel) }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { scoreController.load(from: matchModel) }
    }

    private var currentScoresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Scores")
                .font(.headline)
            ForEach(participantsByScore) { participant in
                let color = playerColors[participant.id] ?? .primary
                HStack {
                    Text(participant.displayName)
                        .font(.subheadline)
                        .foregroundStyle(color)
                    Spacer()
                    Text(scoreController.totalScore(for: participant.seat), format: .number)
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

            Color.clear
                .frame(height: 0)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: UnfinishedScorecardWidthKey.self, value: geo.size.width)
                })

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: cardGap) {
                    ForEach(match.participants.sorted { $0.seat < $1.seat }) { participant in
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
        .onPreferenceChange(UnfinishedScorecardWidthKey.self) { width in
            if width > 0 { scorecardContainerWidth = width }
        }
    }
}

private struct UnfinishedScorecardWidthKey: PreferenceKey {
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
    match.statusRaw = "inProgress"
    match.startedAt = now.addingTimeInterval(-3_600)
    ctx.insert(match)

    func entry(_ category: YatzyCategory, _ value: Int, minutesAgo: Int) -> ScoreEntry {
        ScoreEntry(
            slotKey: category.slotKey, value: Decimal(value),
            metadata: nil, recordedAt: now.addingTimeInterval(Double(-minutesAgo * 60))
        )
    }

    let p1 = ParticipantModel()
    p1.seat = 0; p1.rank = 0; p1.finalScore = 0; p1.yahtzeeBonus = 0
    p1.displayName = "Wayne"; p1.displayInitials = "WM"
    p1.displayThemeID = Theme.ThemeType.midnight.rawValue
    p1.scoreEntries = [
        entry(.ones, 3, minutesAgo: 50),
        entry(.twos, 8, minutesAgo: 46),
        entry(.threes, 9, minutesAgo: 42),
        entry(.threeOfAKind, 20, minutesAgo: 38),
    ]
    p1.match = match
    ctx.insert(p1)

    let p2 = ParticipantModel()
    p2.seat = 1; p2.rank = 0; p2.finalScore = 0; p2.yahtzeeBonus = 0
    p2.displayName = "Sherida"; p2.displayInitials = "SM"
    p2.displayThemeID = Theme.ThemeType.forest.rawValue
    p2.scoreEntries = [
        entry(.ones, 2, minutesAgo: 49),
        entry(.twos, 6, minutesAgo: 45),
        entry(.threes, 6, minutesAgo: 41),
        entry(.threeOfAKind, 18, minutesAgo: 37),
    ]
    p2.match = match
    ctx.insert(p2)

    return NavigationStack {
        UnfinishedMatchDetailView(matchModel: match) { _ in }
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
