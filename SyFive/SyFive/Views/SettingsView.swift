import SwiftUI
import SyLibUI
import SyLibCommentary
import SyLibScoring
import SwiftData
import SyLibFeel
import SyLibCloud

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
    @Environment(\.syTheme) private var theme
    @Environment(CommentaryVoices.self) private var commentaryVoices
    @Environment(FeelDirector.self) private var director
    @Environment(CloudAccountStatus.self) private var cloudStatus
    
    @Bindable var settings: AppSettingsModel
    @State private var showsICloud = false

    var body: some View {
        Form {
            Section {
                Picker("Color Scheme", selection: $settings.colorSchemeRaw) {
                    ForEach(AppearanceSetting.allCases, id: \.rawValue) { scheme in
                        Text(scheme.displayName).tag(scheme.rawValue)
                    }
                }
            } header: {
                Text("Appearance")
                    .foregroundStyle(theme.primaryAccent)
            }
            
            Section {
                FeelSettingsRows(soundMode: $settings.soundMode, hapticsEnabled: $settings.hapticsEnabled,
                                 hapticsSupported: director.hapticSupported)
            } header: {
                Text("Audio & Feedback")
                    .foregroundStyle(theme.primaryAccent)
            } footer: {
                Text(FeelSettingsRows.footer)
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

            Section {
                Button { showsICloud = true } label: {
                    LabeledContent("iCloud Sync", value: cloudStatus.isAvailable ? "On" : "Off")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("iCloud")
                    .foregroundStyle(theme.primaryAccent)
            }
        }
        .sheet(isPresented: $showsICloud) {
            ICloudInfoSheet(appName: "SyFive", accentColor: theme.primaryAccent,
                            backgroundColor: theme.backgroundColor)
                .sheetTextSizeCeiling()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettingsModel.self, inMemory: true)
        .environment(CommentaryVoices())
        .environment(FeelDirector(catalog: .syFive))
        .environment(CloudAccountStatus())
}
