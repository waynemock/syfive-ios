import SwiftUI
import SyLibUI
import SyLibScoringUI
import SwiftData
import SyLibScoringData

struct HouseRecordsView: View {
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.syTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var minimum = RecordCard.gridMinimum
    @State private var width: CGFloat = 0

    private var titles: [HouseRecords.Title] {
        HouseRecords.compute(from: completedModels.map { $0.toDomain() })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RecordsSectionHeader(title: "All Games", subtitle: "Solo and multiplayer")
                    RecordCard.grid(titles.filter { $0.category == .event }, id: \.id,
                                    width: width, minimum: minimum) {
                        RecordCard(title: $0.name, content: content(for: $0))
                    }
                    // One width for both grids, measured on the first.
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                    RecordsSectionHeader(title: "Head-to-Head", subtitle: "Multiplayer only")
                        .padding(.top, 8)
                    RecordCard.grid(titles.filter { $0.category == .standing }, id: \.id,
                                    width: width, minimum: minimum) {
                        RecordCard(title: $0.name, content: content(for: $0))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(theme.backgroundColor)
            .navigationTitle("House Records")
            .navigationBarTitleDisplayMode(.inline)
            .paletteBarBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.primaryAccent)
    }

    /// A title's state as SyLib's card shows it; the copy is today's (D-164).
    private func content(for title: HouseRecords.Title) -> RecordCard.Content {
        switch title.state {
        case .claimed(let holders, let displayValue):
            return .claimed(holders: holders.map {
                RecordCard.Holder(id: $0.id, name: $0.displayName, initials: $0.displayInitials,
                                  themeID: $0.displayThemeID, date: $0.heldSince,
                                  caption: $0.sampleCount.map { "\($0) game\($0 == 1 ? "" : "s")" })
            }, value: displayValue)
        case .unclaimed:
            return .unclaimed(label: "Unclaimed", note: nil)
        case .unclaimedGated:
            return .unclaimed(label: "Unclaimed", note: "After 10 games")
        }
    }
}

// MARK: - Section header

private struct RecordsSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([
        PlayerModel.self, TeamModel.self, GameModel.self,
        MatchModel.self, ParticipantModel.self, AppSettingsModel.self,
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )

    for i in 0..<14 {
        let match = MatchModel()
        match.statusRaw = "completed"
        match.completedAt = Date().addingTimeInterval(Double(i) * -86400)
        container.mainContext.insert(match)

        let p1 = ParticipantModel()
        p1.displayName = "Wayne"; p1.displayInitials = "WM"
        p1.displayThemeID = SyTheme.ThemeType.midnight.rawValue
        p1.finalScore = Decimal(i % 3 == 0 ? 290 : 220); p1.rank = i % 3 == 0 ? 2 : 1
        p1.match = match
        container.mainContext.insert(p1)

        let p2 = ParticipantModel()
        p2.displayName = "Sherida"; p2.displayInitials = "SM"
        p2.displayThemeID = SyTheme.ThemeType.forest.rawValue
        p2.finalScore = Decimal(i % 3 == 0 ? 310 : 195); p2.rank = i % 3 == 0 ? 1 : 2
        p2.match = match
        container.mainContext.insert(p2)
    }

    let theme = SyTheme(type: .midnight, colorScheme: .dark)
    return HouseRecordsView()
        .modelContainer(container)
        .environment(\.syTheme, theme)
        .preferredColorScheme(.dark)
}
