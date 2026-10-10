import SwiftUI
import AVFoundation
import SyLibCommentary
import SyLibFeel
import SyLibGameNight
import SyLibScoring

extension ContentView {

    /// True when this device's commentary engine should be silenced.
    /// ORs the global sound setting with the proximity/manual suppression state so
    /// both paths resolve consistently (§5.3). Never re-runs syncCommentaryEngine().
    var shouldMuteCommentary: Bool {
        director.soundMode == .off || gameNight.commentaryIsSuppressed
    }

    /// Called from onChange(of: appSettings?.soundModeRaw).
    /// Updates the sound mode, handles §5.4 suppression reset, and applies the mute directly.
    func handleSoundModeChanged() {
        let wasOff = director.soundMode == .off
        director.soundMode = appSettings?.soundMode ?? .mix
        let isNowOff = director.soundMode == .off
        if wasOff && !isNowOff {
            // §5.4: button reappears unmuted — reset suppression state (D-GNP-009).
            gameNight.setCommentarySuppressed(false)
        }
        applyCommentaryMute()
    }

    /// Called from `gameNight.onCommentarySuppressedChanged`: the commentary button, proximity
    /// muting a guest when ranging begins, or its verdict or timeout unmuting it.
    /// Applies the mute through applyCommentaryMute(), so a change to muted cuts the line in
    /// flight (D-132). Must not re-run syncCommentaryEngine() (§5.3).
    func handleCommentarySuppressionChanged() {
        applyCommentaryMute()
    }

    /// Applies shouldMuteCommentary to the engine. On a change from unmuted to muted it also
    /// stops the line being spoken and drops the lines queued behind it (D-132). It does not
    /// touch onWillSpeak, so a muted host still feeds its guests (D-130).
    func applyCommentaryMute() {
        guard let engine = commentaryEngine else { return }
        let wasMuted = engine.isMuted
        engine.isMuted = shouldMuteCommentary
        if !wasMuted && engine.isMuted { engine.stopSpeaking() }
    }

    /// Saves the engine's shuffle deck under the personality it was loaded for, then forgets
    /// that personality, so the next host or solo sync restores a deck (D-077).
    func saveShuffleAndForget() {
        guard let loaded = shuffleLoadedFor else { return }
        if let engine = commentaryEngine {
            commentaryShuffleStore.save(engine.shuffleState, for: loaded)
        }
        shuffleLoadedFor = nil
    }

    /// Saves the engine's shuffle deck when the app goes to the background (D-077).
    func saveShuffleForBackground() {
        guard let loaded = shuffleLoadedFor, let engine = commentaryEngine else { return }
        commentaryShuffleStore.save(engine.shuffleState, for: loaded)
    }

    func syncCommentaryEngine() {
        let inSession = gameNight.isSessionActive
        let isGuest   = inSession && gameNight.role != .host

        // Resolve effective settings.
        // During a Game Night session ALL devices follow the host's session-level settings
        // (gameNight.*) rather than each player's own appSettings. This keeps commentary
        // consistent across devices and leaves appSettings untouched.
        let enabled: Bool
        let personalityID: String
        let levelRaw: String
        if inSession {
            enabled       = gameNight.commentaryEnabled
            personalityID = gameNight.commentaryPackID
            levelRaw      = gameNight.commentaryLevelRaw
        } else {
            guard let settings = appSettings else { return }
            // .gameNightOnly and .off both suppress commentary outside a session.
            enabled       = settings.commentaryMode == .allGames
            personalityID = settings.commentaryPersonalityID
            levelRaw      = settings.commentaryLevelRaw
        }

        guard enabled else {
            saveShuffleAndForget()
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            gameNight.onCommentaryReceived = nil
            return
        }

        let personality = CommentaryPersonality.find(id: personalityID)
        let level = CommentaryLevel(rawValue: levelRaw) ?? .celebrations
        // The saved voice while it is installed, else the best installed voice in the device's
        // language (D-081). Nil until the first scan lands; the revision change re-runs this.
        let savedID = UserDefaults.standard.commentaryVoiceID
        let voice = commentaryVoices.voiceInUse(for: personality.id, savedID: savedID)
            .flatMap { AVSpeechSynthesisVoice(identifier: $0.identifier) }

        if isGuest {
            // Guest: engine runs in receive-only mode. Text comes verbatim from the host
            // broadcast; local event generation is suppressed so guests never produce their
            // own lines. appSettings.commentaryEnabled is intentionally ignored here.
            // A guest's engine speaks the host's text and draws nothing, so its deck is saved
            // and forgotten.
            saveShuffleAndForget()
            if let engine = commentaryEngine {
                engine.update(personality: personality, voice: voice, level: .playByPlay)
            } else {
                commentaryEngine = CommentaryEngine(personality: personality, voice: voice, level: .playByPlay)
            }
            model.commentaryEventSink = nil
            let engine = commentaryEngine
            gameNight.onCommentaryReceived = { text, tier in engine?.receiveText(text, tier: tier) }
            applyCommentaryMute()
            return
        }

        // Host or solo: generate commentary locally via the event sink.
        // Save the outgoing personality's deck first: update clears the shuffle when the
        // personality changes (D-077).
        if let loaded = shuffleLoadedFor, loaded != personality.id, let engine = commentaryEngine {
            commentaryShuffleStore.save(engine.shuffleState, for: loaded)
        }
        if let engine = commentaryEngine {
            engine.update(personality: personality, voice: voice, level: level)
        } else {
            commentaryEngine = CommentaryEngine(personality: personality, voice: voice, level: level)
        }
        if shuffleLoadedFor != personality.id {
            commentaryEngine?.restoreShuffle(commentaryShuffleStore.load(for: personality.id))
            shuffleLoadedFor = personality.id
        }
        // Always re-wire the sink — the engine may have been reused from a guest session
        // where commentaryEventSink was intentionally nil.
        if let engine = commentaryEngine {
            model.commentaryEventSink = { [weak engine] event in engine?.handle(event) }
        }
        gameNight.onCommentaryReceived = nil
        // Host in session: broadcast each generated line so all guests speak the same text.
        if inSession {
            let gn = gameNight
            commentaryEngine?.onWillSpeak = { text, tier in gn.broadcastCommentary(text: text, tier: tier) }
        } else {
            commentaryEngine?.onWillSpeak = nil
        }
        applyCommentaryMute()
    }
}
