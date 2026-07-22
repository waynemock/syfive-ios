import SwiftUI
import SwiftData

struct HouseRecordsView: View {
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt)
    private var completedModels: [MatchModel]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme

    private var titles: [HouseRecords.Title] {
        HouseRecords.compute(from: completedModels.map { $0.toDomain() })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(titles) { title in
                        TitleCard(title: title)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("House Records")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Title card

private struct TitleCard: View {
    let title: HouseRecords.Title

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title name
            Text(title.name.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.bottom, 10)

            switch title.state {
            case .claimed(let holders, let displayValue):
                ClaimedContent(holders: holders, displayValue: displayValue)
            case .unclaimed:
                UnclaimedContent(gated: false)
            case .unclaimedGated:
                UnclaimedContent(gated: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Claimed content

private struct ClaimedContent: View {
    let holders: [HouseRecords.Holder]
    let displayValue: String

    @Environment(\.colorScheme) private var colorScheme

    private var holderTheme: Theme {
        let themeType = holders.first.flatMap { Theme.ThemeType(rawValue: $0.displayThemeID) } ?? .midnight
        return Theme(type: themeType, colorScheme: colorScheme)
    }

    private var allSameDate: Bool {
        guard holders.count > 1 else { return true }
        let first = holders[0].heldSince
        return holders.dropFirst().allSatisfy { $0.heldSince == first }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Holder rows
            ForEach(holders) { holder in
                HolderRow(holder: holder, showDate: !allSameDate)
            }

            Divider()
                .padding(.vertical, 4)

            // Record value
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(holderTheme.primaryAccent)

                Spacer()

                // Collective date when all holders share it
                if allSameDate, let date = holders.first?.heldSince {
                    Text(formatDate(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Holder row

private struct HolderRow: View {
    let holder: HouseRecords.Holder
    let showDate: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var themeType: Theme.ThemeType {
        Theme.ThemeType(rawValue: holder.displayThemeID) ?? .midnight
    }

    var body: some View {
        HStack(spacing: 10) {
            PlayerInitialsCircle(initials: holder.displayInitials, themeType: themeType)

            VStack(alignment: .leading, spacing: 1) {
                Text(holder.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let count = holder.sampleCount {
                    Text("\(count) game\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if showDate {
                Text(holder.heldSince.formatted(.dateTime.month(.abbreviated).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Unclaimed content

private struct UnclaimedContent: View {
    let gated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unclaimed")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if gated {
                Text("After 10 games")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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
        p1.displayThemeID = Theme.ThemeType.midnight.rawValue
        p1.finalScore = Decimal(i % 3 == 0 ? 290 : 220); p1.rank = i % 3 == 0 ? 2 : 1
        p1.match = match
        container.mainContext.insert(p1)

        let p2 = ParticipantModel()
        p2.displayName = "Sherida"; p2.displayInitials = "SM"
        p2.displayThemeID = Theme.ThemeType.forest.rawValue
        p2.finalScore = Decimal(i % 3 == 0 ? 310 : 195); p2.rank = i % 3 == 0 ? 1 : 2
        p2.match = match
        container.mainContext.insert(p2)
    }

    let theme = Theme(type: .midnight, colorScheme: .dark)
    return HouseRecordsView()
        .modelContainer(container)
        .environment(\.theme, theme)
        .preferredColorScheme(.dark)
}
