import SwiftUI
import SyLibUI
import SyLibCommentary
import SyLibScoring
import SwiftData
import SyLibFeel
import SyLibCloud

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.syTheme) private var theme
    
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
            .paletteBarBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.primaryAccent)
    }
}

private struct SettingsForm: View {
    @Environment(\.syTheme) private var theme
    @Environment(CommentaryVoices.self) private var commentaryVoices
    @Environment(FeelDirector.self) private var director
    @Environment(CloudAccountStatus.self) private var cloudStatus
    @Environment(\.gameNightAudioActive) private var gameNightAudioActive

    @Bindable var settings: AppSettingsModel
    @State private var showsICloud = false

    var body: some View {
        Form {
            Section {
                SegmentedPicker("Color Scheme", selection: $settings.colorSchemeRaw,
                                segments: AppearanceSetting.allCases.map { ($0.rawValue, $0.displayName) })
            } header: {
                Text("Appearance")
            }
            .paletteRowBackground()
            
            Section {
                FeelSettingsRows(soundMode: Binding(
                                     get: { GameNightAudio.effectiveSoundMode(settings.soundMode, gameNightActive: gameNightAudioActive) },
                                     set: { settings.soundMode = $0 }),
                                 hapticsEnabled: $settings.hapticsEnabled,
                                 hapticsSupported: director.hapticSupported,
                                 soundModes: GameNightAudio.choices(gameNightActive: gameNightAudioActive))
            } header: {
                Text("Audio & Feedback")
            } footer: {
                Text(gameNightAudioActive ? FeelSettingsRows.footer + " " + GameNightAudio.footerNote : FeelSettingsRows.footer)
            }
            .paletteRowBackground()

            Section {
                Toggle("Suggested Move", isOn: $settings.suggestedMoveEnabled)
            } header: {
                Text("Gameplay")
            }
            .paletteRowBackground()

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
            }
            .paletteRowBackground()

            Section {
                Button { showsICloud = true } label: {
                    LabeledContent("iCloud Sync", value: cloudStatus.isAvailable ? "On" : "Off")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("iCloud")
            }
            .paletteRowBackground()
        }
        .paletteListBackground()
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
