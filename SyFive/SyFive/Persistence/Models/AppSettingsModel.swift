import Foundation
import SwiftData
import SwiftUI
import SyLibCommentary
import SyLibFeel
import SyLibUI

@Model final class AppSettingsModel {
    // CloudKit requires declaration-level defaults on all stored properties.
    var colorSchemeRaw: String = AppearanceSetting.dark.rawValue
    var soundEnabled: Bool = true       // retained for CloudKit schema compatibility; use soundMode
    var hapticsEnabled: Bool = true
    var suggestedMoveEnabled: Bool = true
    var commentaryEnabled: Bool = false  // retained for CloudKit schema compatibility; use commentaryMode
    var commentaryModeRaw: String = CommentaryMode.allGames.rawValue
    var commentaryLevelRaw: String = CommentaryLevel.celebrations.rawValue
    var commentaryPersonalityID: String = CommentaryPersonality.zen.id
    var soundModeRaw: String = AppSoundMode.mix.rawValue
    var helpDismissed: Bool = false

    init() {}

    var colorScheme: AppearanceSetting {
        get { AppearanceSetting(rawValue: colorSchemeRaw) ?? .dark }
        set { colorSchemeRaw = newValue.rawValue }
    }

    var commentaryMode: CommentaryMode {
        get { CommentaryMode(rawValue: commentaryModeRaw) ?? .allGames }
        set { commentaryModeRaw = newValue.rawValue }
    }

    var soundMode: AppSoundMode {
        get { AppSoundMode(rawValue: soundModeRaw) ?? .mix }
        set { soundModeRaw = newValue.rawValue }
    }
}

// MARK: - Environment

private struct SuggestedMoveEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var suggestedMoveEnabled: Bool {
        get { self[SuggestedMoveEnabledKey.self] }
        set { self[SuggestedMoveEnabledKey.self] = newValue }
    }
}
