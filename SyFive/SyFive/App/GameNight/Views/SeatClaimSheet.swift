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
        let theme = Theme(type: dummyMatchModel.nextPlayerThemeType, colorScheme: colorScheme)
        return Button {
            showsNewPlayer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                Text("Add Player")
                    .font(.title3)
                Spacer()
            }
            .padding(12)
            .foregroundStyle(theme.primaryAccent)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cellBackgroundColor)
        )
    }
}
