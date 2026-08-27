import Foundation
import SyLibCore
import SyLibDice
import SyLibScoring

/// Game logic layer for Game Night. Holds a `GameNightSession` (transport/seats/handshake)
/// and manages match state, roll theater, scoring, history sync, and proxy mode.
///
/// This is the type views bind to via `@Environment(GameNightController.self)`.
/// Session-level observable properties are exposed as computed pass-throughs that chain
/// correctly through Swift's `@Observable` machinery — views observing `gameNight.phase`
/// track changes on the underlying `GameNightSession.phase` stored property.
@MainActor
@Observable
final class GameNightController {

    // MARK: - Role

    enum Role {
        case host
        case guest
        case spectator  // joined after matchStart; no seat, read-only
    }

    // MARK: - Session (transport layer)

    let session = GameNightSession(keyPrefix: "syfive")

    init() {
        // The session holds these opaquely; the app owns what they mean.
        session.commentaryPackID = CommentaryPersonality.zen.id
        session.commentaryLevelRaw = CommentaryLevel.celebrations.rawValue
    }

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
        get { session.commentaryEnabled }
        set { session.commentaryEnabled = newValue }
    }
    var commentaryPackID: String {
        get { session.commentaryPackID }
        set { session.commentaryPackID = newValue }
    }
    var commentaryLevelRaw: String {
        get { session.commentaryLevelRaw }
        set { session.commentaryLevelRaw = newValue }
    }

    // MARK: - Session method pass-throughs

    func listenForSessions() async {
        session.onTearDown = { [weak self] in self?.performControllerTearDown() }
        session.onNeedsMatchStateBroadcast = { [weak self] in Task { await self?.broadcastMatchState() } }
        session.onTableStateReceived = { [weak self] _ in self?.onCommentarySettingsChanged?() }
        session.onAppMessage = { [weak self] kind, envelope, senderID in
            self?.handleAppMessage(kind, envelope, from: senderID)
        }
        await session.listenForSessions()
    }

    func prepareAsHost() { session.prepareAsHost() }
    func cancelHostPreparation() { session.cancelHostPreparation() }
    func endSession() { session.endSession() }

    /// Deliberate wrapper: session releases the seat; controller clears match-layer participant ID.
    func leaveSession() {
        session.leaveSession()
        localParticipantID = nil
    }

    func playAgain() { session.playAgain() }
    func abandonSession() { session.abandonSession() }
    func clearSessionEndedFlag() { session.clearSessionEndedFlag() }
    func clearHostVersionMismatch() { session.clearHostVersionMismatch() }
    func claimSeat(displayName: String, displayInitials: String, themeID: String, playerID: UUID?, isLocal: Bool = false) {
        session.claimSeat(displayName: displayName, displayInitials: displayInitials, themeID: themeID, playerID: playerID, isLocal: isLocal)
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
        if localParticipantID == nil {
            localParticipantID = session.gnParticipantID(for: matchID)
        }
    }

    // MARK: - Game Night match state (Phase 4)

    private weak var matchController: MatchController?
    private(set) var sessionMatchID: UUID?
    private(set) var sessionGameID: UUID?

    // MARK: - Roll theater hooks (Phase 5)

    var onRollBegan: ((DiceRollRecipe, [Bool]) -> Void)?
    var onRollResult: (([Int]) -> Void)?
    var onHoldToggled: ((Int, Bool) -> Void)?
    var pendingAuthoritativeResult: [Int]? = nil
    var onUndoWithDice: (([Int]) -> Void)?
    private(set) var pendingGuestUndoAvailable: Bool = false
    private(set) var pendingHostUndoAvailable: Bool = false

    // MARK: - Completion hook (Phase 6)

    var onMatchComplete: ((Match) -> Void)?
    var onMatchStarted: (() -> Void)?

    // MARK: - Score announcement hook

    var onOpponentScored: ((Int, YatzyCategory, Int) -> Void)?
    var onCommentaryReceived: ((String, CommentaryEventTier) -> Void)?
    var onCommentarySettingsChanged: (() -> Void)?
    var onUndoApplied: (() -> Void)?

    // MARK: - Match history sync hooks

    var onHistoryManifestNeeded: (() -> [UUID])?
    var onHistoryMatchesNeeded: (([UUID]) -> [Match])?
    var onHistoryMatchesReceived: (([Match]) -> Void)?

    // MARK: - Private match state

    private let logger = AppLogger(category: "GameNightController")
    private(set) var localParticipantID: UUID?
    private(set) var isProxyMode = false
    private var spectatorRollInProgress = false

    // MARK: - Match controller wiring (Phase 4)

    func attach(matchController: MatchController) {
        logger.info(self, "attach: wiring matchController playerCount=\(matchController.playerCount) role=\(String(describing: role))")
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
        logger.info(self, "detachMatchController: clearing hooks matchID=\(sessionMatchID?.uuidString ?? "nil")")
        matchController?.onScoreApplied = nil
        matchController?.onUndone = nil
        matchController?.onRollStarted = nil
        matchController = nil
        pendingHostUndoAvailable = false
        isProxyMode = false
        sessionMatchID = nil
        sessionGameID = nil
    }

    // MARK: - Match state broadcasts (host)

    func broadcastMatchState() async {
        guard role == .host, phase == .inProgress,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        logger.debug(self, "broadcastMatchState: seat=\(mc.currentPlayerIndex) matchID=\(matchID) scores=\(match.participants.map { $0.scoreEntries.count })")
        session.send(.matchState, payload: MatchStatePayload(match: match, currentSeatIndex: mc.currentPlayerIndex))
    }

    func broadcastMatchUndo(diceValues: [Int]) async {
        guard role == .host, phase == .inProgress,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        session.send(.matchState, payload: MatchStatePayload(
            match: match,
            currentSeatIndex: mc.currentPlayerIndex,
            diceValues: diceValues,
            rollsRemaining: 0
        ))
    }

    func broadcastMatchComplete() async {
        guard role == .host,
              let mc = matchController,
              let matchID = sessionMatchID,
              let gameID = sessionGameID else { return }
        let match = mc.buildMatchSnapshot(matchID: matchID, gameID: gameID)
        logger.info(self, "broadcastMatchComplete: matchID=\(matchID) winners=\(match.participants.filter { $0.rank == 1 }.map(\.displayName).joined(separator: ","))")
        session.phase = .completed
        GameNightLogBuffer.shared.flushToDisk()
        session.send(.matchComplete, payload: MatchCompletePayload(match: match))
        Task { await broadcastTableState() }
    }

    // MARK: - Guest scoring proposals

    func proposeScore(category: YatzyCategory, diceValues: [Int]) {
        guard role != .host, phase == .inProgress,
              let participantID = localParticipantID else { return }
        logger.info(self, "proposeScore: category=\(category.rawValue) dice=\(diceValues) participantID=\(participantID)")
        session.send(.scoreChosen, payload: ScoreChosenPayload(
            participantID: participantID, category: category, diceValues: diceValues))
    }

    func proposeUndo() {
        guard role != .host, phase == .inProgress,
              let mc = matchController,
              let undoIndex = mc.undoPlayerIndex,
              undoIndex < mc.participantIDs.count else { return }
        pendingGuestUndoAvailable = false
        let participantID = mc.participantIDs[undoIndex]
        logger.info(self, "proposeUndo: participantID=\(participantID) seat=\(undoIndex)")
        session.send(.undoRequest, payload: UndoRequestPayload(participantID: participantID))
    }

    // MARK: - Proxy mode (D-121)

    func enableProxyMode() {
        guard role == .host else { return }
        let proxySeat = matchController?.currentPlayerIndex ?? -1
        let proxyName = matchController.flatMap { $0.playerDisplayNames.indices.contains(proxySeat) ? $0.playerDisplayNames[proxySeat] : nil } ?? "?"
        logger.info(self, "enableProxyMode: proxying seat=\(proxySeat) name=\(proxyName)")
        isProxyMode = true
    }

    func disableProxyMode() {
        isProxyMode = false
    }

    private var outboundParticipantID: UUID? {
        if isProxyMode,
           let mc = matchController,
           mc.currentPlayerIndex < mc.participantIDs.count {
            return mc.participantIDs[mc.currentPlayerIndex]
        }
        return localParticipantID
    }

    // MARK: - Roll theater sends (Phase 5)

    func sendRollBegan(recipe: DiceRollRecipe, rollIndex: Int, heldMask: [Bool]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendRollBegan: roll=\(rollIndex) held=\(heldMask) seed=\(recipe.seed)")
        session.send(.rollBegan, payload: RollBeganPayload(
            participantID: participantID, rollIndex: rollIndex,
            recipe: recipe, heldMask: heldMask))
    }

    func sendRollResult(faceValues: [Int]) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendRollResult: values=\(faceValues)")
        session.send(.rollResult, payload: RollResultPayload(
            participantID: participantID, faceValues: faceValues))
    }

    func sendHoldToggled(dieIndex: Int, isHeld: Bool) {
        guard isSessionActive, phase == .inProgress,
              let participantID = outboundParticipantID else { return }
        logger.debug(self, "sendHoldToggled: die=\(dieIndex) held=\(isHeld)")
        session.send(.holdToggled, payload: HoldToggledPayload(
            participantID: participantID, dieIndex: dieIndex, isHeld: isHeld))
    }

    // MARK: - Match start / rematch / resume (host)

    func broadcastMatchStart(gameID: UUID) {
        guard role == .host, phase == .settingTable, seats.count >= 2 else { return }
        let match: Match
        let mappings: [SeatMapping]
        let currentSeatIndex: Int
        if let mc = matchController, let matchID = mc.persistedMatchID, mc.playerCount >= 2, !mc.isGameOver {
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
        session.phase = .inProgress
        sessionMatchID = match.id
        sessionGameID = gameID
        if let myClaimID = session.localSeatClaimID,
           let mapping = mappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        persistLocalParticipantID()
        session.setGnWasHost(for: match.id)
        logger.info(self, "broadcastMatchStart: matchID=\(match.id) seats=\(seats.count) path=\(currentSeatIndex > 0 ? "resume" : "new") players=\(match.participants.map(\.displayName).joined(separator: ","))")
        matchController?.loadFromGameNightMatch(match, currentSeatIndex: currentSeatIndex)
        session.send(.matchStart, payload: MatchStartPayload(match: match, seatMappings: mappings, currentSeatIndex: currentSeatIndex))
        Task { await self.broadcastTableState() }
        broadcastHistoryManifest()
    }

    func broadcastRematch(gameID: UUID) {
        guard role == .host,
              phase == .inProgress || phase == .completed,
              matchController != nil else { return }
        let (match, mappings) = buildInitialMatch(gameID: gameID)
        session.phase = .inProgress
        sessionMatchID = match.id
        sessionGameID = gameID
        if let myClaimID = session.localSeatClaimID,
           let mapping = mappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
        }
        persistLocalParticipantID()
        session.setGnWasHost(for: match.id)
        logger.info(self, "broadcastRematch: newMatchID=\(match.id) seats=\(seats.count) players=\(match.participants.map(\.displayName).joined(separator: ","))")
        // Sever the SwiftData binding before loading the new match so game N+1's saves
        // create a fresh row instead of overwriting game N's completed record.
        matchController?.clearPersistedMatchBinding()
        matchController?.loadFromGameNightMatch(match, currentSeatIndex: 0)
        session.send(.matchStart, payload: MatchStartPayload(match: match, seatMappings: mappings, currentSeatIndex: 0))
        Task { await broadcastTableState() }
        broadcastHistoryManifest()
    }

    func resumeAsHost(matchID: UUID, gameID: UUID) {
        guard role == .host, isSessionActive, phase == .settingTable else { return }
        logger.info(self, "resumeAsHost: matchID=\(matchID) playerCount=\(matchController?.playerCount ?? 0)")
        sessionMatchID = matchID
        sessionGameID = gameID
        localParticipantID = session.gnParticipantID(for: matchID)
        session.setGnWasHost(for: matchID)
        if let mc = matchController, mc.playerCount > 0 {
            var rebuilt: [SeatSnapshot] = []
            for i in 0..<mc.playerCount {
                let claimID = UUID()
                let isLocal = mc.participantIDs[i] == localParticipantID
                if isLocal { session.localSeatClaimID = claimID }
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
            session.seats = rebuilt
        }
        session.phase = .inProgress
        Task {
            await session.broadcastTableState()
            await broadcastMatchState()
        }
    }

    // MARK: - Inbound message router

    private func handleAppMessage(_ kind: GameNightMessageKind, _ envelope: GameNightEnvelope, from senderID: UUID) {
        switch kind {
        case .matchStart:        handleMatchStart(envelope)
        case .rollBegan:         handleRollBegan(envelope)
        case .rollResult:        handleRollResult(envelope)
        case .holdToggled:       handleHoldToggled(envelope)
        case .scoreChosen:       handleScoreChosen(envelope, from: senderID)
        case .undoRequest:       handleUndoRequest(envelope, from: senderID)
        case .matchState:        handleMatchState(envelope)
        case .matchComplete:     handleMatchComplete(envelope)
        case .matchAbandoned:    handleMatchAbandoned()
        case .commentary:        handleCommentary(envelope)
        case .historyManifest:   handleHistoryManifest(envelope)
        case .historyRequest:    handleHistoryRequest(envelope)
        case .historyResponse:   handleHistoryResponse(envelope)
        default: break
        }
    }

    // MARK: - Match-layer handlers

    private func handleMatchStart(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let payload = try? envelope.decode(MatchStartPayload.self) else { return }
        session.phase = .inProgress
        let effectiveClaimID = session.localSeatClaimID ?? session.pendingSeatClaim?.seatClaimID
        if let myClaimID = effectiveClaimID,
           let mapping = payload.seatMappings.first(where: { $0.seatClaimID == myClaimID }) {
            localParticipantID = mapping.participantID
            session.localSeatClaimID = myClaimID
            session.pendingSeatClaim = nil
        } else if let mc = matchController,
                  let oldPID = localParticipantID,
                  let myIndex = mc.participantIDs.firstIndex(of: oldPID),
                  myIndex < mc.playerIDs.count,
                  let myPlayerID = mc.playerIDs[myIndex],
                  let participant = payload.match.participants.first(where: { $0.playerID == myPlayerID }) {
            localParticipantID = participant.id
        }
        let resolutionPath: String
        if localParticipantID != nil && session.localSeatClaimID != nil {
            resolutionPath = "claimID"
        } else if localParticipantID != nil {
            resolutionPath = "fallback"
        } else {
            resolutionPath = "spectator"
            session.role = .spectator
        }
        // isRematch must be computed before sessionMatchID is reassigned — load-bearing ordering (Inventory 7.2).
        // Reassigning sessionMatchID first silently breaks rematch detection and destroys the previous match record.
        let isRematch = sessionMatchID != nil && sessionMatchID != payload.match.id
        sessionMatchID = payload.match.id
        sessionGameID = payload.match.gameID
        persistLocalParticipantID()
        if isRematch { matchController?.clearPersistedMatchBinding() }
        matchController?.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
        onMatchStarted?()
        broadcastHistoryManifest()
        logger.info(self, "handleMatchStart: matchID=\(payload.match.id) participants=\(payload.match.participants.count) seat=\(payload.currentSeatIndex) localPID=\(localParticipantID?.uuidString ?? "nil") path=\(resolutionPath)")
    }

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
        let isReconnect = localParticipantID == nil
        if localParticipantID == nil {
            localParticipantID = session.gnParticipantID(for: payload.match.id)
            if sessionMatchID == nil { sessionMatchID = payload.match.id }
            if sessionGameID == nil { sessionGameID = payload.match.gameID }
        }
        if payload.diceValues != nil {
            pendingGuestUndoAvailable = false
            mc.loadFromGameNightMatch(payload.match, currentSeatIndex: payload.currentSeatIndex)
            onUndoApplied?()
        } else if pendingGuestUndoAvailable {
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
        logger.debug(self, "handleMatchState: matchID=\(payload.match.id) seat=\(payload.currentSeatIndex) scores=\(payload.match.participants.map { $0.scoreEntries.count }) undo=\(payload.diceValues != nil) pendingUndo=\(pendingGuestUndoAvailable) reconnect=\(isReconnect)")
    }

    private func handleMatchComplete(_ envelope: GameNightEnvelope) {
        guard role != .host, phase == .inProgress,
              let payload = try? envelope.decode(MatchCompletePayload.self) else { return }
        session.phase = .completed
        GameNightLogBuffer.shared.flushToDisk()
        onMatchComplete?(payload.match)
        logger.debug(self, "matchComplete: \(payload.match.id)")
    }

    private func handleMatchAbandoned() {
        guard phase == .inProgress || phase == .settingTable else { return }
        let wasInProgress = phase == .inProgress
        logger.info(self, "handleMatchAbandoned: wasInProgress=\(wasInProgress) matchID=\(sessionMatchID?.uuidString ?? "nil")")
        session.tearDownSession()
        if wasInProgress { session.sessionEndedDuringPlay = true }
    }

    // MARK: - Roll theater handlers

    private func handleRollBegan(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(RollBeganPayload.self),
              payload.participantID != localParticipantID,
              phase == .inProgress else { return }
        logger.debug(self, "handleRollBegan: roll=\(payload.rollIndex) held=\(payload.heldMask) seed=\(payload.recipe.seed) hookWired=\(onRollBegan != nil)")
        spectatorRollInProgress = true
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
        spectatorRollInProgress = false
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

    // MARK: - Match history sync

    private func broadcastHistoryManifest() {
        guard let ids = onHistoryManifestNeeded?(), !ids.isEmpty else { return }
        session.send(.historyManifest, payload: HistoryManifestPayload(matchIDs: ids))
        logger.info(self, "history sync: broadcasting manifest count=\(ids.count)")
    }

    private func handleHistoryManifest(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HistoryManifestPayload.self) else { return }
        let localIDs = Set(onHistoryManifestNeeded?() ?? [])
        let missing = payload.matchIDs.filter { !localIDs.contains($0) }
        guard !missing.isEmpty else {
            logger.debug(self, "history sync: peer manifest count=\(payload.matchIDs.count), none missing locally")
            return
        }
        logger.info(self, "history sync: peer has \(payload.matchIDs.count) match(es), requesting \(missing.count) missing")
        session.send(.historyRequest, payload: HistoryRequestPayload(matchIDs: missing))
    }

    private func handleHistoryRequest(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HistoryRequestPayload.self),
              let fetcher = onHistoryMatchesNeeded else { return }
        let matches = fetcher(payload.matchIDs)
        guard !matches.isEmpty else { return }
        logger.info(self, "history sync: fulfilling request for \(payload.matchIDs.count) ID(s) with \(matches.count) match(es)")
        session.send(.historyResponse, payload: HistoryResponsePayload(matches: matches))
    }

    private func handleHistoryResponse(_ envelope: GameNightEnvelope) {
        guard let payload = try? envelope.decode(HistoryResponsePayload.self),
              !payload.matches.isEmpty else { return }
        logger.info(self, "history sync: received \(payload.matches.count) match(es) from peer")
        onHistoryMatchesReceived?(payload.matches)
    }

    // MARK: - Helpers

    private func persistLocalParticipantID() {
        guard let pid = localParticipantID, let mid = sessionMatchID else { return }
        session.setGnParticipantID(pid, for: mid)
    }

    private func buildInitialMatch(gameID: UUID) -> (Match, [SeatMapping]) {
        var mappings: [SeatMapping] = []
        let participants: [SyLibScoring.Participant] = seats.enumerated().map { index, seat in
            let participantID = UUID()
            mappings.append(SeatMapping(seatClaimID: seat.seatClaimID, participantID: participantID))
            return SyLibScoring.Participant(
                id: participantID,
                seat: index,
                finalScore: 0,
                rank: 0,
                bonusPoints: 0,
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

    // MARK: - Controller-layer teardown

    private func performControllerTearDown() {
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
        onUndoApplied = nil
        onHistoryManifestNeeded = nil
        onHistoryMatchesNeeded = nil
        onHistoryMatchesReceived = nil
        pendingGuestUndoAvailable = false
        pendingHostUndoAvailable = false
        spectatorRollInProgress = false
        localParticipantID = nil
        detachMatchController()
    }
}
