import SwiftUI
import SyLibCore
import SyLibScoring
import SyLibUI
import SyLibScoringData
import SwiftData

struct PlayersView: View {
    @State private var matchController = MatchController()
    @State private var playerEditMode: PlayerEditSheet.Mode? = nil
    @State private var selectedProfile: PlayerModel? = nil
    @State private var pendingArchive: PlayerModel? = nil
    @State private var pendingLink: PlayerModel? = nil
    @State private var pendingMerge: PlayerModel? = nil
    @State private var mergeFailureMessage: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    private let logger = AppLogger(category: "PlayersView")

    private var rosterPlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived && $0.source == .local }.sorted { $0.name < $1.name }
    }

    private var gameNightPlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived && $0.source == .gameNight }.sorted { $0.name < $1.name }
    }

    private var archivedPlayers: [PlayerModel] {
        allPlayers.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if !gameNightPlayers.isEmpty {
                    Section {
                        ForEach(gameNightPlayers) { player in
                            gameNightRow(for: player)
                        }
                    } header: {
                        Text("From Game Night")
                            .foregroundStyle(theme.primaryAccent)
                    } footer: {
                        Text("These players joined via Game Night. Add them to your roster or link them to an existing player.")
                    }
                }

                Section {
                    ForEach(rosterPlayers) { player in
                        rosterRow(for: player)
                    }

                    Button {
                        playerEditMode = .create
                    } label: {
                        Label("New Player", systemImage: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                } header: {
                    Text("Roster")
                        .foregroundStyle(theme.primaryAccent)
                }

                if !archivedPlayers.isEmpty {
                    Section {
                        ForEach(archivedPlayers) { player in
                            archivedRow(for: player)
                        }
                    } header: {
                        Text("Archived")
                            .foregroundStyle(theme.primaryAccent)
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
                    .environment(\.theme, theme)
            }
            .sheet(item: $selectedProfile) { player in
                PlayerProfileView(
                    playerID: player.id,
                    playerName: player.name,
                    themeType: Theme.ThemeType(rawValue: player.themeID) ?? .midnight,
                    isArchived: player.isArchived
                )
            }
            .sheet(item: $pendingLink) { gameNightPlayer in
                let subject = rosterEntry(for: gameNightPlayer)
                let candidates = allPlayers
                    .filter { !$0.isArchived && $0.source == .local }
                    .sorted { $0.name < $1.name }
                    .map { rosterEntry(for: $0) }
                PlayerLinkSheet(subject: subject, candidates: candidates,
                                accentColor: theme.primaryAccent) { localID in
                    if let local = allPlayers.first(where: { $0.id == localID }) {
                        gameNightPlayer.source = .local
                        do {
                            try absorbPlayer(local, into: gameNightPlayer.id, in: modelContext)
                        } catch {
                            logger.error(self, "absorbPlayer (link) failed: \(error)")
                            mergeFailureMessage = "Couldn't link those players. Please try again."
                        }
                    }
                }
            }
            .sheet(item: $pendingMerge) { retiring in
                let subject = rosterEntry(for: retiring)
                // $0.id != retiring.id is redundant today — merge is only reachable from the
                // archived-row swipe action so retiring.isArchived is always true and
                // !$0.isArchived already excludes it. Keep as defensive: if a future path adds
                // merge for active players it becomes load-bearing, not a no-op.
                let candidates = allPlayers
                    .filter { !$0.isArchived && $0.id != retiring.id }
                    .sorted { $0.name < $1.name }
                    .map { rosterEntry(for: $0) }
                PlayerMergeSheet(subject: subject, candidates: candidates,
                                 accentColor: theme.primaryAccent) { candidateID in
                    do {
                        try absorbPlayer(retiring, into: candidateID, in: modelContext)
                    } catch {
                        logger.error(self, "absorbPlayer (merge) failed: \(error)")
                        mergeFailureMessage = "Couldn't merge those players. Please try again."
                    }
                }
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
            .alert(
                "Player Action Failed",
                isPresented: Binding(
                    get: { mergeFailureMessage != nil },
                    set: { if !$0 { mergeFailureMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mergeFailureMessage ?? "")
            }
        }
    }

    // MARK: - Helpers

    private func rosterEntry(for player: PlayerModel) -> PlayerRosterEntry {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let t = Theme(type: themeType, colorScheme: colorScheme)
        return PlayerRosterEntry(
            id: player.id,
            name: player.name,
            initials: player.initials,
            themeID: player.themeID,
            accentColor: t.primaryAccent,
            secondaryColor: t.secondaryAccent
        )
    }

    // MARK: - Row views

    private func gameNightRow(for player: PlayerModel) -> some View {
        let themeType = Theme.ThemeType(rawValue: player.themeID) ?? .midnight
        let theme = Theme(type: themeType, colorScheme: colorScheme)

        return HStack(spacing: 12) {
            InitialsCircle(initials: player.initials, color: theme.primaryAccent, diameter: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                    .foregroundStyle(theme.secondaryAccent)
                HStack(spacing: 3) {
                    Image(systemName: "person.3.fill")
                        .font(.caption2)
                    Text("Game Night")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                player.source = .local
                try? modelContext.save()
            } label: {
                Text("Add to Roster")
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                pendingLink = player
            } label: {
                Label("Link", systemImage: "link")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingArchive = player
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(.red)
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

            Button {
                playerEditMode = .edit(player, matchSlot: nil)
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(theme.secondaryAccent)
            }
            .buttonStyle(.plain)

            Spacer()

            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(theme.primaryAccent)
                .font(.title2)
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
            InitialsCircle(initials: player.initials, color: theme.primaryAccent, diameter: 28, opacity: 0.4)

            Text(player.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent.opacity(0.4))

            Spacer()

            Image(systemName: "list.bullet.rectangle")
                .foregroundStyle(theme.primaryAccent.opacity(0.4))
                .font(.title2)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedProfile = player }
        .swipeActions(edge: .leading) {
            Button {
                player.isArchived = false
            } label: {
                Label("Unarchive", systemImage: "arrow.up.trash")
            }
            .tint(.green)

            Button {
                pendingMerge = player
            } label: {
                Label("Merge", systemImage: "arrow.triangle.merge")
            }
            .tint(.blue)
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

    let p4 = PlayerModel()
    p4.name = "Sherida"
    p4.initials = "SM"
    p4.themeID = Theme.ThemeType.forest.rawValue
    p4.source = .gameNight
    container.mainContext.insert(p4)

    return PlayersView()
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
