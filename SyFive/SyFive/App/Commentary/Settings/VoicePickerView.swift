import SwiftUI
import AVFoundation

struct VoicePickerView: View {
    let personality: CommentaryPersonality
    let selectedVoiceID: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var speaker = VoiceSpeaker()
    @ScaledMetric private var speakerButtonSize: CGFloat = 28

    private var groupedVoices: [(language: String, voices: [AVSpeechSynthesisVoice])] {
        let localeLang = Locale.current.language.languageCode?.identifier ?? "en"
        var byLang: [String: [AVSpeechSynthesisVoice]] = [:]
        for v in AVSpeechSynthesisVoice.speechVoices() {
            let lang = String(v.language.prefix(2))
            byLang[lang, default: []].append(v)
        }
        for lang in byLang.keys {
            byLang[lang]?.sort { a, b in
                let ra = qualityRank(a.quality), rb = qualityRank(b.quality)
                return ra == rb ? a.name < b.name : ra < rb
            }
        }
        var groups = byLang.map { (language: $0.key, voices: $0.value) }
        groups.sort { a, b in
            if a.language == localeLang { return true }
            if b.language == localeLang { return false }
            return a.language < b.language
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedVoices, id: \.language) { group in
                    Section(languageDisplayName(group.language)) {
                        ForEach(group.voices, id: \.identifier) { voice in
                            voiceRow(voice)
                        }
                    }
                }
            }
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func voiceRow(_ voice: AVSpeechSynthesisVoice) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(voice.name)
                        .foregroundStyle(.primary)
                    qualityBadge(voice.quality)
                }
                Text(voice.language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                speaker.preview(personality: personality, voice: voice)
            } label: {
                Image(systemName: speaker.speakingVoiceID == voice.identifier
                      ? "speaker.wave.2.fill" : "speaker.wave.2")
                    .foregroundStyle(theme.primaryAccent)
                    .frame(width: speakerButtonSize, height: speakerButtonSize)
            }
            .buttonStyle(.plain)

            if selectedVoiceID == voice.identifier {
                Image(systemName: "checkmark")
                    .foregroundStyle(theme.primaryAccent)
                    .font(.body.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(voice.identifier)
            dismiss()
        }
    }

    @ViewBuilder
    private func qualityBadge(_ quality: AVSpeechSynthesisVoiceQuality) -> some View {
        let label: String? = {
            switch quality {
            case .premium:  return "Premium"
            case .enhanced: return "Enhanced"
            default:        return nil
            }
        }()
        if let label {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.primaryAccent)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(theme.primaryAccent.opacity(0.12), in: Capsule())
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
    }

    private func qualityRank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
        switch q {
        case .premium:  return 0
        case .enhanced: return 1
        default:        return 2
        }
    }
}

@Observable
private final class VoiceSpeaker: NSObject {
    var speakingVoiceID: String? = nil
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func preview(personality: CommentaryPersonality, voice: AVSpeechSynthesisVoice) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            speakingVoiceID = nil
            return
        }
        let utterance = AVSpeechUtterance(string: personality.previewLine)
        utterance.voice = voice
        utterance.rate = personality.prosody.rate
        utterance.pitchMultiplier = personality.prosody.pitchMultiplier
        utterance.preUtteranceDelay = personality.prosody.preUtteranceDelay
        utterance.postUtteranceDelay = personality.prosody.postUtteranceDelay
        speakingVoiceID = voice.identifier
        synthesizer.speak(utterance)
    }
}

extension VoiceSpeaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speakingVoiceID = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        speakingVoiceID = nil
    }
}

#Preview {
    VoicePickerView(
        personality: .steady,
        selectedVoiceID: nil,
        onSelect: { _ in }
    )
}
