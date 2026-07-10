import SwiftUI
import SwiftData
import AVFoundation

struct CommentarySettingsView: View {
    @Bindable var settings: AppSettingsModel
    @State private var showsVoicePicker = false
    @State private var showsAddVoices = false
    @State private var speaker = PreviewSpeaker()
    @Environment(\.theme) private var theme

    private var personality: CommentaryPersonality {
        CommentaryPersonality.find(id: settings.commentaryPersonalityID)
    }

    private var selectedVoice: AVSpeechSynthesisVoice? {
        let storedID = UserDefaults.standard.string(forKey: "commentaryVoiceID")
        return storedID.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
    }

    private var selectedVoiceID: String? {
        UserDefaults.standard.string(forKey: "commentaryVoiceID")
    }

    var body: some View {
        Form {
            levelSection
            personalitySection
            voiceSection
            previewSection
        }
        .navigationTitle("Commentary")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsVoicePicker) {
            VoicePickerView(personality: personality, selectedVoiceID: selectedVoiceID) { voiceID in
                UserDefaults.standard.set(voiceID, forKey: "commentaryVoiceID")
            }
            .environment(\.theme, theme)
        }
        .sheet(isPresented: $showsAddVoices) {
            AddVoicesSheet()
                .environment(\.theme, theme)
        }
    }

    private var levelSection: some View {
        Section("Level") {
            Picker("Level", selection: $settings.commentaryLevelRaw) {
                ForEach(CommentaryLevel.allCases, id: \.rawValue) { level in
                    Text(level.displayName).tag(level.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    private var personalitySection: some View {
        Section("Personality") {
            ForEach(CommentaryPersonality.all, id: \.id) { pack in
                Button {
                    settings.commentaryPersonalityID = pack.id
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.displayName)
                                .foregroundStyle(.primary)
                            Text(pack.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if settings.commentaryPersonalityID == pack.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.primaryAccent)
                                .font(.body.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var voiceSection: some View {
        Section("Voice") {
            Button {
                showsVoicePicker = true
            } label: {
                HStack {
                    Text(selectedVoice?.name ?? "Default")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showsAddVoices = true
            } label: {
                Label("Add more voices\u{2026}", systemImage: "arrow.down.circle")
            }
        }
    }

    private var previewSection: some View {
        Section {
            Button {
                let utterance = AVSpeechUtterance(string: personality.previewLine)
                utterance.voice = selectedVoice
                utterance.rate = personality.prosody.rate
                utterance.pitchMultiplier = personality.prosody.pitchMultiplier
                utterance.preUtteranceDelay = personality.prosody.preUtteranceDelay
                utterance.postUtteranceDelay = personality.prosody.postUtteranceDelay
                speaker.speak(utterance)
            } label: {
                HStack {
                    Spacer()
                    Label(
                        speaker.isSpeaking ? "Speaking\u{2026}" : "Preview",
                        systemImage: speaker.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2"
                    )
                    .font(.headline)
                    .foregroundStyle(theme.primaryAccent)
                    Spacer()
                }
            }
        } footer: {
            Text("Speaks the \(personality.displayName) personality in the selected voice. Tap again to stop.")
        }
    }
}

@Observable
private final class PreviewSpeaker: NSObject {
    var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ utterance: AVSpeechUtterance) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

extension PreviewSpeaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}

#Preview {
    NavigationStack {
        CommentarySettingsView(settings: AppSettingsModel())
    }
    .modelContainer(for: AppSettingsModel.self, inMemory: true)
}
