import SwiftUI
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SwiftData

/// The pre-game seating screen shown to all players during the `settingTable` phase.
/// Host sees reorder/remove controls and a Start button; guests see a seat-claim button.
/// Commentary override row is editable by the host and read-only for guests.
struct TableSettingView: View {
    @Bindable var gameNight: GameNightController
    let matchModel: MatchController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showsSeatClaim = false
    @State private var showsGameNightHelp = false
    @State private var showsEndSessionConfirmation = false

    var body: some View {
        NavigationStack {
            SyFiveGameNightTableView(
                gameNight: gameNight,
                matchModel: matchModel,
                onClaimSeat: { showsSeatClaim = true },
                appSettings: { commentarySection }
            )
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
                SyFiveSeatClaimSheet(gameNight: gameNight, matchModel: matchModel)
            }
            .sheet(isPresented: $showsGameNightHelp) {
                GameNightHelpSheet(
                    context: gameNight.role == .host ? .hosting : .joining,
                    isEligibleForGroupSession: true,
                    appName: "SyFive",
                    accentColor: theme.primaryAccent
                )
            }
        }
    }

    // MARK: - Commentary section (SyFive-specific, passed into the table view)

    private var commentarySection: some View {
        Section {
            if gameNight.role == .host {
                Toggle("Commentary on", isOn: $gameNight.commentaryEnabled)
                    .onChange(of: gameNight.commentaryEnabled) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                        gameNight.onCommentarySettingsChanged?()
                    }
                if gameNight.commentaryEnabled {
                    Picker("Personality", selection: $gameNight.commentaryPackID) {
                        ForEach(CommentaryPersonality.all, id: \.id) { pack in
                            Text(pack.displayName).tag(pack.id)
                        }
                    }
                    .onChange(of: gameNight.commentaryPackID) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                        gameNight.onCommentarySettingsChanged?()
                    }
                    Picker("Level", selection: $gameNight.commentaryLevelRaw) {
                        ForEach(CommentaryLevel.allCases, id: \.rawValue) { level in
                            Text(level.displayName).tag(level.rawValue)
                        }
                    }
                    .onChange(of: gameNight.commentaryLevelRaw) { _, _ in
                        Task { await gameNight.broadcastTableState() }
                        gameNight.onCommentarySettingsChanged?()
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
                .foregroundStyle(theme.primaryAccent)
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
        let yatzyID = ScoringSystemID.yatzy.rawValue
        let descriptor = FetchDescriptor<GameModel>(
            predicate: #Predicate { $0.scoringSystemID == yatzyID }
        )
        return (try? modelContext.fetch(descriptor))?.first?.id
    }
}
