import SwiftUI
import AVFoundation
import SyLibFeel
import SyLibGameNight
import SyLibScoring

extension ContentView {

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
            commentaryEngine?.isMuted = (director.soundMode == .off)
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
        commentaryEngine?.isMuted = (director.soundMode == .off)
    }
}
