import SwiftUI
import SyLibUI
import SwiftData
import SyLibGameNight
import SyLibScoring
import SyLibScoringData

// MARK: - Seat edit button (pencil affordance inside SeatRowView slot)

/// Pencil button that appears on the local player's own seat row during table-setting.
/// Owns PlayerEditSheet presentation and updateOwnSeat wiring, keeping SwiftData
/// and MatchController out of the SyLibGameNight package.
private struct SeatEditButton: View {
    let seat: SeatSnapshot
    let matchModel: MatchController
    let gameNight: GameNightController

    @Environment(\.modelContext) private var modelContext
    @Environment(\.syTheme) private var theme
    @State private var showsPlayerEdit: PlayerEditSheet.Mode? = nil

    private var isVisible: Bool {
        seat.seatClaimID == gameNight.session.localSeatClaimID && gameNight.phase == .settingTable
    }

    var body: some View {
        Group {
            if isVisible {
                Button {
                    showsPlayerEdit = fetchPlayerEditMode()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $showsPlayerEdit) { mode in
            PlayerEditSheet(mode: mode, matchModel: matchModel, onSave: {
                if case .edit(let pm, _) = mode {
                    gameNight.updateOwnSeat(name: pm.name, initials: pm.initials, themeID: pm.themeID)
                }
            })
            .environment(\.syTheme, theme)
            .sheetTextSizeCeiling()
        }
    }

    private func fetchPlayerEditMode() -> PlayerEditSheet.Mode? {
        guard let playerID = seat.playerID else { return nil }
        var desc = FetchDescriptor<PlayerModel>(predicate: #Predicate { $0.id == playerID })
        desc.fetchLimit = 1
        guard let pm = (try? modelContext.fetch(desc))?.first else { return nil }
        return .edit(pm, matchSlot: nil)
    }
}

// MARK: - Table view wrapper

/// Wires SyFive-specific values (Theme colour resolution, app name, protocol versions)
/// into the package's GameNightTableView.
struct SyFiveGameNightTableView<Settings: View>: View {
    let gameNight: GameNightController
    let matchModel: MatchController
    let onClaimSeat: () -> Void
    /// Change on this device's own seat (37 §2.3); nil shows no Change.
    let onChangeSeat: (() -> Void)?
    let appSettings: () -> Settings

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.syTheme) private var theme

    init(
        gameNight: GameNightController,
        matchModel: MatchController,
        onClaimSeat: @escaping () -> Void,
        onChangeSeat: (() -> Void)? = nil,
        @ViewBuilder appSettings: @escaping () -> Settings
    ) {
        self.gameNight = gameNight
        self.matchModel = matchModel
        self.onClaimSeat = onClaimSeat
        self.onChangeSeat = onChangeSeat
        self.appSettings = appSettings
    }

    var body: some View {
        GameNightTableView(
            seats: gameNight.seats,
            localSeatClaimID: gameNight.session.localSeatClaimID,
            phase: gameNight.phase,
            role: gameNight.role,
            appName: "SyFive",
            accentColor: theme.primaryAccent,
            seatColor: { seat in
                SyTheme.accent(forThemeID: seat.displayThemeID, colorScheme: colorScheme)
            },
            versionMismatchCount: gameNight.session.versionMismatchedCount,
            lastMismatchedVersion: gameNight.session.lastMismatchedVersion,
            lastMismatchKind: gameNight.session.lastMismatchKind,
            currentTransportVersion: GameNightEnvelope.currentProtocolVersion,
            currentAppVersion: GameNightMessageKind.appProtocolVersion,
            onClaimSeat: onClaimSeat,
            onMoveSeat: { indices, destination in
                gameNight.moveSeat(fromOffsets: indices, toOffset: destination)
            },
            onRemoveSeat: { seat in
                if gameNight.role == .host {
                    gameNight.removeSeat(seatClaimID: seat.seatClaimID)
                } else {
                    // Removing one's own seat forgets the remembered player; Leave doesn't (37 §2.1).
                    gameNight.session.forgetRememberedSeat()
                    gameNight.leaveSession()
                }
            },
            onChangeSeat: onChangeSeat,
            appSettings: appSettings,
            seatTrailing: { seat in
                SeatEditButton(seat: seat, matchModel: matchModel, gameNight: gameNight)
            }
        )
    }
}

// MARK: - Seat claim sheet

/// SyFive-specific wrapper that supplies SwiftData player roster to the package's SeatClaimSheet.
struct SyFiveSeatClaimSheet: View {
    let gameNight: GameNightController
    let matchModel: MatchController
    /// Change mode (37 §2.3): the chosen or created player replaces this device's own seat's,
    /// through `changeLocalSeat(to:)`, instead of claiming a new seat.
    var changesSeat = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.syTheme) private var theme
    @Query(sort: \PlayerModel.name) private var players: [PlayerModel]

    private var availableRoster: [SeatRosterEntry] {
        let seatedIDs = Set(gameNight.seats.compactMap(\.playerID))
        return players
            .filter { !$0.isArchived && !seatedIDs.contains($0.id) }
            .map { pm in
                SeatRosterEntry(
                    id: pm.id,
                    name: pm.name,
                    initials: pm.initials,
                    themeID: pm.themeID,
                    accentColor: SyTheme.accent(forThemeID: pm.themeID, colorScheme: colorScheme)
                )
            }
    }

    var body: some View {
        SeatClaimSheet(
            roster: availableRoster,
            accentColor: theme.primaryAccent,
            onClaim: { entry in
                // Also called with New Player's created entry, so change mode covers both.
                if changesSeat {
                    gameNight.session.changeLocalSeat(to: entry)
                } else {
                    gameNight.claimSeat(
                        displayName: entry.name,
                        displayInitials: entry.initials,
                        themeID: entry.themeID,
                        playerID: entry.id
                    )
                }
            },
            createPlayerSheet: { done in
                PlayerEditSheet(mode: .create, matchModel: matchModel, onCreated: { pm in
                    done(SeatRosterEntry(
                        id: pm.id,
                        name: pm.name,
                        initials: pm.initials,
                        themeID: pm.themeID,
                        accentColor: SyTheme.accent(forThemeID: pm.themeID, colorScheme: colorScheme)
                    ))
                })
                .environment(\.syTheme, theme)
            }
        )
    }
}
