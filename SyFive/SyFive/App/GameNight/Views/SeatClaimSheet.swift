import SwiftUI
import SwiftData

/// Lets the local player pick themselves from the roster to claim a seat.
/// Presented from TableSettingView when the device hasn't yet claimed a seat.
struct SeatClaimSheet: View {
    @Bindable var gameNight: GameNightController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PlayerModel.name) private var players: [PlayerModel]

    private var availablePlayers: [PlayerModel] {
        let seatedIDs = Set(gameNight.seats.compactMap(\.playerID))
        return players.filter { !$0.isArchived && !seatedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availablePlayers.isEmpty {
                    ContentUnavailableView(
                        "Everyone's Seated",
                        systemImage: "person.3.fill",
                        description: Text("All players in your roster are already at the table.")
                    )
                } else {
                    List(availablePlayers, id: \.id) { player in
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
                }
            }
            .navigationTitle("Claim a Seat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
