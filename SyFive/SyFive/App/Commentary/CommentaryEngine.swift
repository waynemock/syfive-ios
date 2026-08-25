import Foundation
import AVFoundation
import UIKit
import SyLibFeel

final class CommentaryEngine: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var personality: CommentaryPersonality
    private(set) var voice: AVSpeechSynthesisVoice?
    private(set) var level: CommentaryLevel
    private var remainingIndices: [CommentaryEventKind: [Int]] = [:]
    private var lastUsedIndex: [CommentaryEventKind: Int] = [:]
    private var currentTier: CommentaryEventTier?

    /// When true the engine silently drops all speech. Controlled by the
    /// app-level sound mode setting; does not affect the commentary enabled toggle.
    var isMuted: Bool = false

    /// Called just before the engine speaks a generated line.
    /// The host wires this to broadcast the text over SharePlay so all
    /// guest devices speak the identical commentary with their own voice.
    var onWillSpeak: ((String, CommentaryEventTier) -> Void)?

    init(personality: CommentaryPersonality, voice: AVSpeechSynthesisVoice?, level: CommentaryLevel) {
        self.personality = personality
        self.voice = voice
        self.level = level
        super.init()
        // Use the app's audio session (.ambient + .mixWithOthers) so the synthesizer
        // never interrupts FeelAudioEngine's AVAudioEngine or the dice audio.
        synthesizer.usesApplicationAudioSession = true
        synthesizer.delegate = self
    }

    func update(personality: CommentaryPersonality, voice: AVSpeechSynthesisVoice?, level: CommentaryLevel) {
        if personality.id != self.personality.id {
            remainingIndices = [:]
            lastUsedIndex = [:]
        }
        self.personality = personality
        self.voice = voice
        self.level = level
    }

    func handle(_ event: CommentaryEvent) {
        guard !UIAccessibility.isVoiceOverRunning else { return }
        let tier = event.kind.tier
        guard passesLevelGate(tier: tier) else { return }

        if synthesizer.isSpeaking {
            // Interrupt for higher-priority (lower rawValue) events; drop same-or-lower.
            guard let current = currentTier, tier < current else { return }
            synthesizer.stopSpeaking(at: .immediate)
        }

        guard let line = selectLine(for: event.kind) else { return }
        let text = fillTokens(line, with: event)
        speak(text: text, tier: tier)
    }

    func preview() {
        synthesizer.stopSpeaking(at: .immediate)
        speak(text: personality.previewLine, tier: .celebration)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Speak text received from the host's broadcast directly, bypassing the
    /// event→text pipeline and the level gate (host already applied the gate).
    /// Only interrupts for celebration-tier (Yatzy / winner) to ensure those
    /// are heard immediately; all other texts are queued so back-to-back lines
    /// from the same scoring action (e.g. primary event + turnStart) both play.
    func receiveText(_ text: String, tier: CommentaryEventTier) {
        guard !UIAccessibility.isVoiceOverRunning else { return }
        if tier == .celebration {
            synthesizer.stopSpeaking(at: .immediate)
        }
        speak(text: text, tier: tier)
    }

    private func passesLevelGate(tier: CommentaryEventTier) -> Bool {
        switch level {
        case .celebrations: return tier == .celebration
        case .highlights:   return tier <= .highlight
        case .playByPlay:   return true
        }
    }

    private func selectLine(for kind: CommentaryEventKind) -> String? {
        guard let variants = personality.lines[kind], !variants.isEmpty else { return nil }
        if remainingIndices[kind]?.isEmpty ?? true {
            // Refill the deck; exclude the last-used index so the deck boundary
            // never produces a back-to-back repeat.
            var pool = Array(variants.indices)
            if pool.count > 1, let last = lastUsedIndex[kind] {
                pool.removeAll { $0 == last }
            }
            remainingIndices[kind] = pool.shuffled()
        }
        let chosen = remainingIndices[kind]!.removeFirst()
        lastUsedIndex[kind] = chosen
        return variants[chosen]
    }

    private func fillTokens(_ line: String, with event: CommentaryEvent) -> String {
        var result = line
        if let v = event.player   { result = result.replacingOccurrences(of: "{player}",   with: v) }
        if let v = event.winner   { result = result.replacingOccurrences(of: "{winner}",   with: v) }
        if let v = event.runnerUp { result = result.replacingOccurrences(of: "{runnerUp}", with: v) }
        if let v = event.leader   { result = result.replacingOccurrences(of: "{leader}",   with: v) }
        if let v = event.score    { result = result.replacingOccurrences(of: "{score}",    with: "\(v)") }
        if let v = event.margin   { result = result.replacingOccurrences(of: "{margin}",   with: "\(v)") }
        if let v = event.category { result = result.replacingOccurrences(of: "{category}", with: v) }
        if let v = event.value    { result = result.replacingOccurrences(of: "{value}",    with: "\(v)") }
        return result
    }

    private func speak(text: String, tier: CommentaryEventTier) {
        guard !isMuted else { return }
        onWillSpeak?(text, tier)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = personality.prosody.rate
        utterance.pitchMultiplier = personality.prosody.pitchMultiplier
        utterance.preUtteranceDelay = personality.prosody.preUtteranceDelay
        utterance.postUtteranceDelay = personality.prosody.postUtteranceDelay
        currentTier = tier
        synthesizer.speak(utterance)
    }
}

extension CommentaryEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentTier = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentTier = nil
    }
}
