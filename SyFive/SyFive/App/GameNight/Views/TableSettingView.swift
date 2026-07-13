import SwiftUI
import SwiftData

/// The pre-game seating screen shown to all players during the `settingTable` phase.
/// Host sees reorder/remove controls and a Start button; guests see a seat-claim button.
/// Commentary override row is editable by the host and read-only for guests.
struct TableSettingView: View {
    @Bindable var gameNight: GameNightController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsSeatClaim = false
    @State private var showsInviteInstructions = false

    var body: some View {
        NavigationStack {
            List {
                seatsSection
                if gameNight.phase == .settingTable {
                    claimSection
                }
                commentarySection
            }
            .navigationTitle("Game Night")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Leave") {
                        gameNight.endSession()
                        dismiss()
                    }
                }
                if gameNight.role == .host && gameNight.phase == .settingTable {
                    ToolbarItem(placement: .topBarTrailing) {
                        StartGameButton(gameNight: gameNight)
                    }
                }
            }
            .sheet(isPresented: $showsSeatClaim) {
                SeatClaimSheet(gameNight: gameNight)
            }
            .sheet(isPresented: $showsInviteInstructions) {
                GameNightInviteInstructions()
            }
        }
    }

    // MARK: - Sections

    private var seatsSection: some View {
        Section("Table") {
            if gameNight.seats.isEmpty {
                Text("Claim a seat to join the table")
                    .foregroundStyle(.secondary)
                    .italic()
            }
            ForEach(gameNight.seats, id: \.seatClaimID) { seat in
                SeatRow(seat: seat, colorScheme: colorScheme,
                        isLocal: seat.seatClaimID == gameNight.localSeatClaimID,
                        canRemove: gameNight.role == .host && gameNight.phase == .settingTable) {
                    gameNight.removeSeat(seatClaimID: seat.seatClaimID)
                }
            }
            .onMove { indices, destination in
                gameNight.moveSeat(fromOffsets: indices, toOffset: destination)
            }
            .moveDisabled(gameNight.role != .host || gameNight.phase != .settingTable)
        }
    }

    private var claimSection: some View {
        Section {
            if gameNight.localSeatClaimID == nil {
                Button {
                    showsSeatClaim = true
                } label: {
                    Label("Claim a seat", systemImage: "person.badge.plus")
                }
            }
            if gameNight.role == .host {
                Button {
                    GameNightSharing.present { showsInviteInstructions = true }
                } label: {
                    Label("Invite Players…", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var commentarySection: some View {
        Section {
            if gameNight.role == .host {
                Toggle("Commentary on", isOn: $gameNight.commentaryEnabled)
                    .onChange(of: gameNight.commentaryEnabled) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                    }
                if gameNight.commentaryEnabled {
                    let packName = CommentaryPersonality.find(id: gameNight.commentaryPackID).displayName
                    let levelName = CommentaryLevel(rawValue: gameNight.commentaryLevelRaw)?.displayName ?? "Celebrations"
                    Text("\(packName) · \(levelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                if gameNight.commentaryEnabled {
                    let packName = CommentaryPersonality.find(id: gameNight.commentaryPackID).displayName
                    let levelName = CommentaryLevel(rawValue: gameNight.commentaryLevelRaw)?.displayName ?? "Celebrations"
                    Label("\(packName) · \(levelName)", systemImage: "mic.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No commentary tonight")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Commentary")
        } footer: {
            if gameNight.role == .host {
                Text("On a FaceTime call? Keep the call on your iPad or Mac and play on your iPhone — everyone sees everyone.")
            }
        }
    }
}

// MARK: - Host start button (needs model context for gameID lookup)

private struct StartGameButton: View {
    @Bindable var gameNight: GameNightController
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button("Start") {
            guard let gameID = fetchYatzyGameID() else { return }
            gameNight.broadcastMatchStart(gameID: gameID)
        }
        .disabled(gameNight.seats.count < 2)
    }

    private func fetchYatzyGameID() -> UUID? {
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == "yatzy" }
        )
        return (try? modelContext.fetch(descriptor))?.first?.id
    }
}

// MARK: - Seat row

private struct SeatRow: View {
    let seat: SeatSnapshot
    let colorScheme: ColorScheme
    let isLocal: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            InitialsCircle(initials: seat.displayInitials, themeID: seat.displayThemeID, colorScheme: colorScheme)
            VStack(alignment: .leading, spacing: 2) {
                Text(seat.displayName)
                if isLocal {
                    Text("You")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Initials circle

struct InitialsCircle: View {
    let initials: String
    let themeID: String
    let colorScheme: ColorScheme

    @ScaledMetric private var circleSize: CGFloat = 32
    @ScaledMetric private var fontSize: CGFloat = 11

    var body: some View {
        let themeType = Theme.ThemeType(rawValue: themeID) ?? .midnight
        let accent = Theme(type: themeType, colorScheme: colorScheme).primaryAccent
        ZStack {
            Circle().fill(accent)
            Text(initials)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: circleSize, height: circleSize)
    }
}
