import SwiftUI
import SyLibCommentary
import SyLibScoring
import SwiftData
import SyLibFeel

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query private var settingsModels: [AppSettingsModel]

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsModels.first {
                    SettingsForm(settings: settings)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SettingsForm: View {
    @Environment(\.theme) private var theme
    @Environment(CommentaryVoices.self) private var commentaryVoices
    
    @Bindable var settings: AppSettingsModel

    var body: some View {
        Form {
            Section {
                Picker("Color Scheme", selection: $settings.colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases, id: \.rawValue) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
            } header: {
                Text("Appearance")
                    .foregroundStyle(theme.primaryAccent)
            }
            
            Section {
                Picker("Sound", selection: $settings.soundModeRaw) {
                    ForEach(AppSoundMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            } header: {
                Text("Audio & Feedback")
                    .foregroundStyle(theme.primaryAccent)
            } footer: {
                Text("Mix with Other Audio plays alongside your music or podcast. Game Audio Only pauses it.")
            }

            Section {
                Toggle("Suggested Move", isOn: $settings.suggestedMoveEnabled)
            } header: {
                Text("Gameplay")
                    .foregroundStyle(theme.primaryAccent)
            }

            Section {
                // Mode, Level, Personality and the voice in use, with Preview (20 §4.2, D-146).
                let personality = CommentaryPersonality.find(id: settings.commentaryPersonalityID)
                CommentarySettingsRows(
                    mode: settings.commentaryMode,
                    level: CommentaryLevel(rawValue: settings.commentaryLevelRaw) ?? .highlights,
                    personality: personality,
                    voice: commentaryVoices.voiceInUse(for: personality.id,
                                                       savedID: UserDefaults.standard.commentaryVoiceID),
                    accentColor: theme.primaryAccent
                ) {
                    CommentaryScreen(settings: settings)
                }
            } header: {
                Text("Commentary")
                    .foregroundStyle(theme.primaryAccent)
            }

        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettingsModel.self, inMemory: true)
        .environment(CommentaryVoices())
}
