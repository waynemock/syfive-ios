import SwiftUI
import SyLibCore
import SyLibScoring
import SyLibUI
import SyLibScoringData
import SyLibScoringUI
import SwiftData

struct PlayersView: View {
    @State private var matchController = MatchController()
    @State private var playerEditMode: PlayerEditSheet.Mode? = nil
    @State private var pendingArchive: PlayerModel? = nil
    @State private var pendingLink: PlayerModel? = nil
    @State private var pendingMerge: PlayerModel? = nil
    @State private var mergeFailureMessage: String? = nil
    /// The name for §2.2's "Can't delete" alert: an archived player in a game in progress (34).
    @State private var undeletableName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syTheme) private var theme

    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]
    @Query private var participants: [ParticipantModel]

    private let logger = AppLogger(category: "PlayersView")

    private var gameNightPlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived && $0.source == .gameNight }.sorted { $0.name < $1.name }
    }

    /// The sheet's roster: local players and every archived one, by name (30 §4).
    private var listedPlayers: [PlayerModel] {
        allPlayers.filter { $0.source == .local || $0.isArchived }.sorted { $0.name < $1.name }
    }

    /// Players' words (30 §2.6, D-180).
    private static let copy = PlayersSheetCopy(
        archiveMessage: "They won't appear in New Game. Their history stays.",
        unarchiveMessage: "They'll appear in New Game again.",
        deleteTitle: "Delete this player?", deleteMessage: "This can't be undone.",
        emptyTitle: "No players yet", emptyMessage: "Add players here, or when you start a new game.")

    /// Each listed player as a row: "1 game" or "N games", N their completed matches from SyLib's
    /// `completedMatchCounts` (once per match id; 34 §3, Task 34.2); Delete only for a player no
    /// participant anywhere has, finished or not (D-177, D-179).
    private var entries: [PlayerListEntry] {
        let completedCounts = (try? completedMatchCounts(in: modelContext)) ?? [:]
        var everPlayed: Set<UUID> = []
        for participant in participants {
            guard let playerID = participant.playerID else { continue }
            everPlayed.insert(playerID)
        }
        return listedPlayers.map { player in
            let n = completedCounts[player.id] ?? 0
            return PlayerListEntry(id: player.id, name: player.name, initials: player.initials,
                                   themeID: player.themeID, stats: n == 1 ? "1 game" : "\(n) games",
                                   isArchived: player.isArchived, canDelete: !everPlayed.contains(player.id))
        }
    }

    private func player(_ id: UUID) -> PlayerModel? {
        allPlayers.first { $0.id == id }
    }

    /// `{others}` in the archived-delete alert (34 §2.1): "Ada", "Ada and Bo", "Ada, Bo and Cy",
    /// then "Ada, Bo, Cy and 1 other" or "… and k others". Internal for the tests.
    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        case 3: return "\(names[0]), \(names[1]) and \(names[2])"
        default:
            let k = names.count - 3
            return "\(names[0]), \(names[1]), \(names[2]) and \(k) \(k == 1 ? "other" : "others")"
        }
    }

    /// Delete on archived rows: the player and every game they played (34 §2.1, D-194). The
    /// counts are completed games only (`playerDeletionImpact`).
    private var archivedDelete: PlayersSheetArchivedDelete {
        PlayersSheetArchivedDelete(
            title: { id in
                let name = player(id)?.name ?? ""
                let n = (try? playerDeletionImpact(playerID: id, in: modelContext))?.matches ?? 0
                switch n {
                case 0: return "Delete \(name)?"
                case 1: return "Delete \(name) and 1 game?"
                default: return "Delete \(name) and \(n) games?"
                }
            },
            message: { id in
                guard let impact = try? playerDeletionImpact(playerID: id, in: modelContext),
                      impact.matches > 0 else { return "This can't be undone." }
                if impact.others.isEmpty {
                    return "Those games leave your records. This can't be undone."
                }
                return "Those games leave everyone's records, including \(Self.list(impact.others)). This can't be undone."
            },
            action: { id in
                guard let player = player(id) else { return }
                // §2.2: not while they're in a game in progress. "inProgress" only: abandoned rows
                // from earlier builds go with the player.
                let inGame = participants.contains { $0.playerID == id && $0.match?.statusRaw == "inProgress" }
                if inGame {
                    let name = player.name
                    // Set after the sheet's confirm alert has closed, so this one can present.
                    Task { @MainActor in undeletableName = name }
                    return
                }
                do {
                    // Deletes every row of the id, its matches and their participants; SyFive
                    // deletes nothing itself.
                    try deletePlayerAndMatches(player, in: modelContext)
                } catch {
                    logger.error(self, "deletePlayerAndMatches failed: \(error)")
                    mergeFailureMessage = "Couldn't delete that player. Please try again."
                }
            })
    }

    var body: some View {
        PlayersSheet(
            players: entries,
            copy: Self.copy,
            hasLeadingContent: !gameNightPlayers.isEmpty,
            onAdd: { playerEditMode = .create },
            onEdit: { id in
                if let player = player(id) { playerEditMode = .edit(player, matchSlot: nil) }
            },
            onArchive: { id in
                player(id)?.isArchived = true
                try? modelContext.save()
            },
            onUnarchive: { id in
                player(id)?.isArchived = false
                try? modelContext.save()
            },
            onDelete: { id in
                // Refuses a played player and deletes every synced row of the id; it saves (34.2).
                if (try? deleteUnplayedPlayer(id: id, in: modelContext)) != true {
                    mergeFailureMessage = "Couldn't delete that player. Please try again."
                }
            },
            onMerge: { id in pendingMerge = player(id) },
            archivedDelete: archivedDelete,
            profile: { id in
                if let player = player(id) {
                    PlayerProfileView(
                        playerID: player.id,
                        playerName: player.name,
                        themeType: SyTheme.ThemeType(themeID: player.themeID),
                        isArchived: player.isArchived,
                        isPushed: true,
                        matchModel: matchController
                    )
                }
            },
            leadingSections: {
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
            }
        )
        .sheet(item: $playerEditMode) { mode in
            PlayerEditSheet(mode: mode, matchModel: matchController)
                .environment(\.syTheme, theme)
                .sheetTextSizeCeiling()
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
            .sheetTextSizeCeiling()
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
            .sheetTextSizeCeiling()
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
            Text("They won't appear in New Game. Their history stays.")
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
        .alert(
            undeletableName.map { "Can't delete \($0)" } ?? "",
            isPresented: Binding(
                get: { undeletableName != nil },
                set: { if !$0 { undeletableName = nil } }
            ),
            presenting: undeletableName
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { name in
            Text("\(name) is in a game that isn't finished. Finish it, or delete it from Match History, first.")
        }
    }

    // MARK: - Helpers

    private func rosterEntry(for player: PlayerModel) -> PlayerRosterEntry {
        let themeType = SyTheme.ThemeType(themeID: player.themeID)
        let t = SyTheme(type: themeType, colorScheme: colorScheme)
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
        let themeType = SyTheme.ThemeType(themeID: player.themeID)
        let theme = SyTheme(type: themeType, colorScheme: colorScheme)

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
    p1.themeID = SyTheme.ThemeType.midnight.rawValue
    container.mainContext.insert(p1)

    let p2 = PlayerModel()
    p2.name = "Sherida"
    p2.initials = "SM"
    p2.themeID = SyTheme.ThemeType.forest.rawValue
    container.mainContext.insert(p2)

    let p3 = PlayerModel()
    p3.name = "Weston"
    p3.initials = "WM"
    p3.themeID = SyTheme.ThemeType.ember.rawValue
    p3.isArchived = true
    container.mainContext.insert(p3)

    let p4 = PlayerModel()
    p4.name = "Sherida"
    p4.initials = "SM"
    p4.themeID = SyTheme.ThemeType.forest.rawValue
    p4.source = .gameNight
    container.mainContext.insert(p4)

    return PlayersView()
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
