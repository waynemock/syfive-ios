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
    var colorSchemeRaw: String
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var suggestedMoveEnabled: Bool

    init(
        colorSchemeRaw: String = AppColorScheme.dark.rawValue,
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        suggestedMoveEnabled: Bool = true
    ) {
        self.colorSchemeRaw = colorSchemeRaw
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.suggestedMoveEnabled = suggestedMoveEnabled
    }

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
