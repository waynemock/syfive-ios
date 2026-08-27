import AVFoundation
import Combine
import Foundation
import GroupActivities
import SyLibCore

/// Session and transport layer for Game Night. Owns the GroupActivities session,
/// the messenger, role assignment, seat management, and all session-level message
/// handling (hello, tableState, seatClaim, seatRelease).
///
/// Non-session message kinds are forwarded to `GameNightController` via `onAppMessage`.
/// `GameNightController` holds a `GameNightSession` and remains the type views bind to.
@MainActor
@Observable
final class GameNightSession {

    // MARK: - Observable state

    /// Settable by controller: handleMatchStart sets .spectator; configureSession sets .host/.guest.
    var role: GameNightController.Role = .guest
    /// Settable by controller: match lifecycle methods set .inProgress/.completed etc.
    var phase: GameNightPhase = .settingTable
    /// Settable by controller: resumeAsHost rebuilds the seat list from match state.
    var seats: [SeatSnapshot] = []
    private(set) var isSessionActive = false
    private(set) var sessionActivationCount: Int = 0
    private(set) var isSessionPending = false
    private(set) var isEligibleForGroupSession = false
    /// Settable by controller: handleMatchStart may restore localSeatClaimID from a pending claim.
    var localSeatClaimID: UUID?
    /// Settable by controller: handleMatchAbandoned sets this after teardown clears it.
    var sessionEndedDuringPlay = false
    /// Settable by controller: prepareForGuestReconnect sets this; tearDownSession clears it.
    var isGuestAwaitingReconnect = false
    private(set) var versionMismatchedCount: Int = 0
    private(set) var lastMismatchedProtocolVersion: Int?
    private(set) var hostVersionMismatch: Int?

    /// Opaque app-scoped table settings, echoed verbatim in `tableState`.
    ///
    /// The session stores and transmits these but never interprets them — it holds
    /// them only so `broadcastTableState()` can compose the whole payload without a
    /// round-trip to the controller. Defaults are supplied by `GameNightController`
    /// at init; the session deliberately has no opinion about what a commentary pack
    /// or level is.
    ///
    /// Known Phase 1 wart: `TableStatePayload` mixes session fields (phase, seats)
    /// with app fields (these three). Phase 2 splits the payload and removes them
    /// from the session entirely. Do not add further app fields here in the meantime.
    ///
    /// `GameNightController` exposes read/write pass-throughs so views can bind
    /// (e.g. `$gameNight.commentaryEnabled`).
    var commentaryEnabled: Bool = false
    var commentaryPackID: String = ""
    var commentaryLevelRaw: String = ""

    // MARK: - Routing callbacks

    /// Non-session message kinds forwarded here. Controller installs its match-layer handler.
    var onAppMessage: ((GameNightMessageKind, GameNightEnvelope, UUID) -> Void)?

    /// Fired at the end of tearDownSession() so the controller can clear match-layer hooks.
    var onTearDown: (() -> Void)?

    /// Fired after the session applies phase/seats from an incoming tableState, so the
    /// controller can read mixed-payload fields (e.g. commentary settings) and fire its own hooks.
    /// Known wart: `TableStatePayload` is mixed (session fields + controller fields) and stays
    /// whole until Phase 2. The controller decodes only what it needs from the envelope.
    var onTableStateReceived: ((GameNightEnvelope) -> Void)?

    /// Fired in handleHello when phase == .inProgress so the controller can broadcast matchState.
    var onNeedsMatchStateBroadcast: (() -> Void)?

    // MARK: - Private session internals

    private var session: GroupSession<GameNightActivity>?
    private var messenger: GroupSessionMessenger?
    private var messageListenTask: Task<Void, Never>?
    private var pendingHostSessionActivation = false
    private var versionMismatchedIDs: Set<UUID> = []
    private let groupStateObserver = GroupStateObserver()
    private let logger = AppLogger(category: "GameNightSession")

    // MARK: - Audio interruption

    private(set) var isAudioInterrupted = false
    private var sessionDroppedDuringInterruption = false
    private var interruptionRecoveryTask: Task<Void, Never>?

    // MARK: - Seat state

    /// Settable by controller: handleMatchStart reads and clears this.
    var pendingSeatClaim: SeatClaimPayload? = nil
    private var versionMismatchTimeoutTask: Task<Void, Never>?

    // MARK: - Init

    let keyPrefix: String

    init(keyPrefix: String) {
        self.keyPrefix = keyPrefix
    }

    // MARK: - UserDefaults key access
    // Key format: "\(keyPrefix).gn.{suffix}.{uuid}" — byte-identical to pre-T3 hardcoded "syfive" prefix.

    func gnIsHost(for sessionID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "\(keyPrefix).gn.host.\(sessionID.uuidString)")
    }
    func setGnIsHost(for sessionID: UUID) {
        UserDefaults.standard.set(true, forKey: "\(keyPrefix).gn.host.\(sessionID.uuidString)")
    }
    func removeGnIsHost(for sessionID: UUID) {
        UserDefaults.standard.removeObject(forKey: "\(keyPrefix).gn.host.\(sessionID.uuidString)")
    }
    func gnParticipantID(for matchID: UUID) -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: "\(keyPrefix).gn.participantID.\(matchID.uuidString)") else { return nil }
        return UUID(uuidString: str)
    }
    func setGnParticipantID(_ pid: UUID, for matchID: UUID) {
        UserDefaults.standard.set(pid.uuidString, forKey: "\(keyPrefix).gn.participantID.\(matchID.uuidString)")
    }
    func gnWasHost(for matchID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: "\(keyPrefix).gn.wasHost.\(matchID.uuidString)")
    }
    func setGnWasHost(for matchID: UUID) {
        UserDefaults.standard.set(true, forKey: "\(keyPrefix).gn.wasHost.\(matchID.uuidString)")
    }

    // MARK: - App-launch entry point

    /// Called by SyFiveApp via `.task` on the root ContentView. Running the for-await
    /// loop inside a structured `.task` ties it to the scene lifecycle, which lets iOS
    /// route Messages-based SharePlay sessions back to the sender's device. An unstructured
    /// Task {} in onAppear is not associated with any scene and silently drops those deliveries.
    func listenForSessions() async {
        logger.info(self, "listenForSessions: scene-level task started, awaiting sessions")
        startObservingAudioInterruptions()
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

    // MARK: - Session configuration

    func configureSession(_ incomingSession: GroupSession<GameNightActivity>) {
        logger.info(self, "configureSession: entry id=\(incomingSession.id) state=\(String(describing: incomingSession.state)) pendingHostActivation=\(pendingHostSessionActivation) existingSessionID=\(session?.id.uuidString ?? "nil")")

        if session?.id == incomingSession.id {
            logger.warning(self, "configureSession: duplicate session id, skipping")
            return
        }

        let persistedAsHost = gnIsHost(for: incomingSession.id)
        let takingHostRole = pendingHostSessionActivation || persistedAsHost
        pendingHostSessionActivation = false
        if takingHostRole {
            setGnIsHost(for: incomingSession.id)
        }

        logger.info(self, "configureSession: takingHostRole=\(takingHostRole), calling tearDownSession")
        if isAudioInterrupted || sessionDroppedDuringInterruption {
            cancelInterruptionRecovery()
            logger.info(self, "configureSession: session recovered after audio interruption")
        }
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
            Task { await self.broadcastTableState() }
        } else {
            Task { await self.sendHello() }
            versionMismatchTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard let self, !Task.isCancelled,
                      self.isSessionActive,
                      self.phase == .settingTable,
                      self.hostVersionMismatch == nil else { return }
                self.hostVersionMismatch = 0
                self.logger.info(self, "configureSession: no compatible tableState after 10 s — surfacing version mismatch alert")
            }
        }
        isGuestAwaitingReconnect = false
        sessionActivationCount += 1
        GameNightLogBuffer.shared.startSession()
        logger.info(self, "configureSession: *** COMPLETE *** role=\(String(describing: role)) activationCount=\(sessionActivationCount)")
    }

    // MARK: - Session teardown

    func endSession() {
        cancelInterruptionRecovery()
        tearDownSession()
    }

    /// Guest-only: releases this device's seat without ending the session for others.
    /// Note: localParticipantID is on GameNightController and is cleared by its leaveSession() wrapper.
    func leaveSession() {
        if let claimID = localSeatClaimID {
            send(.seatRelease, payload: SeatReleasePayload(seatClaimID: claimID))
        }
        localSeatClaimID = nil
    }

    func playAgain() {
        guard role == .host, phase == .completed, !seats.isEmpty else { return }
        phase = .settingTable
        Task { await broadcastTableState() }
    }

    func abandonSession() {
        guard role == .host, isSessionActive else { return }
        cancelInterruptionRecovery()
        send(.matchAbandoned, payload: MatchAbandonedPayload())
        tearDownSession()
    }

    func clearSessionEndedFlag() {
        sessionEndedDuringPlay = false
    }

    func clearHostVersionMismatch() {
        hostVersionMismatch = nil
    }

    // MARK: - Audio interruption (private)

    private func startObservingAudioInterruptions() {
        Task { @MainActor [weak self] in
            let notifications = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance()
            )
            for await notification in notifications {
                self?.handleAudioInterruption(notification)
            }
        }
    }

    private func handleAudioInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            guard isSessionActive || phase == .inProgress else { return }
            interruptionRecoveryTask?.cancel()
            interruptionRecoveryTask = nil
            isAudioInterrupted = true
            logger.info(self, "audioInterruption: began — holding session-ended alert")

        case .ended:
            guard isAudioInterrupted else { return }
            logger.info(self, "audioInterruption: ended — waiting up to 6 s for session recovery")
            interruptionRecoveryTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(6))
                guard let self, !Task.isCancelled else { return }
                self.isAudioInterrupted = false
                if self.sessionDroppedDuringInterruption {
                    self.sessionDroppedDuringInterruption = false
                    self.sessionEndedDuringPlay = true
                    self.logger.info(self, "audioInterruption: session did not recover — surfacing reconnect alert")
                }
            }

        @unknown default:
            break
        }
    }

    private func cancelInterruptionRecovery() {
        interruptionRecoveryTask?.cancel()
        interruptionRecoveryTask = nil
        isAudioInterrupted = false
        sessionDroppedDuringInterruption = false
    }

    // MARK: - Session teardown

    /// Internal (not private) so GameNightController can call teardown without also cancelling
    /// the audio interruption recovery window. User-initiated teardowns (endSession, abandonSession)
    /// call cancelInterruptionRecovery() first; host-abandoned teardown (handleMatchAbandoned) does not.
    func tearDownSession() {
        GameNightLogBuffer.shared.flushToDisk()
        logger.info(self, "tearDownSession: role=\(String(describing: role)) phase=\(phase.rawValue) isSessionActive=\(isSessionActive)")
        pendingHostSessionActivation = false
        isSessionPending = false
        messageListenTask?.cancel()
        messageListenTask = nil
        // Captured before session is cleared — reading session?.id after nil-ing would return nil
        // and the host flag would leak, causing stale auto-promotion on the next join. (Inventory 2.2)
        if let id = session?.id {
            removeGnIsHost(for: id)
        }
        session?.end()
        session = nil
        messenger = nil
        isSessionActive = false
        seats = []
        phase = .settingTable
        versionMismatchedIDs = []
        versionMismatchedCount = 0
        lastMismatchedProtocolVersion = nil
        hostVersionMismatch = nil
        versionMismatchTimeoutTask?.cancel()
        versionMismatchTimeoutTask = nil
        localSeatClaimID = nil
        pendingSeatClaim = nil
        isGuestAwaitingReconnect = false
        isAudioInterrupted = false
        sessionDroppedDuringInterruption = false
        // interruptionRecoveryTask is intentionally NOT cancelled here.
        // It is managed by cancelInterruptionRecovery(), which is called from
        // configureSession() (session came back) and user-initiated teardowns.
        // commentaryEnabled/PackID/LevelRaw are deliberately NOT reset. They are the
        // host's session-scoped preference and should carry into the next Game Night
        // rather than silently reverting to defaults. Not an omission.
        onTearDown?()
    }

    // MARK: - Table state broadcast

    func broadcastTableState() async {
        guard role == .host else { return }
        send(.tableState, payload: TableStatePayload(
            phase: phase,
            seats: seats,
            commentaryEnabled: commentaryEnabled,
            commentaryPackID: commentaryPackID,
            commentaryLevelRaw: commentaryLevelRaw,
            protocolVersion: GameNightEnvelope.currentProtocolVersion
        ))
    }

    // MARK: - Message receive loop (private)

    private func listenForMessages(messenger: GroupSessionMessenger) async {
        for await (envelope, context) in messenger.messages(of: GameNightEnvelope.self) {
            handle(envelope, from: context.source.id)
        }
        // Loop exits when the session is invalidated. If we didn't cancel this task
        // (i.e. the session dropped rather than the user leaving), show the reconnect alert —
        // unless the drop was caused by an audio interruption, in which case we defer
        // for up to 6 seconds to let SharePlay redeliver the session first.
        guard !Task.isCancelled, isSessionActive else { return }
        let wasInProgress = phase == .inProgress
        let droppedDuringInterruption = isAudioInterrupted && wasInProgress
        logger.info(self, "listenForMessages: session dropped — wasInProgress=\(wasInProgress) droppedDuringInterruption=\(droppedDuringInterruption) role=\(String(describing: role))")
        tearDownSession()
        if droppedDuringInterruption {
            // Re-set after tearDown (which clears it) so the recovery task can check it.
            sessionDroppedDuringInterruption = true
            logger.info(self, "listenForMessages: session dropped during audio interruption — deferring reconnect alert")
        } else if wasInProgress {
            logger.info(self, "listenForMessages: unexpected drop during play — surfacing reconnect alert")
            sessionEndedDuringPlay = true
        }
    }

    // MARK: - Message routing (private)

    private func handle(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard let kind = envelope.messageKind else { return }
        switch kind {
        case .hello:       handleHello(envelope, from: senderID)
        case .tableState:  handleTableState(envelope)
        case .seatClaim:   handleSeatClaim(envelope, from: senderID)
        case .seatRelease: handleSeatRelease(envelope)
        default:           onAppMessage?(kind, envelope, senderID)
        }
    }

    // MARK: - Session-layer handlers (private)

    private func handleHello(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard let payload = try? envelope.decode(HelloPayload.self) else { return }
        guard payload.protocolVersion == GameNightEnvelope.currentProtocolVersion else {
            logger.info(self, "Version mismatch from \(senderID): v\(payload.protocolVersion)")
            versionMismatchedIDs.insert(senderID)
            versionMismatchedCount = versionMismatchedIDs.count
            lastMismatchedProtocolVersion = payload.protocolVersion
            return
        }
        logger.info(self, "handleHello: v\(payload.protocolVersion) appV=\(payload.appVersion) from=\(senderID) — sending catch-up phase=\(phase.rawValue)")
        if role == .host {
            Task {
                await self.broadcastTableState()
                if self.phase == .inProgress { self.onNeedsMatchStateBroadcast?() }
            }
        }
    }

    private func handleTableState(_ envelope: GameNightEnvelope) {
        guard role != .host,
              let payload = try? envelope.decode(TableStatePayload.self) else { return }
        let hostVersion = payload.protocolVersion ?? 1
        if hostVersion != GameNightEnvelope.currentProtocolVersion {
            hostVersionMismatch = hostVersion
            versionMismatchTimeoutTask?.cancel()
            versionMismatchTimeoutTask = nil
            logger.info(self, "handleTableState: version mismatch hostVersion=\(hostVersion) ours=\(GameNightEnvelope.currentProtocolVersion)")
            return
        }
        hostVersionMismatch = nil
        versionMismatchTimeoutTask?.cancel()
        versionMismatchTimeoutTask = nil
        phase = payload.phase
        seats = payload.seats
        commentaryEnabled = payload.commentaryEnabled
        commentaryPackID = payload.commentaryPackID
        commentaryLevelRaw = payload.commentaryLevelRaw
        // If the host removed our seat, clear the local claim so the Claim button reappears.
        if let claimID = localSeatClaimID, !seats.contains(where: { $0.seatClaimID == claimID }) {
            localSeatClaimID = nil
        }
        // If we have a pending claim, check whether the host has now acknowledged it.
        if let pending = pendingSeatClaim {
            if seats.contains(where: { $0.seatClaimID == pending.seatClaimID }) {
                logger.debug(self, "tableState: pendingSeatClaim acknowledged by host — clearing, restoring localSeatClaimID")
                localSeatClaimID = pending.seatClaimID
                pendingSeatClaim = nil
            } else if phase == .settingTable {
                logger.info(self, "tableState: pendingSeatClaim not in seats — resending claim for '\(pending.displayName)'")
                addSeat(from: pending)
                send(.seatClaim, payload: pending)
            }
        }
        onTableStateReceived?(envelope)
        logger.debug(self, "tableState received: \(seats.count) seats, phase=\(payload.phase.rawValue)")
    }

    private func handleSeatClaim(_ envelope: GameNightEnvelope, from senderID: UUID) {
        guard role == .host, phase == .settingTable else { return }
        guard !versionMismatchedIDs.contains(senderID) else {
            logger.info(self, "Declining seatClaim from version-mismatched sender \(senderID)")
            return
        }
        guard let payload = try? envelope.decode(SeatClaimPayload.self) else { return }
        logger.info(self, "handleSeatClaim: '\(payload.displayName)' accepted totalSeats=\(seats.count + 1)")
        addSeat(from: payload)
        Task { await self.broadcastTableState() }
    }

    private func handleSeatRelease(_ envelope: GameNightEnvelope) {
        guard role == .host, phase == .settingTable else { return }
        guard let payload = try? envelope.decode(SeatReleasePayload.self) else { return }
        logger.info(self, "handleSeatRelease: claimID=\(payload.seatClaimID) remainingSeats=\(seats.count - 1)")
        removeSeat(seatClaimID: payload.seatClaimID)
    }

    // MARK: - Send helper

    func send<P: Encodable>(_ kind: GameNightMessageKind, payload: P) {
        guard let messenger else { return }
        do {
            let envelope = try GameNightEnvelope(kind: kind, payload: payload)
            logger.verbose(self, "send: \(kind.rawValue)")
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

    // MARK: - Seating

    func claimSeat(displayName: String, displayInitials: String, themeID: String, playerID: UUID?, isLocal: Bool = false) {
        logger.info(self, "claimSeat: '\(displayName)' role=\(String(describing: role)) playerID=\(playerID?.uuidString ?? "nil")")
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
            pendingSeatClaim = payload
            // Show own seat immediately — in Messages SharePlay the host may not have
            // joined yet, so no tableState will arrive to confirm the claim for a while.
            addSeat(from: payload)
            send(.seatClaim, payload: payload)
        }
    }

    func updateOwnSeat(name: String, initials: String, themeID: String) {
        guard phase == .settingTable, let claimID = localSeatClaimID,
              let i = seats.firstIndex(where: { $0.seatClaimID == claimID }) else { return }
        seats[i].displayName = name
        seats[i].displayInitials = initials
        seats[i].displayThemeID = themeID
        let payload = SeatClaimPayload(
            seatClaimID: claimID,
            playerID: seats[i].playerID,
            displayName: name,
            displayInitials: initials,
            displayThemeID: themeID,
            isLocal: seats[i].isLocal
        )
        if pendingSeatClaim != nil { pendingSeatClaim = payload }
        if role == .host {
            Task { await self.broadcastTableState() }
        } else {
            send(.seatClaim, payload: payload)
        }
        logger.info(self, "updateOwnSeat: '\(name)' themeID=\(themeID)")
    }

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

    func removeSeat(seatClaimID: UUID) {
        guard role == .host, phase == .settingTable else { return }
        if let seat = seats.first(where: { $0.seatClaimID == seatClaimID }) {
            logger.info(self, "removeSeat: '\(seat.displayName)' remainingSeats=\(seats.count - 1)")
        }
        if localSeatClaimID == seatClaimID { localSeatClaimID = nil }
        seats.removeAll { $0.seatClaimID == seatClaimID }
        for i in seats.indices { seats[i].seat = i }
        Task { await self.broadcastTableState() }
    }

    private func addSeat(from payload: SeatClaimPayload) {
        if let i = seats.firstIndex(where: { $0.seatClaimID == payload.seatClaimID }) {
            seats[i].displayName = payload.displayName
            seats[i].displayInitials = payload.displayInitials
            seats[i].displayThemeID = payload.displayThemeID
            logger.debug(self, "addSeat: updated '\(payload.displayName)' (upsert)")
            return
        }
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
        logger.debug(self, "addSeat: '\(payload.displayName)' totalSeats=\(seats.count)")
    }
}
