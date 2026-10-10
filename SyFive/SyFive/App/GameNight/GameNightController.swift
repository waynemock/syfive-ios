import Foundation
import SyLibCommentary
import SyLibCore
import SyLibDice
import SyLibGameNight
import SyLibGameNightMatch
import SyLibScoring
import SyLibYatzy

/// Game logic layer for Game Night. Holds a `GameNightSession` (transport/seats/handshake)
/// and a `GameNightMatchCoordinator` (match lifecycle, history sync, proxy mode).
///
/// This is the type views bind to via `@Environment(GameNightController.self)`.
/// Session-level observable properties are exposed as computed pass-throughs.
/// Match-layer state is forwarded from the coordinator so SwiftUI can track it.
@MainActor
@Observable
final class GameNightController {

    // MARK: - Role

    typealias Role = GameNightRole

    // MARK: - Session (transport layer)

    let session = GameNightSession<GameNightActivity>(
        keyPrefix: "syfive",
        appProtocolVersion: GameNightMessageKind.appProtocolVersion
    )

    // commentaryEnabled/PackID/LevelRaw are not reset on teardown.
    // Host: re-seeded from personal appSettings at each session activation (see ContentView).
    // Guests: populated from the host's tableState broadcast; not reset so values survive reconnects.
    private var appSettings = GameNightAppSettings(
        commentaryEnabled: false,
        commentaryPackID: CommentaryPersonality.zen.id,
        commentaryLevelRaw: CommentaryLevel.celebrations.rawValue
    )

    // MARK: - Proximity

    let proximity = GameNightProximity()

    /// Whether commentary speech is suppressed on this device. Driven by proximity verdict
    /// or manual tap; independent of the host's commentary-enabled setting.
    var commentaryIsSuppressed: Bool { proximity.isSuppressed }

    /// Begins proximity ranging if commentary is enabled and the local SharePlay ID is
    /// available (D-GNP-010, D-GNP-025). Idempotent — `GameNightProximity.begin` latches on
    /// first success; subsequent calls are no-ops. Call from multiple lifecycle points so the
    /// first moment the ID is available wins: session activation, first tableState, seat claim.
    func beginProximityRanging() {
        guard commentaryEnabled else {
            logger.debug(self, "beginProximityRanging: commentary disabled — skipping")
            return
        }
        guard let myID = session.localSharePlayID else {
            logger.debug(self, "beginProximityRanging: no localSharePlayID yet — deferring")
            return
        }
        proximity.begin(isHost: role == .host, localSharePlayID: myID)
    }

    /// Sets suppression state permanently for this match (D-GNP-008).
    func setCommentarySuppressed(_ suppressed: Bool) {
        proximity.overrideManually(suppressed: suppressed)
        onCommentarySuppressedChanged?()
    }

    // MARK: - Match coordinator

    let coordinator: GameNightMatchCoordinator<GameNightActivity> = {
        let c = GameNightMatchCoordinator<GameNightActivity>()
        c.scoringSystemID = ScoringSystemID.yatzy.rawValue
        c.scoringSystemVersion = 1
        return c
    }()

    // MARK: - Deliberate forwarding properties
    // These are kept on GameNightController because they are observed by multiple view files
    // or are required for @Bindable binding. Everything else is accessed via gameNight.session.xxx.

    var role: Role { session.role }
    var phase: GameNightPhase { session.phase }
    var seats: [SeatSnapshot] { session.seats }
    var isSessionActive: Bool { session.isSessionActive }
    var isSessionPending: Bool { session.isSessionPending }

    /// Commentary fields: read/write so views can bind (e.g. $gameNight.commentaryEnabled).
    var commentaryEnabled: Bool {
        get { appSettings.commentaryEnabled }
        set { appSettings.commentaryEnabled = newValue }
    }
    var commentaryPackID: String {
        get { appSettings.commentaryPackID }
        set { appSettings.commentaryPackID = newValue }
    }
    var commentaryLevelRaw: String {
        get { appSettings.commentaryLevelRaw }
        set { appSettings.commentaryLevelRaw = newValue }
    }

    // MARK: - Match-layer state forwarding (from coordinator)
    // Views observe these via GameNightController; @Observable tracking follows through to
    // the coordinator's stored properties, so coordinator mutations trigger view updates.

    var sessionMatchID: UUID? { coordinator.sessionMatchID }
    var sessionGameID: UUID? { coordinator.sessionGameID }
    var localParticipantID: UUID? { coordinator.localParticipantID }
    var isProxyMode: Bool { coordinator.isProxyMode }
    var pendingGuestUndoAvailable: Bool { coordinator.pendingGuestUndoAvailable }
    var pendingHostUndoAvailable: Bool { coordinator.pendingHostUndoAvailable }

    // MARK: - Session method pass-throughs

    func listenForSessions() async {
        coordinator.session = session
        // Forward autonomous proximity transitions (timeout, UWB verdict) to the app layer.
        proximity.onSuppressedChanged = { [weak self] in self?.onCommentarySuppressedChanged?() }
        // Host broadcasts a verdict whenever the union-find produces an election result.
        proximity.onDecisionsElected = { [weak self] decisions in
            self?.session.send(.proximityVerdict, payload: ProximityVerdictPayload(decisions: decisions))
        }
        // Proximity fires this when a UWB session token is ready to broadcast or send.
        proximity.onReadyToSendToken = { [weak self] senderID, targetPeerID, tokenData, supportsRanging in
            self?.session.send(.proximityToken, payload: ProximityTokenPayload(
                senderID: senderID, tokenData: tokenData, targetPeerID: targetPeerID,
                supportsRanging: supportsRanging))
        }
        // Guests fire this when they have a pairwise distance report for the host.
        proximity.onReadyToReport = { [weak self] senderID, peerID, isNear in
            self?.session.send(.proximityReport, payload: ProximityReportPayload(
                senderID: senderID, peerID: peerID, isNear: isNear))
        }
        // Presence retry uses this to check NISession coverage against rangeable peers
        // only (D-GNP-033) — excludes self and incapable peers from the coverage count.
        proximity.allSharePlayIDsProvider = { [weak self] in
            self?.session.allSharePlayIDs ?? []
        }
        // Presence retry uses this to exit when the phase advances beyond settingTable
        // without relying solely on task cancellation — produces a searchable log entry (D-GNP-035).
        proximity.phaseProvider = { [weak self] in
            self?.session.phase ?? .settingTable
        }
        // Route session-layer proximity envelopes to the GameNightProximity component.
        session.onProximityTokenReceived = { [weak self] senderID, targetPeerID, tokenData, supportsRanging in
            self?.proximity.handleProximityToken(senderID: senderID, targetPeerID: targetPeerID,
                                                 tokenData: tokenData, supportsRanging: supportsRanging)
        }
        session.onProximityReportReceived = { [weak self] senderID, peerID, isNear in
            guard let self, self.role == .host,
                  let hostID = self.session.localSharePlayID else { return }
            self.proximity.handleProximityReport(senderID: senderID, peerID: peerID,
                                                 isNear: isNear, hostSharePlayID: hostID)
        }
        session.onProximityVerdictReceived = { [weak self] decisions in
            guard let self, let myID = self.session.localSharePlayID else { return }
            self.proximity.applyVerdict(decisions: decisions, localSharePlayID: myID)
        }
        // Wire coordinator output callbacks before the session starts.
        coordinator.onMatchStarted = { [weak self] in
            guard let self else { return }
            self.proximity.lockSeatMap(self.session.senderSeatMap,
                                       allParticipantIDs: self.session.allSharePlayIDs)
            self.proximity.openResolutionWindow()
            self.onMatchStarted?()
        }
        coordinator.onMatchComplete = { [weak self] match in self?.onMatchComplete?(match) }
        coordinator.onHistoryManifestNeeded = { [weak self] in self?.onHistoryManifestNeeded?() ?? [] }
        coordinator.onHistoryMatchesNeeded = { [weak self] ids in self?.onHistoryMatchesNeeded?(ids) ?? [] }
        coordinator.onHistoryMatchesReceived = { [weak self] matches in self?.onHistoryMatchesReceived?(matches) }

        GameNightLogBuffer.configure(keyPrefix: session.keyPrefix)
        GameNightLogBuffer.shared.isLoggingEnabled = AppConfig.DebugGameNight.showLogs
        session.onTearDown = { [weak self] in self?.performControllerTearDown() }
        session.onNeedsMatchStateBroadcast = { [weak self] in Task { await self?.broadcastMatchState() } }
        session.appSettingsProvider = { [weak self] in
            guard let self else { return nil }
            return try? JSONEncoder().encode(self.appSettings)
        }
        session.onTableStateReceived = { [weak self] envelope in
            guard let self else { return }
            if let payload = try? envelope.decode(TableStatePayload.self),
               let data = payload.appSettings,
               let settings = try? JSONDecoder().decode(GameNightAppSettings.self, from: data) {
                self.appSettings.commentaryEnabled = settings.commentaryEnabled
                self.appSettings.commentaryPackID = settings.commentaryPackID
                self.appSettings.commentaryLevelRaw = settings.commentaryLevelRaw
            }
            // Second begin() call site (D-GNP-025): by the time tableState arrives, the
            // GroupSession is fully established and localSharePlayID is guaranteed available.
            // Gated inside settingTable by begin's hasBegun latch — mid-match tableState is a no-op.
            if self.phase == .settingTable { self.beginProximityRanging() }
            self.onCommentarySettingsChanged?()
        }
        session.onAppMessage = { [weak self] kindString, envelope, senderID in
            self?.handleAppMessage(kindString, envelope, from: senderID)
        }
        await session.listenForSessions()
    }

    func prepareAsHost() { session.prepareAsHost() }
    func cancelHostPreparation() { session.cancelHostPreparation() }
    func beginHosting(
        onNeedsConversation: @escaping () -> Void,
        onReadyToSeat: @escaping () -> Void
    ) {
        session.beginHosting(
            activity: GameNightActivity(),
            onNeedsConversation: onNeedsConversation,
            onReadyToSeat: onReadyToSeat
        )
    }
    func endSession() { session.endSession() }

    /// Deliberate wrapper: session releases the seat; coordinator clears match-layer participant ID.
    func leaveSession() {
        session.leaveSession()
        coordinator.localParticipantID = nil
    }

    func playAgain() { session.playAgain() }
    func abandonSession() {
        guard session.role == .host, session.isSessionActive else { return }
        session.send(GameNightMatchKind.matchAbandoned, payload: MatchAbandonedPayload())
        session.abandonSession()
    }
    func clearSessionEndedFlag() { session.clearSessionEndedFlag() }
    func clearGuestJoinFailure() { session.clearGuestJoinFailure() }
    func claimSeat(displayName: String, displayInitials: String, themeID: String, playerID: UUID?, isLocal: Bool = false) {
        session.claimSeat(displayName: displayName, displayInitials: displayInitials, themeID: themeID, playerID: playerID, isLocal: isLocal)
        // Third begin() call site (D-GNP-025): seat claiming is the last moment reliably inside
        // the setting-table phase. Covers the case where tableState arrived before commentary
        // settings were seeded. Idempotent — begin's hasBegun latch makes repeated calls no-ops.
        beginProximityRanging()
    }
    func updateOwnSeat(name: String, initials: String, themeID: String) {
        session.updateOwnSeat(name: name, initials: initials, themeID: themeID)
    }
    func moveSeat(fromOffsets: IndexSet, toOffset: Int) {
        session.moveSeat(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    func removeSeat(seatClaimID: UUID) { session.removeSeat(seatClaimID: seatClaimID) }

    func broadcastTableState() async { await session.broadcastTableState() }

    func gnWasHost(for matchID: UUID) -> Bool { session.gnWasHost(for: matchID) }

    func prepareForGuestReconnect(matchID: UUID) {
        session.isGuestAwaitingReconnect = true
        if coordinator.localParticipantID == nil {
            coordinator.localParticipantID = session.gnParticipantID(for: matchID)
        }
    }

    // MARK: - Roll theater hooks

    var onRollBegan: ((DiceRollRecipe, [Bool]) -> Void)?
    var onRollResult: (([Int]) -> Void)?
    var onHoldToggled: ((Int, Bool) -> Void)?
    var pendingAuthoritativeResult: [Int]? = nil
    var onUndoWithDice: (([Int]) -> Void)?

    // MARK: - App-layer hooks

    var onMatchComplete: ((Match) -> Void)?
    var onMatchStarted: (() -> Void)?
    var onOpponentScored: ((Int, YatzyCategory, Int) -> Void)?
    var onCommentaryReceived: ((String, CommentaryEventTier) -> Void)?
    var onCommentarySettingsChanged: (() -> Void)?
    var onCommentarySuppressedChanged: (() -> Void)?
    var onUndoApplied: (() -> Void)?
    var onHistoryManifestNeeded: (() -> [UUID])?
    var onHistoryMatchesNeeded: (([UUID]) -> [Match])?
    var onHistoryMatchesReceived: (([Match]) -> Void)?

    // MARK: - Private state

    private let logger = AppLogger(category: "GameNightController")
    private weak var matchController: MatchController?
    private var spectatorRollInProgress = false

    // MARK: - Match controller wiring

    func attach(matchController: MatchController) {
        logger.info(self, "attach: wiring matchController playerCount=\(matchController.playerCount) role=\(String(describing: role))")
        self.matchController = matchController
        coordinator.attach(to: matchController)
        // Wire GNC-specific onScoreApplied for the guest proposal path (carries YatzyCategory).
        // The coordinator handles the host broadcast path and the undo-available flag via onMoveApplied.
        matchController.onScoreApplied = { [weak self] category, dice in
            guard let self, self.role != .host, self.phase == .inProgress else { return }
            self.proposeScore(category: category, diceValues: dice)
        }
        coordinator.onProposeUndo = { [weak self] in self?.proposeUndo() }
    }

    private func detachMatchController() {
        logger.info(self, "detachMatchController: matchID=\(coordinator.sessionMatchID?.uuidString ?? "nil")")
        matchController?.onScoreApplied = nil
        matchController = nil
        coordinator.detach()
    }

    // MARK: - Match coordinator delegation

    func broadcastMatchState() async { await coordinator.broadcastMatchState() }
    func broadcastMatchUndo(diceValues: [Int]) async { await coordinator.broadcastMatchUndo(diceValues: diceValues) }
    func broadcastMatchComplete() async { await coordinator.broadcastMatchComplete() }
    func broadcastMatchStart(gameID: UUID) { coordinator.broadcastMatchStart(gameID: gameID) }
    func broadcastRematch(gameID: UUID) { coordinator.broadcastRematch(gameID: gameID) }
    func resumeAsHost(matchID: UUID, gameID: UUID) { coordinator.resumeAsHost(matchID: matchID, gameID: gameID) }
    func enableProxyMode() { coordinator.enableProxyMode() }
    func disableProxyMode() { coordinator.disableProxyMode() }

    // MARK: - Guest scoring proposals

    func proposeScore(category: YatzyCategory, diceValues: [Int]) {
        guard role != .host, phase == .inProgress,
              let participantID = coordinator.localParticipantID else { return }
        logger.info(self, "proposeScore: category=\(category.rawValue) dice=\(diceValues) participantID=\(participantID)")
        session.send(.scoreChosen, payload: ScoreChosenPayload(
            participantID: participantID, category: category, diceValues: diceValues))
    }

    func proposeUndo() {
        guard role != .host, phase == .inProgress,
              let mc = matchController,
              let undoIndex = mc.undoPlayerIndex,
              undoIndex < mc.participantIDs.count else { return }
        coordinator.pendingGuestUndoAvailable = false
        let participantID = mc.participantIDs[undoIndex]
        logger.info(self, "proposeUndo: participantID=\(participantID) seat=\(undoIndex)")
        session.send(.undoRequest, payload: UndoRequestPayload(participantID: participantID))
    }

    // MARK: - Roll theater sends

    func sendRollBegan(recipe: DiceRollRecipe, rollIndex: Int, heldMask: [Bool]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = coordinator.outboundParticipantID else { return }
        logger.debug(self, "sendRollBegan: roll=\(rollIndex) held=\(heldMask) seed=\(recipe.seed)")
        session.send(.rollBegan, payload: RollBeganPayload(
            participantID: participantID, rollIndex: rollIndex,
            recipe: recipe, heldMask: heldMask))
    }

    func sendRollResult(faceValues: [Int]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = coordinator.outboundParticipantID else { return }
        logger.debug(self, "sendRollResult: values=\(faceValues)")
        session.send(.rollResult, payload: RollResultPayload(
            participantID: participantID, faceValues: faceValues))
    }

    func sendHoldToggled(dieIndex: Int, isHeld: Bool) {
        guard isSessionActive, phase == .inProgress,
              let participantID = coordinator.outboundParticipantID else { return }
        logger.debug(self, "sendHoldToggled: die=\(dieIndex) held=\(isHeld)")
        session.send(.holdToggled, payload: HoldToggledPayload(
            participantID: participantID, dieIndex: dieIndex, isHeld: isHeld))
    }

    // MARK: - Inbound message router

    private func handleAppMessage(_ kindString: String, _ envelope: GameNightEnvelope, from senderID: UUID) {
        // matchState is received by GNC, not the coordinator — it carries a Match snapshot
        // and GNC runs Yatzy-specific opponent-score detection against mc.playerScores.
        if kindString == GameNightMatchKind.matchState.rawValue {
            handleMatchState(envelope)
            return
        }
        // All other match-layer kinds route to the coordinator.
        if let matchKind = GameNightMatchKind(rawValue: kindString) {
            coordinator.handleMatchKind(matchKind, envelope: envelope, from: senderID)
            return
        }
        guard let kind = GameNightMessageKind(rawValue: kindString) else { return }
        switch kind {
        case .rollBegan:    handleRollBegan(envelope)
        case .rollResult:   handleRollResult(envelope)
        case .holdToggled:  handleHoldToggled(envelope)
        case .scoreChosen:  handleScoreChosen(envelope, from: senderID)
        case .undoRequest:  handleUndoRequest(envelope, from: senderID)
        case .commentary:   handleCommentary(envelope)
        }
    }

    // MARK: - Yatzy-specific match handlers

    private func handleScoreChosen(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host, phase == .inProgress,
              let mc = matchController,
              let payload = try? envelope.decode(ScoreChosenPayload.self) else { return }
        logger.info(self, "handleScoreChosen: participantID=\(payload.participantID) category=\(payload.category.rawValue) dice=\(payload.diceValues)")
        mc.applyRemoteScore(
            category: payload.category,
            remoteValues: payload.diceValues,
            forParticipantID: payload.participantID
        )
    }

    private func handleUndoRequest(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host, phase == .inProgress,
              let mc = matchController,
              let payload = try? envelope.decode(UndoRequestPayload.self) else { return }
        guard let index = mc.participantIDs.firstIndex(of: payload.participantID),
              mc.undoPlayerIndex == index else {
            logger.warning(self, "handleUndoRequest: rejected — participantID=\(payload.participantID) undoIndex=\(mc.undoPlayerIndex?.description ?? "nil")")
            return
        }
        logger.info(self, "handleUndoRequest: accepted participantID=\(payload.participantID) seat=\(index)")
        mc.undoLastScore()
        onUndoApplied?()
    }

    private func handleMatchState(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let mc = matchController,
              let payload = try? envelope.decode(MatchStatePayload.self) else { return }
        let isReconnect = coordinator.localParticipantID == nil
        if coordinator.localParticipantID == nil {
            coordinator.localParticipantID = session.gnParticipantID(for: payload.match.id)
            if coordinator.sessionMatchID == nil { coordinator.sessionMatchID = payload.match.id }
            if coordinator.sessionGameID == nil { coordinator.sessionGameID = payload.match.gameID }
        }
        if payload.diceValues != nil {
            // Undo broadcast: clear undo availability before loading so the restored state is clean.
            coordinator.pendingGuestUndoAvailable = false
            mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
            onUndoApplied?()
        } else if coordinator.pendingGuestUndoAvailable {
            // Self-echo path: preserve the undo snapshot so the guest can still undo their score.
            // Using loadFromGameNightMatch here would clear lastScoreSnapshot. (Inventory 6.5 / 9.3)
            mc.loadFromGameNightMatchPreservingUndo(payload.match, currentSeatIndex: payload.currentSeatIndex)
        } else {
            let guestAlreadyRolled = mc.rollsRemaining < 3
            let scoresBefore = mc.playerScores
            mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
            if !guestAlreadyRolled {
                detectAndAnnounceOpponentScore(scoresBefore: scoresBefore, mc: mc)
            }
        }
        if let dv = payload.diceValues, let rr = payload.rollsRemaining {
            mc.restoreDiceStateAfterUndo(values: dv, rollsRemaining: rr)
            onUndoWithDice?(dv)
        }
        logger.debug(self, "handleMatchState: matchID=\(payload.match.id) seat=\(payload.currentSeatIndex) scores=\(payload.match.participants.map { $0.scoreEntries.count }) undo=\(payload.diceValues != nil) pendingUndo=\(coordinator.pendingGuestUndoAvailable) reconnect=\(isReconnect)")
    }

    // MARK: - Roll theater handlers

    private func handleRollBegan(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollBeganPayload.self),
              payload.participantID != coordinator.localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleRollBegan: roll=\(payload.rollIndex) held=\(payload.heldMask) seed=\(payload.recipe.seed) hookWired=\(onRollBegan != nil)")
        spectatorRollInProgress = true
        coordinator.clearUndoAvailability()
        matchController?.clearUndoSnapshot()
        pendingAuthoritativeResult = nil
        onRollBegan?(payload.recipe, payload.heldMask)
    }

    private func handleRollResult(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollResultPayload.self),
              payload.participantID != coordinator.localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleRollResult: values=\(payload.faceValues) hookWired=\(onRollResult != nil)")
        spectatorRollInProgress = false
        pendingAuthoritativeResult = payload.faceValues
        onRollResult?(payload.faceValues)
    }

    private func handleHoldToggled(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HoldToggledPayload.self),
              payload.participantID != coordinator.localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleHoldToggled: die=\(payload.dieIndex) held=\(payload.isHeld) hookWired=\(onHoldToggled != nil)")
        onHoldToggled?(payload.dieIndex, payload.isHeld)
    }

    // MARK: - Commentary

    func broadcastCommentary(text: String, tier: CommentaryEventTier) {
        guard role == .host, phase == .inProgress else { return }
        session.send(.commentary, payload: CommentaryPayload(text: text, tierRaw: tier.rawValue))
    }

    private func handleCommentary(_ envelope: GameNightEnvelope) {
        guard role != .host, phase == .inProgress,
              let payload = try? envelope.decode(CommentaryPayload.self) else { return }
        let tier = CommentaryEventTier(rawValue: payload.tierRaw) ?? .playByPlay
        onCommentaryReceived?(payload.text, tier)
    }

    private func detectAndAnnounceOpponentScore(scoresBefore: [[YatzyCategory: Int]], mc: MatchController) {
        guard !mc.isGameOver, !spectatorRollInProgress else { return }
        let scoresAfter = mc.playerScores
        for (playerIndex, after) in scoresAfter.enumerated() {
            guard playerIndex < scoresBefore.count else { continue }
            let before = scoresBefore[playerIndex]
            for (cat, val) in after where before[cat] == nil {
                onOpponentScored?(playerIndex, cat, val)
                return
            }
        }
    }

    // MARK: - Controller-layer teardown

    private func performControllerTearDown() {
        proximity.end()
        // Proximity callbacks (onReadyToSendToken, onDecisionsElected, onReadyToReport,
        // onSuppressedChanged) are intentionally NOT cleared here. They are wired once
        // in listenForSessions() for the controller's lifetime. Clearing them on session
        // teardown leaves them nil at the next begin(), silently dropping all token sends
        // and making proximity completely non-functional for every session after the first.
        // (D-GNP-030 — nine presence announcements, zero transmissions)
        onRollBegan = nil
        onRollResult = nil
        onHoldToggled = nil
        pendingAuthoritativeResult = nil
        onUndoWithDice = nil
        onMatchComplete = nil
        onMatchStarted = nil
        onOpponentScored = nil
        onCommentaryReceived = nil
        onCommentarySettingsChanged = nil
        onCommentarySuppressedChanged = nil
        onUndoApplied = nil
        onHistoryManifestNeeded = nil
        onHistoryMatchesNeeded = nil
        onHistoryMatchesReceived = nil
        spectatorRollInProgress = false
        detachMatchController()
    }
}
