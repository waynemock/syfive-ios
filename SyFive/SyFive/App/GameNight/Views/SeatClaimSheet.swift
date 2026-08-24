import SwiftUI
import SwiftData

/// Lets the local player pick themselves from the roster to claim a seat.
/// Presented from TableSettingView when the device hasn't yet claimed a seat.
struct SeatClaimSheet: View {
    @Bindable var gameNight: GameNightController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PlayerModel.name) private var players: [PlayerModel]

    @State private var showsNewPlayer = false
    @State private var pendingDismissAfterCreate = false
    @State private var dummyMatchModel = MatchController()

    private var availablePlayers: [PlayerModel] {
        let seatedIDs = Set(gameNight.seats.compactMap(\.playerID))
        return players.filter { !$0.isArchived && !seatedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availablePlayers, id: \.id) { player in
                    Button {
                        gameNight.claimSeat(
                            displayName: player.name,
                            displayInitials: player.initials,
                            themeID: player.themeID,
                            playerID: player.id
                        )
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            InitialsCircle(
                                initials: player.initials,
                                themeID: player.themeID,
                                colorScheme: colorScheme
                            )
                            Text(player.name)
                                .foregroundStyle(.primary)
                        }
                    }
                }

                addPlayerCard
            }
            .navigationTitle("Claim a Seat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showsNewPlayer) {
                PlayerEditSheet(
                    mode: .create,
                    matchModel: dummyMatchModel,
                    onCreated: { pm in
                        gameNight.claimSeat(
                            displayName: pm.name,
                            displayInitials: pm.initials,
                            themeID: pm.themeID,
                            playerID: pm.id
                        )
                        pendingDismissAfterCreate = true
                    }
                )
            }
            .onChange(of: showsNewPlayer) { _, showing in
                if !showing && pendingDismissAfterCreate {
                    dismiss()
                }
            }
        }
    }

    private var addPlayerCard: some View {
        return Button {
            showsNewPlayer = true
        } label: {
            Label("New Player", systemImage: "plus.circle.fill")
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private func makeSeatClaimContainer(players: [(String, String, String)] = []) -> ModelContainer {
    let container = try! ModelContainer(
        for: PlayerModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for (name, initials, themeID) in players {
        let pm = PlayerModel()
        pm.name = name
        pm.initials = initials
        pm.themeID = themeID
        container.mainContext.insert(pm)
    }
    return container
}

#Preview("With Players") {
    let container = makeSeatClaimContainer(players: [
        ("Alice Nakamura", "AN", "Midnight"),
        ("Bob Chen",       "BC", "Ocean"),
        ("Carmen Reyes",   "CR", "Forest"),
        ("Dave Kim",       "DK", "Ember"),
    ])
    SeatClaimSheet(gameNight: GameNightController())
        .modelContainer(container)
}

#Preview("Empty Roster") {
    SeatClaimSheet(gameNight: GameNightController())
        .modelContainer(makeSeatClaimContainer())
}
