import SwiftUI
import SyLibCommentary

// Thin binding wrapper following GameNightScreens.swift pattern.
// Bridges AppSettingsModel and UserDefaults to the package CommentarySettingsView.
struct CommentaryScreen: View {
    @Bindable var settings: AppSettingsModel
    @Environment(\.theme) private var theme

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

    private var voiceIDBinding: Binding<String?> {
        Binding(
            get: { UserDefaults.standard.commentaryVoiceID },
            set: { UserDefaults.standard.commentaryVoiceID = $0 }
        )
    }
}
