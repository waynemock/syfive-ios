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
    /// Updates the sound mode, handles §5.4 suppression reset, and sets isMuted directly.
    func handleSoundModeChanged() {
        let wasOff = director.soundMode == .off
        director.soundMode = appSettings?.soundMode ?? .mix
        let isNowOff = director.soundMode == .off
        if wasOff && !isNowOff {
            // §5.4: button reappears unmuted — reset suppression state (D-GNP-009).
            gameNight.setCommentarySuppressed(false)
        }
        commentaryEngine?.isMuted = shouldMuteCommentary
    }

    /// Called from `gameNight.onCommentarySuppressedChanged` (button tap or proximity timeout).
    /// Sets isMuted directly — must not re-run syncCommentaryEngine() (§5.3).
    func handleCommentarySuppressionChanged() {
        commentaryEngine?.isMuted = shouldMuteCommentary
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
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            gameNight.onCommentaryReceived = nil
            return
        }

        let personality = CommentaryPersonality.find(id: personalityID)
        let level = CommentaryLevel(rawValue: levelRaw) ?? .celebrations
        let voiceID = UserDefaults.standard.commentaryVoiceID
        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")

        if isGuest {
            // Guest: engine runs in receive-only mode. Text comes verbatim from the host
            // broadcast; local event generation is suppressed so guests never produce their
            // own lines. appSettings.commentaryEnabled is intentionally ignored here.
            if let engine = commentaryEngine {
                engine.update(personality: personality, voice: voice, level: .playByPlay)
            } else {
                commentaryEngine = CommentaryEngine(personality: personality, voice: voice, level: .playByPlay)
            }
            model.commentaryEventSink = nil
            let engine = commentaryEngine
            gameNight.onCommentaryReceived = { text, tier in engine?.receiveText(text, tier: tier) }
            commentaryEngine?.isMuted = shouldMuteCommentary
            return
        }

        // Host or solo: generate commentary locally via the event sink.
        if let engine = commentaryEngine {
            engine.update(personality: personality, voice: voice, level: level)
        } else {
            commentaryEngine = CommentaryEngine(personality: personality, voice: voice, level: level)
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
        commentaryEngine?.isMuted = shouldMuteCommentary
    }
}
