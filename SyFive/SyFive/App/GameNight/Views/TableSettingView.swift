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
    @State private var showsGameNightHelp = false
    @State private var showsEndSessionConfirmation = false

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
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Leave") {
                        if gameNight.role == .host {
                            showsEndSessionConfirmation = true
                        } else if gameNight.phase == .settingTable {
                            // Pre-game: release the seat and close.
                            gameNight.leaveSession()
                            dismiss()
                        } else {
                            // Game in progress: just close — leaveSession() would nil
                            // out localParticipantID, silencing all outbound messages.
                            dismiss()
                        }
                    }
                    if gameNight.role == .host {
                        Button { showsGameNightHelp = true } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("Game Night Help")
                    }
                }
                if gameNight.role == .host && gameNight.phase == .settingTable {
                    ToolbarItem(placement: .topBarTrailing) {
                        StartGameButton(gameNight: gameNight)
                    }
                }
            }
            .alert("End Game Night for Everyone?", isPresented: $showsEndSessionConfirmation) {
                Button("End Game Night", role: .destructive) {
                    gameNight.endSession()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All players will be disconnected from this Game Night session.")
            }
            .sheet(isPresented: $showsSeatClaim) {
                SeatClaimSheet(gameNight: gameNight)
            }
            .sheet(isPresented: $showsGameNightHelp) {
                GameNightHelpSheet(
                    context: gameNight.role == .host ? .hosting : .joining,
                    isEligibleForGroupSession: true
                )
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
                let isOwnSeat = seat.seatClaimID == gameNight.localSeatClaimID
                SeatRow(seat: seat, colorScheme: colorScheme,
                        isLocal: isOwnSeat,
                        canRemove: gameNight.phase == .settingTable && (gameNight.role == .host || isOwnSeat),
                        canReorder: gameNight.role == .host && gameNight.phase == .settingTable) {
                    if gameNight.role == .host {
                        gameNight.removeSeat(seatClaimID: seat.seatClaimID)
                    } else {
                        gameNight.leaveSession()
                    }
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
                    Picker("Personality", selection: $gameNight.commentaryPackID) {
                        ForEach(CommentaryPersonality.all, id: \.id) { pack in
                            Text(pack.displayName).tag(pack.id)
                        }
                    }
                    .onChange(of: gameNight.commentaryPackID) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                    }
                    Picker("Level", selection: $gameNight.commentaryLevelRaw) {
                        ForEach(CommentaryLevel.allCases, id: \.rawValue) { level in
                            Text(level.displayName).tag(level.rawValue)
                        }
                    }
                    .onChange(of: gameNight.commentaryLevelRaw) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                    }
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
    let canReorder: Bool
    let onRemove: () -> Void

    @Environment(\.editMode) private var editMode

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

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
            if canReorder && !isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .font(.title3)
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
