import SwiftUI
import SwiftData
import SyLibCommentary

// Thin binding wrapper following GameNightScreens.swift pattern.
// Bridges AppSettingsModel and UserDefaults to the package CommentarySettingsView.
struct CommentaryScreen: View {
    @Bindable var settings: AppSettingsModel
    @Environment(\.theme) private var theme
    @Environment(CommentaryVoices.self) private var voices

    var body: some View {
        CommentarySettingsView(
            personalities: CommentaryPersonality.all,
            selectedPersonalityID: $settings.commentaryPersonalityID,
            level: levelBinding,
            mode: modeBinding,
            voiceID: voiceIDBinding,
            accentColor: theme.primaryAccent
        )
    }

    private var levelBinding: Binding<CommentaryLevel> {
        Binding(
            get: { CommentaryLevel(rawValue: settings.commentaryLevelRaw) ?? .highlights },
            set: { settings.commentaryLevelRaw = $0.rawValue }
        )
    }

    private var modeBinding: Binding<CommentaryMode> {
        Binding(
            get: { CommentaryMode(rawValue: settings.commentaryModeRaw) ?? .off },
            set: { settings.commentaryModeRaw = $0.rawValue }
        )
    }

    /// Names the voice actually in use, so the Voice row and its preview match what speaks
    /// (D-081): the saved voice while it is installed, else the personality's automatic voice.
    private var voiceIDBinding: Binding<String?> {
        Binding(
            get: {
                let saved = UserDefaults.standard.commentaryVoiceID
                return voices.voiceInUse(for: settings.commentaryPersonalityID, savedID: saved)?.identifier ?? saved
            },
            set: { UserDefaults.standard.commentaryVoiceID = $0 }
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AppSettingsModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let settings = AppSettingsModel()
    container.mainContext.insert(settings)
    return NavigationStack {
        CommentaryScreen(settings: settings)
    }
    .modelContainer(container)
    .environment(CommentaryVoices())
}
