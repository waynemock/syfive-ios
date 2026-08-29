import SwiftUI
import SyLibScoring
import SyLibUI
import SwiftData
import SyLibScoringData

/// Lets the user link a Game Night player to an existing local roster player.
/// On confirmation the local player's match history is remapped to the Game Night UUID,
/// the local PlayerModel is deleted, and the Game Night player is promoted to .local source.
/// Game Night ID is always kept — it is the more durable cross-device identity.
struct PlayerLinkSheet: View {
    let gameNightPlayer: PlayerModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme

    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    @State private var pendingMerge: PlayerModel? = nil

    private var localPlayers: [PlayerModel] {
        allPlayers
            .filter { !$0.isArchived && $0.source == .local }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        InitialsCircle(
                            initials: gameNightPlayer.initials,
                            color: Theme.accent(forThemeID: gameNightPlayer.themeID, colorScheme: colorScheme),
                            diameter: 28
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gameNightPlayer.name)
                                .font(.headline)
                            Text("Game Night player — their ID will be kept")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    if localPlayers.isEmpty {
                        Text("No roster players to link with.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(localPlayers) { player in
                            rosterRow(for: player)
                        }
                    }
                } header: {
                    Text("Select Roster Player to Merge")
                        .foregroundStyle(theme.primaryAccent)
                } footer: {
                    Text("All of the selected player's match history will be combined with \(gameNightPlayer.name)'s history. The roster entry will be removed.")
                }
            }
            .navigationTitle("Link Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(
                pendingMerge.map { "Merge \($0.name) with \(gameNightPlayer.name)?" } ?? "",
                isPresented: Binding(
                    get: { pendingMerge != nil },
                    set: { if !$0 { pendingMerge = nil } }
                ),
                presenting: pendingMerge
            ) { localPlayer in
                Button("Merge") {
                    merge(localPlayer: localPlayer)
                }
                Button("Cancel", role: .cancel) {}
            } message: { localPlayer in
                Text("\(localPlayer.name)'s match history will transfer to \(gameNightPlayer.name). \(localPlayer.name) will be removed from your roster.")
            }
        }
    }

    private func rosterRow(for player: PlayerModel) -> some View {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let theme = Theme(type: themeType, colorScheme: colorScheme)

        return HStack(spacing: 12) {
            InitialsCircle(initials: player.initials, color: theme.primaryAccent, diameter: 28)

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

    private func merge(localPlayer: PlayerModel) {
        let localID = localPlayer.id
        let canonicalID = gameNightPlayer.id

        let allParticipants = (try? modelContext.fetch(FetchDescriptor<ParticipantModel>())) ?? []
        for participant in allParticipants where participant.playerID == localID {
            participant.playerID = canonicalID
        }

        modelContext.delete(localPlayer)
        gameNightPlayer.source = .local

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

    let local1 = PlayerModel()
    local1.name = "Wayne"
    local1.initials = "WM"
    local1.themeID = Theme.ThemeType.midnight.rawValue
    container.mainContext.insert(local1)

    let local2 = PlayerModel()
    local2.name = "Sherida (local)"
    local2.initials = "SM"
    local2.themeID = Theme.ThemeType.forest.rawValue
    container.mainContext.insert(local2)

    let gnPlayer = PlayerModel()
    gnPlayer.name = "Sherida"
    gnPlayer.initials = "SM"
    gnPlayer.themeID = Theme.ThemeType.forest.rawValue
    gnPlayer.source = .gameNight
    container.mainContext.insert(gnPlayer)

    return PlayerLinkSheet(gameNightPlayer: gnPlayer)
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
