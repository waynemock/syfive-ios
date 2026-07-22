import SwiftUI
import SwiftData

struct PlayersView: View {
    @State private var matchController = MatchController()
    @State private var playerEditMode: PlayerEditSheet.Mode? = nil
    @State private var selectedProfile: PlayerModel? = nil
    @State private var pendingArchive: PlayerModel? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    private var rosterPlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived }.sorted { $0.name < $1.name }
    }

    private var archivedPlayers: [PlayerModel] {
        allPlayers.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Roster") {
                    ForEach(rosterPlayers) { player in
                        rosterRow(for: player)
                    }

                    Button {
                        playerEditMode = .create
                    } label: {
                        Label("New Player", systemImage: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                if !archivedPlayers.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPlayers) { player in
                            archivedRow(for: player)
                        }
                    }
                }
            }
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $playerEditMode) { mode in
                PlayerEditSheet(mode: mode, matchModel: matchController)
            }
            .sheet(item: $selectedProfile) { player in
                PlayerProfileView(
                    playerID: player.id,
                    playerName: player.name,
                    themeType: Theme.ThemeType(rawValue: player.themeID) ?? .midnight
                )
            }
            .alert(
                pendingArchive.map { "Archive \($0.name)?" } ?? "",
                isPresented: Binding(
                    get: { pendingArchive != nil },
                    set: { if !$0 { pendingArchive = nil } }
                ),
                presenting: pendingArchive
            ) { player in
                Button("Archive", role: .destructive) {
                    player.isArchived = true
                    pendingArchive = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("They'll be moved to the archive and removed from your roster.")
            }
        }
    }

    // MARK: - Row views

    private func rosterRow(for player: PlayerModel) -> some View {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let theme = Theme(type: themeType, colorScheme: colorScheme)

        return HStack(spacing: 12) {
            PlayerInitialsCircle(initials: player.initials, themeType: themeType)

            Text(player.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent)

            Button {
                playerEditMode = .edit(player, matchSlot: nil)
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(theme.secondaryAccent)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedProfile = player }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingArchive = player
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(.red)
        }
    }

    private func archivedRow(for player: PlayerModel) -> some View {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let theme = Theme(type: themeType, colorScheme: colorScheme)

        return HStack(spacing: 12) {
            PlayerInitialsCircle(initials: player.initials, themeType: themeType, opacity: 0.4)

            Text(player.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent.opacity(0.4))

            Spacer()

            Button {
                player.isArchived = false
            } label: {
                Image(systemName: "arrow.up.trash")
                    .foregroundStyle(.secondary)
                    .font(.title)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                player.isArchived = false
            } label: {
                Label("Unarchive", systemImage: "arrow.up.trash")
            }
            .tint(.green)
        }
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

    let p1 = PlayerModel()
    p1.name = "Wayne"
    p1.initials = "WM"
    p1.themeID = Theme.ThemeType.midnight.rawValue
    container.mainContext.insert(p1)

    let p2 = PlayerModel()
    p2.name = "Sherida"
    p2.initials = "SM"
    p2.themeID = Theme.ThemeType.forest.rawValue
    container.mainContext.insert(p2)

    let p3 = PlayerModel()
    p3.name = "Weston"
    p3.initials = "WM"
    p3.themeID = Theme.ThemeType.ember.rawValue
    p3.isArchived = true
    container.mainContext.insert(p3)

    return PlayersView()
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
