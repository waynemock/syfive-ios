import Foundation
import SwiftData
import SwiftUI

enum AppColorScheme: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum CommentaryMode: String, CaseIterable, Codable {
    case off
    case gameNightOnly
    case allGames

    var displayName: String {
        switch self {
        case .off:           "Off"
        case .gameNightOnly: "Game Night Only"
        case .allGames:      "All Games"
        }
    }
}

enum AppSoundMode: String, CaseIterable, Codable {
    case off
    case mix
    case exclusive

    var displayName: String {
        switch self {
        case .off:       "Off"
        case .mix:       "Mix with Other Audio"
        case .exclusive: "Game Audio Only"
        }
    }
}

@Model final class AppSettingsModel {
    // CloudKit requires declaration-level defaults on all stored properties.
    var colorSchemeRaw: String = AppColorScheme.dark.rawValue
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

    var colorScheme: AppColorScheme {
        get { AppColorScheme(rawValue: colorSchemeRaw) ?? .dark }
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
