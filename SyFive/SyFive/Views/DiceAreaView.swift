import SwiftUI
import Observation
import RealityKit

struct DiceAreaView: View {
    @Bindable var model: MatchController
    @State private var diceRoller = DiceRoller()
    @State private var feelAdapter: DiceFeelAdapter?
    @State private var traySize: CGSize = .zero
    @State private var suppressNextPlayerChangeDiceClear = false
    @State private var isAwaitingInitialTurnStart = false
    @Environment(FeelDirector.self) private var director
    @Environment(CelebrationCoordinator.self) private var celebrationCoordinator
    @Environment(GameNightController.self) private var gameNight
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(UserDefaults.Key.theaterAudioEnabled) private var theaterAudioEnabled: Bool = false
    private let rollControlHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            trayView
            rollControls
            #if DEBUG
            if AppConfig.DebugDice.showPhysicsSliders {
                physicsDebugPanel
            }
            if AppConfig.DebugDice.showHarness {
                DiceDebugHUD(diceRoller: diceRoller)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            if feelAdapter == nil {
                let adapter = DiceFeelAdapter(director: director)
                adapter.theaterAudioEnabled = theaterAudioEnabled
                feelAdapter = adapter
                diceRoller.audioController = adapter
            }
            diceRoller.keepScreenAwake = { UIApplication.shared.isIdleTimerDisabled = $0 }
            diceRoller.config.logDiagnostics = AppConfig.DebugDice.logRollDiagnostics
            diceRoller.config.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            if gameNight.isSessionActive {
                wireGameNightHooks()
            }
        }
        .onChange(of: gameNight.isSessionActive) { _, active in
            if active { wireGameNightHooks() }
        }
        .onChange(of: theaterAudioEnabled) { _, enabled in
            feelAdapter?.theaterAudioEnabled = enabled
        }
        .onChange(of: model.currentPlayerIndex) { _, _ in
            if suppressNextPlayerChangeDiceClear {
                suppressNextPlayerChangeDiceClear = false
                return
            }
            if let pending = diceRoller.pendingUndoRestore {
                diceRoller.pendingUndoRestore = nil
                diceRoller.restoreDice(values: pending, held: Array(repeating: false, count: pending.count))
                return
            }
            guard model.playerCount > 1 else { return }
            diceRoller.clearDice()
        }
        .onChange(of: model.hasStarted) { _, hasStarted in
            if !hasStarted {
                isAwaitingInitialTurnStart = false
                diceRoller.clearDice()
            }
        }
    }

    // MARK: - Subviews

    /// 3D RealityKit tray — square, fills available width dynamically.
    private var trayView: some View {
        Color.clear
            .overlay {
                DiceRKView(diceRoller: diceRoller)
                    .gesture(
                        SpatialTapGesture()
                            .targetedToAnyEntity()
                            .onEnded { value in
                                handleDiceTap(value.entity)
                            }
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                DiceTrayOverlayView(model: model)
            }
    }

    private var rollControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if shouldPrimeInitialTurn {
                        isAwaitingInitialTurnStart = true
                        diceRoller.clearDice()
                        return
                    }

                    if isAwaitingInitialTurnStart {
                        isAwaitingInitialTurnStart = false
                    }

                    model.beginRoll()
                    director.rollStarted(unheldCount: model.held.filter { !$0 }.count)
                    let capturedHeld = model.held
                    let gn = gameNight
                    let dr = diceRoller
                    // Notify watchers immediately so they can snap held dice to the row
                    // before the roll starts. lastRecipe is the previous roll's recipe;
                    // the recipe itself is ignored by watchers — only heldMask matters.
                    if gn.isSessionActive && gn.phase == .inProgress, let recipe = dr.lastRecipe {
                        gn.sendRollBegan(recipe: recipe, rollIndex: 0, heldMask: capturedHeld)
                    }
                    Task {
                        await dr.roll(held: capturedHeld) { values in
                            model.receiveDiceResults(values)
                            if gn.isSessionActive && gn.phase == .inProgress {
                                gn.sendRollResult(faceValues: values)
                            }
                            // Yatzy-moment predicate (D-052): all-same values + box nil or 50.
                            let isYatzy = !values.isEmpty && values.dropFirst().allSatisfy { $0 == values[0] }
                            let yahtzeeBox = model.scores(for: model.currentPlayerIndex)[.yahtzee]
                            if isYatzy && (yahtzeeBox == nil || yahtzeeBox == 50) {
                                director.yatzyMoment()
                                celebrationCoordinator.triggerYatzy(playerIndex: model.currentPlayerIndex)
                            }
                        }
                    }
                } label: {
                    Text(rollButtonTitle)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: rollControlHeight)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canRoll)

                if isUndoTurn {
                    Button {
                        suppressNextPlayerChangeDiceClear = true
                        if let restoration = model.undoLastScore() {
                            diceRoller.restoreDice(values: restoration.diceValues, held: restoration.held)
                        } else {
                            suppressNextPlayerChangeDiceClear = false
                        }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: rollControlHeight)
                            .frame(minHeight: rollControlHeight)
                    }
                    .buttonStyle(.bordered)
                    .tint(undoButtonTint)
                    .accessibilityLabel("Undo last score")
                }
            }

            VStack(spacing: 4) {
                if let stuckMessage = diceRoller.stuckDiceMessage, isLocalTurn {
                    Text(stuckMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if model.canScore {
                    Text("Choose a category to score")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !model.isGameOver && model.rollsRemaining == 0 {
                    Text("No rolls remaining — choose a category")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("M") // keep space for this row of text
                        .font(.footnote)
                        .foregroundColor(.clear)
                }

                proxyModeControls
            }
        }
    }

    @ViewBuilder
    private var proxyModeControls: some View {
        let names = model.playerDisplayNames
        let idx = model.currentPlayerIndex
        let name = names.indices.contains(idx) ? names[idx] : "player"

        if gameNight.isProxyMode && gameNight.role == .host {
            Text("Playing for \(name)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if gameNight.role == .host && gameNight.isSessionActive
                    && gameNight.phase == .inProgress && !isLocalTurn && !model.isGameOver {
            Button("Play for \(name)") {
                gameNight.enableProxyMode()
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Actions

    private func handleDiceTap(_ entity: Entity) {
        guard isLocalTurn, let diceIndex = diceRoller.index(of: entity) else { return }

        if diceRoller.hasStuckDice {
            guard diceRoller.isStuckDie(index: diceIndex) else { return }
            if diceRoller.isNudgeableDie(index: diceIndex) {
                // Yellow die — nudge attempt: apply a physics push and let it try to settle.
                director.dieNudged()
                diceRoller.nudgeStuckDie(at: diceIndex)
            } else {
                // Red die — nudge already failed, reroll from scratch.
                director.dieRerolled()
                Task {
                    await diceRoller.rerollStuckDie(at: diceIndex)
                }
            }
            return
        }

        guard model.canScore else { return }
        model.toggleHold(at: diceIndex)
        diceRoller.setHeld(model.held)
        let engaged = model.held.indices.contains(diceIndex) ? model.held[diceIndex] : false
        if gameNight.isSessionActive && gameNight.phase == .inProgress {
            gameNight.sendHoldToggled(dieIndex: diceIndex, isHeld: engaged)
        }
        director.holdToggled(engaged: engaged)
    }

    // MARK: - Game Night hooks

    private func wireGameNightHooks() {
        let gn = gameNight
        let dr = diceRoller
        let mc = model
        let cc = celebrationCoordinator

        // When a roll begins, keep held dice visible in the far-wall row and
        // hide the non-held dice. They reappear in pip-pattern when the result arrives.
        gn.onRollBegan = { _, heldMask in
            dr.prepareForSpectatorRoll(held: heldMask)
        }
        // Show settled values: held dice in the far-wall row, non-held in the pip
        // pattern matching the count. Uses currentHeld — kept accurate by onHoldToggled.
        gn.onRollResult = { values in
            dr.displaySpectatorResult(values: values, held: dr.currentHeld)
            let isYatzy = !values.isEmpty && values.dropFirst().allSatisfy { $0 == values[0] }
            guard isYatzy else { return }
            let yahtzeeBox = mc.scores(for: mc.currentPlayerIndex)[.yahtzee]
            guard yahtzeeBox == nil || yahtzeeBox == 50 else { return }
            cc.triggerYatzy(playerIndex: mc.currentPlayerIndex)
        }
        gn.onHoldToggled = { dieIndex, isHeld in
            var held = dr.currentHeld
            if held.indices.contains(dieIndex) { held[dieIndex] = isHeld }
            dr.setHeld(held)
        }
        gn.onUndoWithDice = { values in
            // Store in the DiceRoller reference so the onChange(of: currentPlayerIndex)
            // handler (which fires after loadFromGameNightMatch changes the index) can
            // restore rather than clear.
            dr.pendingUndoRestore = values
        }
    }

    // MARK: - Helpers

    private var isUndoTurn: Bool {
        if gameNight.isSessionActive, gameNight.phase == .inProgress {
            if gameNight.role == .spectator { return false }
            return gameNight.role == .host
                ? gameNight.pendingHostUndoAvailable
                : gameNight.pendingGuestUndoAvailable
        }
        return model.undoPlayerIndex != nil
    }

    private var isLocalTurn: Bool {
        // Pre-reconnect: participant ID was restored from UserDefaults — use it
        // so the scorecard highlights the correct player while waiting.
        if gameNight.isGuestAwaitingReconnect,
           let localID = gameNight.localParticipantID {
            let ids = model.participantIDs
            guard model.currentPlayerIndex < ids.count else { return false }
            return ids[model.currentPlayerIndex] == localID
        }
        guard gameNight.isSessionActive, gameNight.phase == .inProgress else { return true }
        // Host in proxy mode rolls and scores on behalf of a dropped player (D-121).
        if gameNight.isProxyMode && gameNight.role == .host { return true }
        guard let localID = gameNight.localParticipantID else { return false }
        let ids = model.participantIDs
        guard model.currentPlayerIndex < ids.count else { return true }
        return ids[model.currentPlayerIndex] == localID
    }

    private var canRoll: Bool {
        guard !gameNight.isGuestAwaitingReconnect else { return false }
        return model.playerCount > 0 && isLocalTurn && model.rollsRemaining > 0 && !model.isGameOver && !model.isRolling
    }

    private var shouldPrimeInitialTurn: Bool {
        // Never prime in Game Night — the match is already underway when the guest arrives.
        guard !gameNight.isSessionActive else { return false }
        return !model.hasStarted && model.playerCount > 1 && !isAwaitingInitialTurnStart
    }

    private var rollButtonTitle: String {
        if gameNight.isGuestAwaitingReconnect {
            return "Waiting for Game Night…"
        }
        if gameNight.isSessionActive, gameNight.phase == .inProgress, !isLocalTurn {
            let names = model.playerDisplayNames
            guard model.currentPlayerIndex < names.count else { return "Waiting…" }
            return "Waiting for \(names[model.currentPlayerIndex])…"
        }
        if isAwaitingInitialTurnStart {
            return "Start Turn"
        }
        if !model.hasStarted {
            if model.playerCount == 0 { return "Add players to begin" }
            // In Game Night the match is already live — skip the "Start game" label.
            if gameNight.isSessionActive { return "Start Turn" }
            return model.playerCount == 1
                ? "Start game with 1 player"
                : "Start game with \(model.playerCount) players"
        }
        if model.isRolling { return "Rolling…" }
        if model.rollsRemaining == 3 { return "Start Turn" }
        return model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "No rolls remaining"
    }

    private var undoButtonTint: Color {
        guard let undoThemeType = model.undoThemeType else { return .accentColor }
        return Theme(type: undoThemeType, colorScheme: colorScheme).primaryAccent
    }

    // MARK: - Debug

    #if DEBUG
    /// Physics tuning sliders — only visible when `AppConfig.DebugDice.showPhysicsSliders == true`.
    private var physicsDebugPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Physics Tuning")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Group {
                debugSlider(
                    label: "Impulse max \(String(format: "%.2f", diceRoller.config.impulseMax))",
                    value: Binding(
                        get: { diceRoller.config.impulseMax },
                        set: { diceRoller.config.impulseMax = $0 }
                    ),
                    in: 0.03...0.25
                )
                debugSlider(
                    label: "Torque max \(String(format: "%.2f", diceRoller.config.torqueMax))",
                    value: Binding(
                        get: { diceRoller.config.torqueMax },
                        set: { diceRoller.config.torqueMax = $0 }
                    ),
                    in: 0.02...0.35
                )
                debugSlider(
                    label: "Cone angle \(String(format: "%.0f°", diceRoller.config.coneHalfAngle * 180 / .pi))",
                    value: Binding(
                        get: { diceRoller.config.coneHalfAngle },
                        set: { diceRoller.config.coneHalfAngle = $0 }
                    ),
                    in: 0.1...1.2
                )
                debugSlider(
                    label: "Spawn jitter \(String(format: "%.3f", diceRoller.config.spawnJitter))",
                    value: Binding(
                        get: { diceRoller.config.spawnJitter },
                        set: { diceRoller.config.spawnJitter = $0 }
                    ),
                    in: 0...0.04
                )
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
    }

    private func debugSlider(label: String, value: Binding<Float>, in range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
    }
    #endif

}

#Preview {
    DiceAreaView(model: MatchController())
}
