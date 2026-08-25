import SwiftUI
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
                Picker("Commentary", selection: $settings.commentaryModeRaw) {
                    ForEach(CommentaryMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                if settings.commentaryMode != .off {
                    NavigationLink {
                        CommentarySettingsView(settings: settings)
                    } label: {
                        Text("Voice, Personality & Level")
                    }
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
}
