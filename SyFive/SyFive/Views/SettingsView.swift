import SwiftUI
import SwiftData

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
    @Bindable var settings: AppSettingsModel
    @AppStorage("theaterAudioEnabled") private var theaterAudioEnabled: Bool = false

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $settings.colorSchemeRaw) {
                    ForEach(AppColorScheme.allCases, id: \.rawValue) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
            }

            Section("Audio & Feedback") {
                Toggle("Sound", isOn: $settings.soundEnabled)
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            }

            Section("Gameplay") {
                Toggle("Suggested Move", isOn: $settings.suggestedMoveEnabled)
            }

            Section("Commentary") {
                Toggle("Commentary", isOn: $settings.commentaryEnabled)
                if settings.commentaryEnabled {
                    NavigationLink {
                        CommentarySettingsView(settings: settings)
                    } label: {
                        Text("Voice, Personality & Level")
                    }
                }
            }

            Section {
                Toggle("Theater sound on this device", isOn: $theaterAudioEnabled)
            } header: {
                Text("Game Night")
            } footer: {
                Text("Play dice audio during other players' rolls. Turn off when you can hear their device.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettingsModel.self, inMemory: true)
}
