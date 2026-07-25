import Combine
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
    /// Incremented every time configureSession() fully completes. Because tearDownSession()
    /// can flip isSessionActive false→true within the same SwiftUI render cycle (net: no change),
    /// keying the seating-sheet trigger off this counter guarantees onChange always fires.
    private(set) var sessionActivationCount: Int = 0
    /// True after prepareAsHost() until the session arrives or the invite is cancelled.
    /// Used to block a second invite attempt and show a "waiting" state in the menu.
    private(set) var isSessionPending = false
    /// Mirrors GroupStateObserver.isEligibleForGroupSession. True when the device is
    /// in a FaceTime call or iMessage thread that supports SharePlay.
    private(set) var isEligibleForGroupSession = false
    /// The seatClaimID for the local device's own seat, set on `claimSeat()`.
    private(set) var localSeatClaimID: UUID?
    /// The participantID assigned to our seat when `matchStart` locks the table.
    private(set) var localParticipantID: UUID?
    /// Set when a game-in-progress session ended unexpectedly (host killed or abandoned).
    /// Cleared by `clearSessionEndedFlag()` after the user dismisses the alert.
    private(set) var sessionEndedDuringPlay = false
    /// True on a guest device after loading a game night match at relaunch, until the
    /// host's session arrives. Blocks rolling so the guest can't act as the wrong player.
    private(set) var isGuestAwaitingReconnect = false
    /// True when the host has chosen to roll and score on behalf of a dropped player (D-121).
    /// Cleared automatically when the proxied turn is scored.
    private(set) var isProxyMode = false

    /// Session-scoped commentary override. Host writes; guests receive via tableState.
    /// Never persisted — the session ends and solo settings reassert immediately.
    var commentaryEnabled: Bool = false
    var commentaryPackID: String = CommentaryPersonality.steady.id
    var commentaryLevelRaw: String = CommentaryLevel.celebrations.rawValue

    // MARK: - Private session state

    private var session: GroupSession<GameNightActivity>?
    private var messenger: GroupSessionMessenger?
    private var messageListenTask: Task<Void, Never>?
    /// True between calling activate() and the resulting session arriving in configureSession.
    /// Used to distinguish "I started this session" from "another device started it" so role
    /// is resolved correctly when both devices restart and both tap Start.
    private var pendingHostSessionActivation = false

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
    /// Fired on the undone player's device after undo — DiceAreaView restores 3D dice.
    var onUndoWithDice: (([Int]) -> Void)?
    /// True on the guest device between scoring and the start of the next player's roll.
    /// Keeps the undo button visible after the host's echo matchState clears the local snapshot.
    private(set) var pendingGuestUndoAvailable: Bool = false
    /// True on the host device after any score is applied and until the next roll begins.
    /// Drives the undo button via gameNight observation (model.canUndoLastScore alone
    /// doesn't reliably trigger a re-render on the host after a remote score is applied).
    private(set) var pendingHostUndoAvailable: Bool = false

    // MARK: - Completion hook (Phase 6)

    /// Fired on guests when matchComplete arrives. ContentView wires this to the upsert write.
    var onMatchComplete: ((Match) -> Void)?

    private let groupStateObserver = GroupStateObserver()

    private let logger = AppLogger(category: "GameNightController")

    // MARK: - App-launch entry point

    /// Called by SyFiveApp via `.task` on the root ContentView. Running the for-await
    /// loop inside a structured `.task` ties it to the scene lifecycle, which lets iOS
    /// route Messages-based SharePlay sessions back to the sender's device. An unstructured
    /// Task {} in onAppear is not associated with any scene and silently drops those deliveries.
    func listenForSessions() async {
        logger.info(self, "listenForSessions: scene-level task started, awaiting sessions")
        // Mirror GroupStateObserver eligibility into our @Observable property so
        // views can drive UI without importing GroupActivities themselves.
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isEligibleForGroupSession = self.groupStateObserver.isEligibleForGroupSession
            for await _ in self.groupStateObserver.objectWillChange.values {
                self.isEligibleForGroupSession = self.groupStateObserver.isEligibleForGroupSession
            }
        }
        for await incomingSession in GameNightActivity.sessions() {
            logger.info(self, "listenForSessions: *** SESSION ARRIVED *** id=\(incomingSession.id) state=\(String(describing: incomingSession.state))")
            configureSession(incomingSession)
        }
        logger.warning(self, "listenForSessions: *** STREAM ENDED *** for-await loop exited, no more sessions will arrive")
    }

    // MARK: - Host entry point

    /// Called before presenting the invite UI. Sets the host role so configureSession
    /// knows to take host when the session arrives. Does NOT call activate() — the
    /// GroupActivitySharingController handles activation after the user picks contacts.
    func prepareAsHost() {
        logger.info(self, "prepareAsHost: isSessionActive=\(isSessionActive) isSessionPending=\(isSessionPending)")
        guard !isSessionActive && !isSessionPending else {
            logger.warning(self, "prepareAsHost: guard failed — already active or pending, ignoring")
            return
        }
        role = .host
        pendingHostSessionActivation = true
        isSessionPending = true
        logger.info(self, "prepareAsHost: pendingHostSessionActivation=true isSessionPending=true")
    }

    /// Reverts prepareAsHost() if the user cancelled before a session was established.
    func cancelHostPreparation() {
        logger.info(self, "cancelHostPreparation: isSessionActive=\(isSessionActive)")
        guard !isSessionActive else {
            logger.warning(self, "cancelHostPreparation: guard failed — session already active")
            return
        }
        role = .guest
        pendingHostSessionActivation = false
        isSessionPending = false
    }

    // MARK: - Session configuration (both host and guest)

    /// Wires up the messenger and starts listening. Called for every incoming
    /// session — the host's own session arrives here too.
    func configureSession(_ incomingSession: GroupSession<GameNightActivity>) {
        logger.info(self, "configureSession: entry id=\(incomingSession.id) state=\(String(describing: incomingSession.state)) pendingHostActivation=\(pendingHostSessionActivation) existingSessionID=\(session?.id.uuidString ?? "nil")")

        // Guard against reconfiguring with the same session.
        if session?.id == incomingSession.id {
            logger.warning(self, "configureSession: duplicate session id, skipping")
            return
        }

        // Resolve role from activation intent OR a persisted host flag for this session.
        // The session ID is stable across app relaunches (it's a system-level GroupActivities
        // object tied to the FaceTime call), so persisting against it lets the host device
        // recover its role automatically on relaunch without any user interaction.
        let persistedAsHost = UserDefaults.standard.gnIsHost(for: incomingSession.id)
        let takingHostRole = pendingHostSessionActivation || persistedAsHost
        pendingHostSessionActivation = false
        if takingHostRole {
            UserDefaults.standard.setGnIsHost(for: incomingSession.id)
        }

        logger.info(self, "configureSession: takingHostRole=\(takingHostRole), calling tearDownSession")
        // Tear down any prior session cleanly.
        tearDownSession()
        sessionEndedDuringPlay = false
        role = takingHostRole ? .host : .guest

        session = incomingSession
        let m = GroupSessionMessenger(session: incomingSession)
        messenger = m
        incomingSession.join()
        isSessionActive = true
        isSessionPending = false

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
        isGuestAwaitingReconnect = false
        sessionActivationCount += 1
        logger.info(self, "configureSession: *** COMPLETE *** role=\(String(describing: role)) activationCount=\(sessionActivationCount)")
    }

    // MARK: - Session teardown

    /// Ends the session for ALL participants. Host-only path — guests should call `leaveSession()`.
    func endSession() {
        tearDownSession()
    }

    /// Guest-only: releases this device's seat without ending the session for others.
    /// The GroupActivities session stays active so the guest can reopen the Game Night
    /// sheet from the nav bar and reclaim a seat before the host starts the game.
    func leaveSession() {
        if let claimID = localSeatClaimID {
            send(.seatRelease, payload: SeatReleasePayload(seatClaimID: claimID))
        }
        localSeatClaimID = nil
        localParticipantID = nil
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

    /// Called when a guest device loads a game night match at relaunch. Restores
    /// the persisted participant ID so the UI can identify the local player before
    /// the session arrives, and blocks rolling until the host reconnects.
    func prepareForGuestReconnect(matchID: UUID) {
        isGuestAwaitingReconnect = true
        if localParticipantID == nil {
            localParticipantID = UserDefaults.standard.gnParticipantID(for: matchID)
        }
    }

    private func tearDownSession() {
        pendingHostSessionActivation = false
        isSessionPending = false
        messageListenTask?.cancel()
        messageListenTask = nil
        // Clear the persisted host flag so a future relaunch doesn't auto-promote
        // a stale device. Captured before the session reference is cleared.
        if let id = session?.id {
            UserDefaults.standard.removeGnIsHost(for: id)
        }
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
        onUndoWithDice = nil
        onMatchComplete = nil
        pendingGuestUndoAvailable = false
        pendingHostUndoAvailable = false
        isGuestAwaitingReconnect = false
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
                self.isProxyMode = false
                self.pendingHostUndoAvailable = true
                Task {
                    await self.broadcastMatchState()
                    if mc.isGameOver {
                        await self.broadcastMatchComplete()
                    }
                }
            } else {
                self.pendingGuestUndoAvailable = true
                self.proposeScore(category: category, diceValues: dice)
            }
        }
        matchController.onUndone = { [weak self, weak matchController] in
            guard let self, self.phase == .inProgress else { return }
            if self.role == .host {
                self.pendingHostUndoAvailable = false
                let dv = matchController?.diceValues ?? []
                Task { await self.broadcastMatchUndo(diceValues: dv) }
            } else {
                self.proposeUndo()
            }
        }
        matchController.onRollStarted = { [weak self] in
            self?.pendingHostUndoAvailable = false
        }
    }

    private func detachMatchController() {
        matchController?.onScoreApplied = nil
        matchController?.onUndone = nil
        matchController?.onRollStarted = nil
        matchController = nil
        pendingHostUndoAvailable = false
        isProxyMode = false
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

    /// Broadcasts a matchState that includes the pre-scoring dice values so the
    /// undone player can rescore without re-rolling. `rollsRemaining` is always
    /// sent as 0 — the guest already used their rolls before scoring.
    func broadcastMatchUndo(diceValues: [Int]) async {
        guard role == .host,
              phase == .inProgress,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        send(.matchState, payload: MatchStatePayload(
            match: match,
            currentSeatIndex: mc.currentPlayerIndex,
            diceValues: diceValues,
            rollsRemaining: 0
        ))
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

    /// Guest: send an undo request to the host for the last scorer's entry.
    func proposeUndo() {
        guard role != .host, phase == .inProgress,
              let mc = matchController,
              let undoIndex = mc.undoPlayerIndex,
              undoIndex < mc.participantIDs.count else { return }
        pendingGuestUndoAvailable = false
        let participantID = mc.participantIDs[undoIndex]
        send(.undoRequest, payload: UndoRequestPayload(participantID: participantID))
    }

    // MARK: - Proxy mode (D-121)

    /// Lets the host roll and score on behalf of a dropped player for the current turn.
    func enableProxyMode() {
        guard role == .host else { return }
        isProxyMode = true
    }

    func disableProxyMode() {
        isProxyMode = false
    }

    /// In proxy mode the host's outbound roll messages carry the current player's
    /// participantID so guests see the roll attributed to the right seat.
    private var outboundParticipantID: UUID? {
        if isProxyMode,
           let mc = matchController,
           mc.currentPlayerIndex < mc.participantIDs.count {
            return mc.participantIDs[mc.currentPlayerIndex]
        }
        return localParticipantID
    }

    // MARK: - Outbound messages (Phase 5 — roll theater)

    func sendRollBegan(recipe: DiceRollRecipe, rollIndex: Int, heldMask: [Bool]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendRollBegan: roll=\(rollIndex) held=\(heldMask) seed=\(recipe.seed)")
        send(.rollBegan, payload: RollBeganPayload(
            participantID: participantID, rollIndex: rollIndex,
            recipe: recipe, heldMask: heldMask))
    }

    func sendRollResult(faceValues: [Int]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendRollResult: values=\(faceValues)")
        send(.rollResult, payload: RollResultPayload(
            participantID: participantID, faceValues: faceValues))
    }

    func sendHoldToggled(dieIndex: Int, isHeld: Bool) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendHoldToggled: die=\(dieIndex) held=\(isHeld)")
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
        case .seatRelease:    handleSeatRelease(envelope)
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
        // Compatible joiner — push current table state for catch-up.
        // If a match is already running, also push the full match snapshot so
        // reconnecting guests (or late joiners) see current scores immediately.
        if role == .host {
            Task {
                await self.broadcastTableState()
                if self.phase == .inProgress { await self.broadcastMatchState() }
            }
        }
    }

    private func persistLocalParticipantID() {
        guard let pid = localParticipantID, let mid = sessionMatchID else { return }
        UserDefaults.standard.setGnParticipantID(pid, for: mid)
    }

    private func handleTableState(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let payload = try? envelope.decode(TableStatePayload.self) else { return }
        phase = payload.phase
        seats = payload.seats
        commentaryEnabled = payload.commentaryEnabled
        commentaryPackID = payload.commentaryPackID
        commentaryLevelRaw = payload.commentaryLevelRaw
        // If the host removed our seat, clear the local claim so the Claim button reappears.
        if let claimID = localSeatClaimID, !seats.contains(where: { $0.seatClaimID == claimID }) {
            localSeatClaimID = nil
        }
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
        // Primary: match by seat claim ID.
        if let myClaimID = localSeatClaimID,
           let mapping = payload.seatMappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        // Fallback for reconnect: seatClaimID was cleared at relaunch.
        // Match the guest's old participantID → playerID → new participantID.
        else if let mc = matchController,
                let oldPID = localParticipantID,
                let myIndex = mc.participantIDs.firstIndex(of: oldPID),
                myIndex < mc.playerIDs.count,
                let myPlayerID = mc.playerIDs[myIndex],
                let participant = payload.match.participants.first(where: { $0.playerID == myPlayerID }) {
            localParticipantID = participant.id
        }
        if localParticipantID == nil {
            role = .spectator
        }
        sessionMatchID = payload.match.id
        sessionGameID = payload.match.gameID
        persistLocalParticipantID()
        matchController?.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        logger.debug(self, "matchStart: \(payload.match.participants.count) seats, seat \(payload.currentSeatIndex) role=\(role)")
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
        // On reconnect the session resumes via matchState (not matchStart), so
        // localParticipantID was never set. Restore it so send* methods work.
        if localParticipantID == nil {
            localParticipantID = UserDefaults.standard.gnParticipantID(for: payload.match.id)
            if sessionMatchID == nil { sessionMatchID = payload.match.id }
            if sessionGameID == nil { sessionGameID = payload.match.gameID }
        }
        if payload.diceValues != nil {
            // Undo broadcast — clear the pending flag and reload normally.
            pendingGuestUndoAvailable = false
            mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        } else if pendingGuestUndoAvailable {
            // Echo of our own score — preserve the undo snapshot so the button stays visible.
            mc.loadFromGameNightMatchPreservingUndo(payload.match, currentSeatIndex: payload.currentSeatIndex)
        } else {
            mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        }
        if let dv = payload.diceValues, let rr = payload.rollsRemaining {
            mc.restoreDiceStateAfterUndo(values: dv, rollsRemaining: rr)
            onUndoWithDice?(dv)
        }
        logger.debug(self, "matchState: seat \(payload.currentSeatIndex) undo=\(payload.diceValues != nil) pendingUndo=\(pendingGuestUndoAvailable)")
    }

    private func handleRollBegan(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollBeganPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleRollBegan: roll=\(payload.rollIndex) held=\(payload.heldMask) seed=\(payload.recipe.seed) hookWired=\(onRollBegan != nil)")
        pendingGuestUndoAvailable = false
        pendingHostUndoAvailable = false
        matchController?.clearUndoSnapshot()
        pendingAuthoritativeResult = nil
        onRollBegan?(payload.recipe, payload.heldMask)
    }

    private func handleRollResult(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollResultPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleRollResult: values=\(payload.faceValues) hookWired=\(onRollResult != nil)")
        pendingAuthoritativeResult = payload.faceValues
        onRollResult?(payload.faceValues)
    }

    private func handleHoldToggled(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HoldToggledPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleHoldToggled: die=\(payload.dieIndex) held=\(payload.isHeld) hookWired=\(onHoldToggled != nil)")
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

    private func handleSeatRelease(_ envelope: GameNightEnvelope) {
        guard role == .host, phase == .settingTable else { return }
        guard let payload = try? envelope.decode(SeatReleasePayload.self) else { return }
        removeSeat(seatClaimID: payload.seatClaimID)
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
        persistLocalParticipantID()
        UserDefaults.standard.setGnWasHost(for: match.id)
        matchController?.loadFromGameNightMatch(match, currentSeatIndex: currentSeatIndex)
        send(.matchStart, payload: MatchStartPayload(match: match, seatMappings: mappings, currentSeatIndex: currentSeatIndex))
        Task { await self.broadcastTableState() }
    }

    /// Host-only: start a new game with the same seated participants without leaving the
    /// current session. Builds a fresh match (new UUIDs, zeroed scores) from the existing
    /// seat list and broadcasts a `matchStart` so all guests reset alongside the host.
    func broadcastRematch(gameID: UUID) {
        guard role == .host,
              phase == .inProgress || phase == .completed,
              matchController != nil else { return }
        let (match, mappings) = buildInitialMatch(gameID: gameID)
        phase = .inProgress
        sessionMatchID = match.id
        sessionGameID = gameID
        if let myClaimID = localSeatClaimID,
           let mapping = mappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        persistLocalParticipantID()
        UserDefaults.standard.setGnWasHost(for: match.id)
        matchController?.loadFromGameNightMatch(match, currentSeatIndex: 0)
        send(.matchStart, payload: MatchStartPayload(match: match, seatMappings: mappings, currentSeatIndex: 0))
        Task { await broadcastTableState() }
    }

    /// Host-only: skip the seating phase and immediately resume an already-started match.
    /// Called after a cold relaunch when the host wants to reconnect Game Night without
    /// going back through table setup. Restores the local participant ID from the prior
    /// session so roll messages can be sent correctly.
    func resumeAsHost(matchID: UUID, gameID: UUID) {
        guard role == .host, isSessionActive, phase == .settingTable else { return }
        sessionMatchID = matchID
        sessionGameID = gameID
        localParticipantID = UserDefaults.standard.gnParticipantID(for: matchID)
        UserDefaults.standard.setGnWasHost(for: matchID)
        // Rebuild seat snapshots from the current match so broadcastRematch / playAgain
        // have a populated seat list even after a cold relaunch (tearDownSession clears seats).
        if let mc = matchController, mc.playerCount > 0 {
            var rebuilt: [SeatSnapshot] = []
            for i in 0..<mc.playerCount {
                let claimID = UUID()
                let isLocal = mc.participantIDs[i] == localParticipantID
                if isLocal { localSeatClaimID = claimID }
                rebuilt.append(SeatSnapshot(
                    seatClaimID: claimID,
                    seat: i,
                    playerID: mc.playerIDs[i],
                    displayName: mc.playerDisplayNames[i],
                    displayInitials: mc.playerDisplayInitials[i],
                    displayThemeID: mc.playerThemes[i].rawValue,
                    isLocal: isLocal
                ))
            }
            seats = rebuilt
        }
        phase = .inProgress
        Task {
            await broadcastTableState()
            await broadcastMatchState()
        }
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
            scoringSystemID: ScoringSystemID.yatzy.rawValue,
            scoringSystemVersion: 1,
            status: .inProgress,
            startedAt: Date(),
            completedAt: nil,
            participants: participants
        )
        return (match, mappings)
    }
}
