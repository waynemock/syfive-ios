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

@Model final class AppSettingsModel {
    // CloudKit requires declaration-level defaults on all stored properties.
    var colorSchemeRaw: String = AppColorScheme.dark.rawValue
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var suggestedMoveEnabled: Bool = true
    var commentaryEnabled: Bool = false
    var commentaryLevelRaw: String = CommentaryLevel.celebrations.rawValue
    var commentaryPersonalityID: String = CommentaryPersonality.zen.id

    init() {}

    var colorScheme: AppColorScheme {
        get { AppColorScheme(rawValue: colorSchemeRaw) ?? .dark }
        set { colorSchemeRaw = newValue.rawValue }
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
