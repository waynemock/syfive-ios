import Foundation
import GroupActivities

/// Session orchestrator for Game Night. Owns the SharePlay session, the
/// messenger, role assignment, and all inbound message routing.
///
/// Lifecycle rule: `startListeningForSessions()` is called once at app launch
/// (in SyFiveApp) and runs for the app's lifetime. Every other interaction goes
/// through this object's public API.
///
/// GroupActivities imports are confined to this file and GameNightActivity.swift.
/// Nothing below the App layer imports GroupActivities.
@MainActor
@Observable
final class GameNightController {

    // MARK: - Role

    enum Role {
        case host
        case guest
        case spectator  // joined after matchStart; no seat, read-only
    }

    // MARK: - Observable state

    private(set) var role: Role = .guest
    private(set) var phase: GameNightPhase = .settingTable
    private(set) var seats: [SeatSnapshot] = []
    private(set) var isSessionActive = false
    /// The seatClaimID for the local device's own seat, set on `claimSeat()`.
    private(set) var localSeatClaimID: UUID?
    /// The participantID assigned to our seat when `matchStart` locks the table.
    private(set) var localParticipantID: UUID?
    /// Set when a game-in-progress session ended unexpectedly (host killed or abandoned).
    /// Cleared by `clearSessionEndedFlag()` after the user dismisses the alert.
    private(set) var sessionEndedDuringPlay = false

    /// Session-scoped commentary override. Host writes; guests receive via tableState.
    /// Never persisted — the session ends and solo settings reassert immediately.
    var commentaryEnabled: Bool = false
    var commentaryPackID: String = "steady"
    var commentaryLevelRaw: String = "celebrations"

    // MARK: - Private session state

    private var session: GroupSession<GameNightActivity>?
    private var messenger: GroupSessionMessenger?
    private var messageListenTask: Task<Void, Never>?

    /// Participant IDs that sent a mismatched protocol version. Their subsequent
    /// seatClaim will be declined with calm copy (Phase 3).
    private var versionMismatchedIDs: Set<UUID> = []

    // MARK: - Game Night match state (Phase 4)

    /// The shared MatchController. Host uses it as the authoritative engine;
    /// guests read it (populated from matchState snapshots). Weakly held so
    /// ContentView owns the object's lifetime.
    private weak var matchController: MatchController?

    /// Stable identifiers for the running match — set in broadcastMatchStart.
    private(set) var sessionMatchID: UUID?
    private(set) var sessionGameID: UUID?

    // MARK: - Roll theater hooks (Phase 5)

    /// Fired on spectators when rollBegan arrives. DiceAreaView replays the recipe.
    var onRollBegan: ((DiceRollRecipe, [Bool]) -> Void)?
    /// Fired on spectators when rollResult arrives. DiceAreaView applies any correction.
    var onRollResult: (([Int]) -> Void)?
    /// Fired on spectators when holdToggled arrives. DiceAreaView mirrors held state.
    var onHoldToggled: ((Int, Bool) -> Void)?
    /// Authoritative face values from rollResult, held while spectator replay is still running.
    var pendingAuthoritativeResult: [Int]? = nil

    // MARK: - Completion hook (Phase 6)

    /// Fired on guests when matchComplete arrives. ContentView wires this to the upsert write.
    var onMatchComplete: ((Match) -> Void)?

    private let logger = AppLogger(category: "GameNightController")

    // MARK: - App-launch entry point

    /// Begin watching for incoming GroupSession objects. Call once from SyFiveApp
    /// and let it run for the app's lifetime.
    func startListeningForSessions() {
        Task { [weak self] in
            for await incomingSession in GameNightActivity.sessions() {
                await MainActor.run {
                    self?.configureSession(incomingSession)
                }
            }
        }
    }

    // MARK: - Host entry point

    /// Called when the host taps "Start Game Night". Sets role = .host before
    /// activate() so configureSession knows which role to take.
    /// Phase 3 will wrap this in a GroupActivitySharingController for the
    /// call-absent path (door 3 / invite link).
    func startAsHost() async throws {
        role = .host
        _ = try await GameNightActivity().activate()
    }

    // MARK: - Session configuration (both host and guest)

    /// Wires up the messenger and starts listening. Called for every incoming
    /// session — the host's own session arrives here too.
    func configureSession(_ incomingSession: GroupSession<GameNightActivity>) {
        // Guard against reconfiguring with the same session.
        if session?.id == incomingSession.id { return }

        // Tear down any prior session cleanly.
        tearDownSession()
        sessionEndedDuringPlay = false

        session = incomingSession
        let m = GroupSessionMessenger(session: incomingSession)
        messenger = m
        incomingSession.join()
        isSessionActive = true

        messageListenTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForMessages(messenger: m)
        }

        if role == .host {
            // Push current table state so any early joiners catch up.
            Task { await self.broadcastTableState() }
        } else {
            // Announce ourselves so the host can version-check and send tableState.
            Task { await self.sendHello() }
        }
    }

    // MARK: - Session teardown

    func endSession() {
        tearDownSession()
    }

    /// Host-only: reset to the table-setting phase with existing seats so players
    /// can start a new match without re-claiming. Guests see the seating sheet again
    /// via their `onChange(of: phase)` handler.
    func playAgain() {
        guard role == .host, phase == .completed, !seats.isEmpty else { return }
        phase = .settingTable
        Task { await broadcastTableState() }
    }

    /// Host-only: broadcast `matchAbandoned` to guests, then tear down locally.
    func abandonSession() {
        guard role == .host, isSessionActive else { return }
        send(.matchAbandoned, payload: MatchAbandonedPayload())
        tearDownSession()
    }

    /// Clear the session-ended flag after the UI has acknowledged it.
    func clearSessionEndedFlag() {
        sessionEndedDuringPlay = false
    }

    private func tearDownSession() {
        messageListenTask?.cancel()
        messageListenTask = nil
        session?.end()
        session = nil
        messenger = nil
        isSessionActive = false
        seats = []
        phase = .settingTable
        versionMismatchedIDs = []
        localSeatClaimID = nil
        localParticipantID = nil
        onRollBegan = nil
        onRollResult = nil
        onHoldToggled = nil
        pendingAuthoritativeResult = nil
        onMatchComplete = nil
        detachMatchController()
    }

    // MARK: - Game Night match wiring (Phase 4)

    /// Wire the shared MatchController for the duration of the session.
    /// Call from ContentView when isSessionActive becomes true.
    func attach(matchController: MatchController) {
        self.matchController = matchController
        matchController.onScoreApplied = { [weak self, weak matchController] category, dice in
            guard let self, let mc = matchController, self.phase == .inProgress else { return }
            if self.role == .host {
                Task {
                    await self.broadcastMatchState()
                    if mc.isGameOver {
                        await self.broadcastMatchComplete()
                    }
                }
            } else {
                self.proposeScore(category: category, diceValues: dice)
            }
        }
        matchController.onUndone = { [weak self] in
            guard let self, self.phase == .inProgress else { return }
            if self.role == .host {
                Task { await self.broadcastMatchState() }
            } else {
                self.proposeUndo()
            }
        }
    }

    private func detachMatchController() {
        matchController?.onScoreApplied = nil
        matchController?.onUndone = nil
        matchController = nil
        sessionMatchID = nil
        sessionGameID = nil
    }

    /// Builds and broadcasts a full match snapshot to all players. Host-only.
    func broadcastMatchState() async {
        guard role == .host,
              phase == .inProgress,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        send(.matchState, payload: MatchStatePayload(match: match, currentSeatIndex: mc.currentPlayerIndex))
    }

    /// Broadcasts the final match to all guests; sets phase to .completed. Host-only.
    func broadcastMatchComplete() async {
        guard role == .host,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        phase = .completed
        send(.matchComplete, payload: MatchCompletePayload(match: match))
        Task { await broadcastTableState() }
    }

    /// Guest: send a scoring proposal to the host.
    func proposeScore(category: YatzyCategory, diceValues: [Int]) {
        guard role != .host, phase == .inProgress,
              let participantID = localParticipantID else { return }
        send(.scoreChosen, payload: ScoreChosenPayload(
            participantID: participantID, category: category, diceValues: diceValues))
    }

    /// Guest: send an undo request to the host.
    func proposeUndo() {
        guard role != .host, phase == .inProgress,
              let participantID = localParticipantID else { return }
        send(.undoRequest, payload: UndoRequestPayload(participantID: participantID))
    }

    // MARK: - Outbound messages (Phase 5 — roll theater)

    func sendRollBegan(recipe: DiceRollRecipe, rollIndex: Int, heldMask: [Bool]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = localParticipantID else { return }
        send(.rollBegan, payload: RollBeganPayload(
            participantID: participantID, rollIndex: rollIndex,
            recipe: recipe, heldMask: heldMask))
    }

    func sendRollResult(faceValues: [Int]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = localParticipantID else { return }
        send(.rollResult, payload: RollResultPayload(
            participantID: participantID, faceValues: faceValues))
    }

    func sendHoldToggled(dieIndex: Int, isHeld: Bool) {
        guard isSessionActive, phase == .inProgress,
              let participantID = localParticipantID else { return }
        send(.holdToggled, payload: HoldToggledPayload(
            participantID: participantID, dieIndex: dieIndex, isHeld: isHeld))
    }

    // MARK: - Outbound messages (host)

    func broadcastTableState() async {
        guard role == .host else { return }
        send(.tableState, payload: TableStatePayload(
            phase: phase,
            seats: seats,
            commentaryEnabled: commentaryEnabled,
            commentaryPackID: commentaryPackID,
            commentaryLevelRaw: commentaryLevelRaw
        ))
    }

    // MARK: - Private: inbound message loop

    private func listenForMessages(messenger: GroupSessionMessenger) async {
        for await (envelope, context) in messenger.messages(of: GameNightEnvelope.self) {
            handle(envelope, from: context.source.id)
        }
        // Loop exits when the session is invalidated. If we didn't cancel this task
        // (i.e. the session dropped rather than the user leaving), show the reconnect alert.
        guard !Task.isCancelled, isSessionActive else { return }
        let wasInProgress = phase == .inProgress
        tearDownSession()
        if wasInProgress { sessionEndedDuringPlay = true }
    }

    // MARK: - Message routing

    private func handle(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard let kind = envelope.messageKind else { return }   // unknown kind → drop
        switch kind {
        case .hello:          handleHello(envelope, from: senderID)
        case .tableState:     handleTableState(envelope)
        case .seatClaim:      handleSeatClaim(envelope, from: senderID)       // Phase 3
        case .matchStart:     handleMatchStart(envelope)                        // Phase 3
        case .rollBegan:      handleRollBegan(envelope)                         // Phase 5
        case .rollResult:     handleRollResult(envelope)                        // Phase 5
        case .holdToggled:    handleHoldToggled(envelope)                       // Phase 5
        case .scoreChosen:    handleScoreChosen(envelope, from: senderID)      // Phase 4
        case .undoRequest:    handleUndoRequest(envelope, from: senderID)      // Phase 4
        case .matchState:     handleMatchState(envelope)                        // Phase 4
        case .matchComplete:  handleMatchComplete(envelope)                     // Phase 7
        case .matchAbandoned: handleMatchAbandoned()                            // Phase 8
        }
    }

    // MARK: - Handlers (Phase 2: hello + tableState live; rest are stubs)

    private func handleHello(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard let payload = try? envelope.decode(HelloPayload.self) else { return }
        guard payload.protocolVersion == GameNightEnvelope.currentProtocolVersion else {
            logger.info(self, "Version mismatch from \(senderID): v\(payload.protocolVersion)")
            versionMismatchedIDs.insert(senderID)
            return
        }
        // Compatible joiner — push current tableState for catch-up.
        if role == .host {
            Task { await self.broadcastTableState() }
        }
    }

    private func handleTableState(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let payload = try? envelope.decode(TableStatePayload.self) else { return }
        phase = payload.phase
        seats = payload.seats
        commentaryEnabled = payload.commentaryEnabled
        commentaryPackID = payload.commentaryPackID
        commentaryLevelRaw = payload.commentaryLevelRaw
        logger.debug(self, "tableState received: \(seats.count) seats, phase=\(payload.phase.rawValue)")
    }

    private func handleSeatClaim(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host, phase == .settingTable else { return }
        guard !versionMismatchedIDs.contains(senderID) else {
            logger.info(self, "Declining seatClaim from version-mismatched sender \(senderID)")
            return
        }
        guard let payload = try? envelope.decode(SeatClaimPayload.self) else { return }
        addSeat(from: payload)
        Task { await self.broadcastTableState() }
    }

    private func handleMatchStart(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let payload = try? envelope.decode(MatchStartPayload.self) else { return }
        phase = .inProgress
        if let myClaimID = localSeatClaimID,
           let mapping = payload.seatMappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        sessionMatchID = payload.match.id
        sessionGameID = payload.match.gameID
        matchController?.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        logger.debug(self, "matchStart: \(payload.match.participants.count) seats, seat \(payload.currentSeatIndex)")
    }

    private func handleScoreChosen(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host,
              phase == .inProgress,
              let mc = matchController,
              let payload = try? envelope.decode(ScoreChosenPayload.self) else { return }
        mc.applyRemoteScore(
            category: payload.category,
            remoteValues: payload.diceValues,
            forParticipantID: payload.participantID
        )
        // onScoreApplied hook (wired in attach()) broadcasts matchState automatically.
    }

    private func handleUndoRequest(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host,
              phase == .inProgress,
              let mc = matchController,
              let payload = try? envelope.decode(UndoRequestPayload.self) else { return }
        guard let index = mc.participantIDs.firstIndex(of: payload.participantID),
              mc.undoPlayerIndex == index else { return }
        mc.undoLastScore()
        // onUndone hook broadcasts matchState automatically.
    }

    private func handleMatchState(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let mc = matchController,
              let payload = try? envelope.decode(MatchStatePayload.self) else { return }
        mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        logger.debug(self, "matchState: seat \(payload.currentSeatIndex)")
    }

    private func handleRollBegan(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollBeganPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        pendingAuthoritativeResult = nil
        onRollBegan?(payload.recipe, payload.heldMask)
    }

    private func handleRollResult(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollResultPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        pendingAuthoritativeResult = payload.faceValues
        onRollResult?(payload.faceValues)
    }

    private func handleHoldToggled(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HoldToggledPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        onHoldToggled?(payload.dieIndex, payload.isHeld)
    }
    private func handleMatchComplete(_ envelope: GameNightEnvelope) {
        guard role != .host,
              phase == .inProgress,
              let payload = try? envelope.decode(MatchCompletePayload.self) else { return }
        phase = .completed
        onMatchComplete?(payload.match)
        logger.debug(self, "matchComplete: \(payload.match.id)")
    }

    private func handleMatchAbandoned() {
        guard phase == .inProgress || phase == .settingTable else { return }
        let wasInProgress = phase == .inProgress
        tearDownSession()
        if wasInProgress { sessionEndedDuringPlay = true }
    }

    // MARK: - Send helper

    private func send<P: Encodable>(_ kind: GameNightMessageKind, payload: P) {
        guard let messenger else { return }
        do {
            let envelope = try GameNightEnvelope(kind: kind, payload: payload)
            Task {
                try? await messenger.send(envelope)
            }
        } catch {
            logger.error(self, "Encode failed (\(kind.rawValue)): \(error)")
        }
    }

    private func sendHello() async {
        send(.hello, payload: HelloPayload(
            protocolVersion: GameNightEnvelope.currentProtocolVersion,
            appVersion: Bundle.main.appVersionShort
        ))
    }

    // MARK: - Seating (Phase 3)

    /// Claim one seat for the local player. Host processes locally and rebroadcasts
    /// tableState; guest sends a `seatClaim` message to the host.
    func claimSeat(displayName: String, displayInitials: String, themeID: String, playerID: UUID?, isLocal: Bool = false) {
        let claimID = UUID()
        localSeatClaimID = claimID
        let payload = SeatClaimPayload(
            seatClaimID: claimID,
            playerID: playerID,
            displayName: displayName,
            displayInitials: displayInitials,
            displayThemeID: themeID,
            isLocal: isLocal
        )
        if role == .host {
            addSeat(from: payload)
            Task { await self.broadcastTableState() }
        } else {
            send(.seatClaim, payload: payload)
        }
    }

    /// Host-only: reorder seats after a drag-and-drop in the table-setting UI.
    func moveSeat(fromOffsets: IndexSet, toOffset: Int) {
        guard role == .host, phase == .settingTable else { return }
        var reordered = seats
        let items = fromOffsets.sorted(by: >).map { reordered[$0] }
        for offset in fromOffsets.sorted(by: >) { reordered.remove(at: offset) }
        let insertAt = min(toOffset - fromOffsets.filter { $0 < toOffset }.count, reordered.count)
        reordered.insert(contentsOf: items.reversed(), at: insertAt)
        seats = reordered
        for i in seats.indices { seats[i].seat = i }
        Task { await self.broadcastTableState() }
    }

    /// Host-only: remove a seat by its stable claim identity.
    func removeSeat(seatClaimID: UUID) {
        guard role == .host, phase == .settingTable else { return }
        if localSeatClaimID == seatClaimID { localSeatClaimID = nil }
        seats.removeAll { $0.seatClaimID == seatClaimID }
        for i in seats.indices { seats[i].seat = i }
        Task { await self.broadcastTableState() }
    }

    /// Host-only: lock the table and broadcast `matchStart` to begin (or resume) the game.
    func broadcastMatchStart(gameID: UUID) {
        guard role == .host, phase == .settingTable, seats.count >= 2 else { return }
        let match: Match
        let mappings: [SeatMapping]
        let currentSeatIndex: Int
        if let mc = matchController, let matchID = mc.persistedMatchID, mc.playerCount >= 2 {
            // Resume path: host was killed mid-match; same players re-seated.
            // Rebuild the snapshot and remap seatClaimIDs → existing participantIDs by playerID.
            let snapshot = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
            currentSeatIndex = mc.currentPlayerIndex
            var newMappings: [SeatMapping] = []
            for seat in seats {
                let existing = snapshot.participants.first { p in
                    seat.playerID != nil && p.playerID == seat.playerID
                }
                newMappings.append(SeatMapping(
                    seatClaimID: seat.seatClaimID,
                    participantID: existing?.id ?? UUID()
                ))
            }
            match = snapshot
            mappings = newMappings
        } else {
            (match, mappings) = buildInitialMatch(gameID: gameID)
            currentSeatIndex = 0
        }
        phase = .inProgress
        sessionMatchID = match.id
        sessionGameID = gameID
        if let myClaimID = localSeatClaimID,
           let mapping = mappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        matchController?.loadFromGameNightMatch(match, currentSeatIndex: currentSeatIndex)
        send(.matchStart, payload: MatchStartPayload(match: match, seatMappings: mappings, currentSeatIndex: currentSeatIndex))
        Task { await self.broadcastTableState() }
    }

    private func addSeat(from payload: SeatClaimPayload) {
        guard !seats.contains(where: { $0.seatClaimID == payload.seatClaimID }) else { return }
        let snapshot = SeatSnapshot(
            seatClaimID: payload.seatClaimID,
            seat: seats.count,
            playerID: payload.playerID,
            displayName: payload.displayName,
            displayInitials: payload.displayInitials,
            displayThemeID: payload.displayThemeID,
            isLocal: payload.isLocal
        )
        seats.append(snapshot)
    }

    private func buildInitialMatch(gameID: UUID) -> (Match, [SeatMapping]) {
        var mappings: [SeatMapping] = []
        let participants: [Participant] = seats.enumerated().map { index, seat in
            let participantID = UUID()
            mappings.append(SeatMapping(seatClaimID: seat.seatClaimID, participantID: participantID))
            return Participant(
                id: participantID,
                seat: index,
                finalScore: 0,
                rank: 0,
                yahtzeeBonus: 0,
                playerID: seat.playerID,
                teamID: nil,
                displayName: seat.displayName,
                displayInitials: seat.displayInitials,
                displayThemeID: seat.displayThemeID,
                scoreEntries: []
            )
        }
        let match = Match(
            id: UUID(),
            gameID: gameID,
            scoringSystemID: "yatzy",
            scoringSystemVersion: 1,
            status: .inProgress,
            startedAt: Date(),
            completedAt: nil,
            participants: participants
        )
        return (match, mappings)
    }
}
