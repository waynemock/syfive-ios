import SwiftUI
import SwiftData

/// Merges an archived player's match history into an active roster player.
/// The active player's UUID is kept; all of the retiring player's ParticipantModel
/// records are remapped to the active UUID, then the retiring PlayerModel is deleted.
struct PlayerMergeSheet: View {
    let retiring: PlayerModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    @State private var pendingMerge: PlayerModel? = nil

    private var activePlayers: [PlayerModel] {
        allPlayers
            .filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        PlayerInitialsCircle(
                            initials: retiring.initials,
                            themeType: Theme.ThemeType(rawValue: retiring.themeID) ?? .midnight,
                            opacity: 0.5
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(retiring.name)
                                .font(.headline)
                            Text("Archived — history will transfer to the player you pick")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    if activePlayers.isEmpty {
                        Text("No active roster players to merge into.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(activePlayers) { player in
                            targetRow(for: player)
                        }
                    }
                } header: {
                    Text("Move History To")
                } footer: {
                    Text("All of \(retiring.name)'s match history will be combined with the selected player's history. \(retiring.name) will be permanently removed.")
                }
            }
            .navigationTitle("Merge Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                pendingMerge.map { "Merge \(retiring.name) into \($0.name)?" } ?? "",
                isPresented: Binding(
                    get: { pendingMerge != nil },
                    set: { if !$0 { pendingMerge = nil } }
                ),
                presenting: pendingMerge
            ) { target in
                Button("Merge", role: .destructive) {
                    merge(into: target)
                }
                Button("Cancel", role: .cancel) {}
            } message: { target in
                Text("\(retiring.name)'s match history will be added to \(target.name)'s record. \(retiring.name) will be removed.")
            }
        }
    }

    private func targetRow(for player: PlayerModel) -> some View {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let theme = Theme(type: themeType, colorScheme: colorScheme)

        return HStack(spacing: 12) {
            PlayerInitialsCircle(initials: player.initials, themeType: themeType)

            Text(player.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { pendingMerge = player }
    }

    private func merge(into target: PlayerModel) {
        let retiringID = retiring.id
        let canonicalID = target.id

        let allParticipants = (try? modelContext.fetch(FetchDescriptor<ParticipantModel>())) ?? []
        for participant in allParticipants where participant.playerID == retiringID {
            participant.playerID = canonicalID
        }

        modelContext.delete(retiring)

        try? modelContext.save()

        dismiss()
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

    let active1 = PlayerModel()
    active1.name = "Sherida"
    active1.initials = "SM"
    active1.themeID = Theme.ThemeType.forest.rawValue
    container.mainContext.insert(active1)

    let active2 = PlayerModel()
    active2.name = "Wayne"
    active2.initials = "WM"
    active2.themeID = Theme.ThemeType.midnight.rawValue
    container.mainContext.insert(active2)

    let archived = PlayerModel()
    archived.name = "Sherida iMoc"
    archived.initials = "SM"
    archived.themeID = Theme.ThemeType.forest.rawValue
    archived.isArchived = true
    container.mainContext.insert(archived)

    return PlayerMergeSheet(retiring: archived)
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
