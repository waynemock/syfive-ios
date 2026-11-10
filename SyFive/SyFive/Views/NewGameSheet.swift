import SwiftUI
import SwiftData
import SyLibScoring
import SyLibScoringData
import SyLibScoringUI
import SyLibUI

/// New Game (38 §2.8, D-207): SyLib's match setup, editing the game live. Seating a player,
/// reordering, removing and Same as Last Time change `MatchController` at once, so the pre-game grid
/// behind the sheet follows along. Done, or swiping the sheet down, just closes: there's nothing to
/// cancel and nothing to lose. An empty table is allowed. The first roll still starts the game.
struct NewGameSheet: View {
    @Bindable var model: MatchController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syTheme) private var theme
    @Query(sort: \PlayerModel.name) private var allPlayers: [PlayerModel]
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" })
    private var completedMatches: [MatchModel]

    @State private var showsNewPlayer = false

    private func player(_ id: UUID) -> PlayerModel? {
        allPlayers.first { $0.id == id }
    }

    /// The game's seats as roster players, in seat order. A slot with no roster player isn't shown
    /// (only previews have one), so `SeatList`'s offsets count these, not the controller's slots.
    private var seatedPlayers: [PlayerModel] {
        model.playerIDs.compactMap { $0.flatMap(player) }
    }

    private var unseatedPlayers: [PlayerModel] {
        let seated = Set(model.playerIDs.compactMap { $0 })
        return allPlayers.filter { !$0.isArchived && !seated.contains($0.id) }
    }

    private var lastTime: [UUID] {
        Self.lastTimePlayerIDs(matches: completedMatches, roster: allPlayers)
    }

    var body: some View {
        MatchSetupForm(title: "New Game", canStart: true, onCancel: {}, onStart: { dismiss() },
                       buttons: .done) {
            let lastTime = lastTime
            let seated = seatedPlayers
            // Same as Last Time is Players' first chip (38 §2.7), shown when last time's players
            // differ from the seated players as a set: the same players reordered count as the same.
            let showsLastTime = !lastTime.isEmpty && Set(lastTime) != Set(seated.map(\.id))
            SeatList(players: seated, onMove: moveSeat, onRemove: removeSeats)
            PlayerPicker(players: unseatedPlayers,
                         onSeat: { model.addPlayer(from: $0.toDomain()) },
                         onNewPlayer: { showsNewPlayer = true },
                         onSameAsLastTime: showsLastTime
                             ? { model.setPlayers(lastTime.compactMap { player($0)?.toDomain() }) }
                             : nil)
        }
        .sheet(isPresented: $showsNewPlayer) {
            // No onCreated: the editor seats the new player in the game itself, as before 38.
            PlayerEditSheet(mode: .create, matchModel: model)
                .environment(\.syTheme, theme)
                .sheetTextSizeCeiling()
        }
    }

    /// `SeatList`'s move, in shown-seat offsets, made on the controller's slots through the two
    /// players' ids, looked up now so a stale index can't move the wrong seat (38.9 v1.8). List's
    /// offset is insert-before, converted as the old sheet did. Nothing happens if a seat is gone.
    private func moveSeat(from offsets: IndexSet, to destination: Int) {
        guard let source = offsets.first else { return }
        let target = source < destination ? destination - 1 : destination
        let shown = seatedPlayers
        guard shown.indices.contains(source), shown.indices.contains(target),
              let from = model.playerIDs.firstIndex(of: shown[source].id),
              let to = model.playerIDs.firstIndex(of: shown[target].id) else { return }
        model.movePlayer(from: from, to: to)
    }

    /// `SeatList`'s remove, in shown-seat offsets, made on the controller's slots through each
    /// player's id, looked up now (38.9 v1.8). A seat that's gone is skipped.
    private func removeSeats(at offsets: IndexSet) {
        let shown = seatedPlayers
        let ids = offsets.filter { shown.indices.contains($0) }.map { shown[$0].id }
        for id in ids {
            if let slot = model.playerIDs.firstIndex(of: id) {
                model.removePlayer(at: slot)
            }
        }
    }

    /// Who played last time (38 §2.3): the player ids of the most recent completed match that wasn't
    /// Game Night, by `completedAt`, one row per match id, in seat order, keeping active roster
    /// players only. Empty when there is no such match. Internal for tests.
    static func lastTimePlayerIDs(matches: [MatchModel], roster: [PlayerModel]) -> [UUID] {
        let latest = matches.onePerMatchID()
            .filter { $0.statusRaw == "completed" && !$0.isGameNight }
            .max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        guard let latest else { return [] }
        let active = Set(roster.filter { !$0.isArchived }.map(\.id))
        return latest.participants
            .sorted { $0.seat < $1.seat }
            .compactMap(\.playerID)
            .filter { active.contains($0) }
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

    let model = MatchController()
    model.addPlayer(from: p1.toDomain())

    return NewGameSheet(model: model)
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
