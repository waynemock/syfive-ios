import SwiftUI
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
    let appSettings: () -> Settings

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme

    init(
        gameNight: GameNightController,
        matchModel: MatchController,
        onClaimSeat: @escaping () -> Void,
        @ViewBuilder appSettings: @escaping () -> Settings
    ) {
        self.gameNight = gameNight
        self.matchModel = matchModel
        self.onClaimSeat = onClaimSeat
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
                Theme(
                    type: Theme.ThemeType(rawValue: seat.displayThemeID) ?? .midnight,
                    colorScheme: colorScheme
                ).primaryAccent
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
                    gameNight.leaveSession()
                }
            },
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
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
                    accentColor: Theme(
                        type: Theme.ThemeType(rawValue: pm.themeID) ?? .midnight,
                        colorScheme: colorScheme
                    ).primaryAccent
                )
            }
    }

    var body: some View {
        SeatClaimSheet(
            roster: availableRoster,
            accentColor: theme.primaryAccent,
            onClaim: { entry in
                gameNight.claimSeat(
                    displayName: entry.name,
                    displayInitials: entry.initials,
                    themeID: entry.themeID,
                    playerID: entry.id
                )
            },
            createPlayerSheet: { done in
                PlayerEditSheet(mode: .create, matchModel: matchModel, onCreated: { pm in
                    done(SeatRosterEntry(
                        id: pm.id,
                        name: pm.name,
                        initials: pm.initials,
                        themeID: pm.themeID,
                        accentColor: Theme(
                            type: Theme.ThemeType(rawValue: pm.themeID) ?? .midnight,
                            colorScheme: colorScheme
                        ).primaryAccent
                    ))
                })
            }
        )
    }
}
