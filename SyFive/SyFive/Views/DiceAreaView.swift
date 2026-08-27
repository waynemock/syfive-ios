import SwiftUI
import SyLibCore
import SyLibDice
import SyLibFeel
import SyLibGameNight
import SyLibScoring
import Observation
import UIKit

extension Theme {
    var dicePalette: DiceTintPalette {
        DiceTintPalette(
            normal: UIColor(primaryAccent),
            held: UIColor(heldAccent),
            nudgeable: UIColor(stuckColor),
            stuck: UIColor(errorColor),
            pip: UIColor(pipColor),
            heldPip: UIColor(heldPipColor)
        )
    }
}

struct DiceAreaView: View {
    @Bindable var model: MatchController
    var onPlayAgain: () -> Void = {}
    @State private var diceRoller = DiceRoller()
    @State private var feelAdapter: DiceFeelAdapter?
    @State private var suppressNextPlayerChangeDiceClear = false
    @State private var isAwaitingInitialTurnStart = false
    @Environment(FeelDirector.self) private var director
    @Environment(CelebrationCoordinator.self) private var celebrationCoordinator
    @Environment(GameNightController.self) private var gameNight
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    private let rollControlHeight: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            DiceTrayView(
                roller: diceRoller,
                palette: theme.dicePalette,
                backgroundColor: theme.backgroundColor,
                isInteractive: isLocalTurn,
                canToggleHold: model.canScore,
                showHoldHint: showHoldHint,
                onHoldToggled: { index in
                    model.toggleHold(at: index)
                    diceRoller.setHeld(model.held)
                    let engaged = model.held.indices.contains(index) ? model.held[index] : false
                    if gameNight.isSessionActive && gameNight.phase == .inProgress {
                        gameNight.sendHoldToggled(dieIndex: index, isHeld: engaged)
                    }
                    director.holdToggled(engaged: engaged)
                },
                onNudge:  { director.dieNudged() },
                onReroll: { director.dieRerolled() }
            ) {
                DiceTrayOverlayView(model: model)
            }
            rollControls
            #if DEBUG
            if AppConfig.DebugDice.showPhysicsSliders {
                PhysicsTuningPanel(roller: diceRoller)
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
                feelAdapter = adapter
                diceRoller.audioController = adapter
            }
            diceRoller.keepScreenAwake = { UIApplication.shared.isIdleTimerDisabled = $0 }
            diceRoller.config.logDiagnostics = AppConfig.DebugDice.logRollDiagnostics
            diceRoller.config.appVersion = Bundle.main.appVersionShort
            if gameNight.isSessionActive {
                wireGameNightHooks()
            }
        }
        .onChange(of: gameNight.isSessionActive) { _, active in
            if active { wireGameNightHooks() }
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

    private var rollControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if isPlayAgainButton {
                        onPlayAgain()
                        return
                    }

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
                            let yatzyBox = model.scores(for: model.currentPlayerIndex)[.yatzy]
                            if isYatzy && (yatzyBox == nil || yatzyBox == 50) {
                                director.celebration()
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
                        if gameNight.isSessionActive && gameNight.phase == .inProgress && gameNight.role != .host {
                            // Guest: propose undo to host before any local state changes —
                            // undoLastScore() clears lastScoreSnapshot, making undoPlayerIndex nil
                            // and causing proposeUndo() to fail its guard silently.
                            gameNight.proposeUndo()
                        } else {
                            suppressNextPlayerChangeDiceClear = true
                            if let restoration = model.undoLastScore() {
                                diceRoller.restoreDice(values: restoration.diceValues, held: restoration.held)
                            } else {
                                suppressNextPlayerChangeDiceClear = false
                            }
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

    // MARK: - Game Night hooks

    private func wireGameNightHooks() {
        let gn = gameNight
        let dr = diceRoller
        let mc = model
        let cc = celebrationCoordinator
        let fa = feelAdapter
        let dir = director

        // When a roll begins, keep held dice visible in the far-wall row and
        // hide the non-held dice. They reappear in pip-pattern when the result arrives.
        gn.onRollBegan = { _, heldMask in
            dr.prepareForSpectatorRoll(held: heldMask)
            cc.clearAll()
        }
        // Show settled values: held dice in the far-wall row, non-held in the pip
        // pattern matching the count. Uses currentHeld — kept accurate by onHoldToggled.
        gn.onRollResult = { values in
            // First roll of a turn sends rollResult only (no preceding rollBegan),
            // so clear here too. Idempotent if onRollBegan already cleared it.
            cc.clearAll()
            dr.displaySpectatorResult(values: values, held: dr.currentHeld)
            fa?.onAllDiceSettled(values: values)
            let isYatzy = !values.isEmpty && values.dropFirst().allSatisfy { $0 == values[0] }
            guard isYatzy else { return }
            let yatzyBox = mc.scores(for: mc.currentPlayerIndex)[.yatzy]
            guard yatzyBox == nil || yatzyBox == 50 else { return }
            dir.celebration()
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
        if gameNight.session.isGuestAwaitingReconnect,
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

    private var allDiceHeld: Bool {
        model.canScore && !model.held.isEmpty && model.held.allSatisfy { $0 }
    }

    private var showHoldHint: Bool {
        model.rollsRemaining < 3
            && model.rollsRemaining > 0
            && model.held.filter { $0 }.count < 5
    }

    private var isPlayAgainButton: Bool {
        model.isGameOver
    }

    private var canRoll: Bool {
        if isPlayAgainButton {
            return !gameNight.isSessionActive || gameNight.role == .host
        }
        guard !gameNight.session.isGuestAwaitingReconnect else { return false }
        return model.playerCount > 0 && isLocalTurn && model.rollsRemaining > 0 && !model.isGameOver && !model.isRolling && !allDiceHeld
    }

    private var shouldPrimeInitialTurn: Bool {
        // Never prime in Game Night — the match is already underway when the guest arrives.
        guard !gameNight.isSessionActive else { return false }
        return !model.hasStarted && model.playerCount > 1 && !isAwaitingInitialTurnStart
    }

    private var rollButtonTitle: String {
        if isPlayAgainButton {
            if gameNight.isSessionActive && gameNight.role != .host {
                return "Waiting for host…"
            }
            return "Play Again"
        }
        if gameNight.session.isGuestAwaitingReconnect {
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
        if allDiceHeld { return "Release a die to roll" }
        if model.rollsRemaining == 3 { return "Start Turn" }
        return model.rollsRemaining > 0 ? "Roll (\(model.rollsRemaining) left)" : "No rolls remaining"
    }

    private var undoButtonTint: Color {
        guard let undoThemeType = model.undoThemeType else { return .accentColor }
        return Theme(type: undoThemeType, colorScheme: colorScheme).primaryAccent
    }

}

#Preview {
    DiceAreaView(model: MatchController())
        .environment(FeelDirector(catalog: .syFive))
        .environment(CelebrationCoordinator())
        .environment(GameNightController())
}
