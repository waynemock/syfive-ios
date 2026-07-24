import SwiftUI
import AVFoundation

extension ContentView {

    func syncCommentaryEngine() {
        // Commentary speaks only on the host's seated device during Game Night (10 §3).
        if gameNight.isSessionActive && gameNight.role != .host {
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            return
        }
        guard let settings = appSettings, settings.commentaryEnabled else {
            commentaryEngine?.stopSpeaking()
            commentaryEngine = nil
            model.commentaryEventSink = nil
            return
        }
        let personality = CommentaryPersonality.find(id: settings.commentaryPersonalityID)
        let level = CommentaryLevel(rawValue: settings.commentaryLevelRaw) ?? .celebrations
        let voiceID = UserDefaults.standard.commentaryVoiceID
        let voice = voiceID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        if let engine = commentaryEngine {
            engine.update(personality: personality, voice: voice, level: level)
        } else {
            let engine = CommentaryEngine(personality: personality, voice: voice, level: level)
            commentaryEngine = engine
            model.commentaryEventSink = { [weak engine] event in engine?.handle(event) }
        }
    }
}
