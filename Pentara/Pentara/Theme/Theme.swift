import SwiftUI

/// Defines the color schemes and visual styling for the Sudoku app.
///
/// `Theme` provides a centralized theming system supporting multiple color schemes,
/// light/dark mode adaptation, and consistent visual styling across the app.
struct Theme {
    // MARK: - Theme Type
    
    /// Available theme options for the app.
    enum ThemeType: String, Codable, CaseIterable {
        case blossom = "Blossom"
        case ember = "Ember"
        case forest = "Forest"
        case midnight = "Midnight"
        case ocean = "Ocean"
        case sunset = "Sunset"
        case paper = "Paper"

        /// User-friendly display name for the theme.
        var displayName: String {
            switch self {
            case .blossom:
                return "Blossom"
            case .ember:
                return "Ember"
            case .forest:
                return "Forest"
            case .midnight:
                return "Midnight"
            case .ocean:
                return "Ocean"
            case .paper:
                return "Paper"
            case .sunset:
                return "Sunset"
            }
        }
    }
    
    // MARK: - Propertiest
    
    /// The current theme type.
    var type: ThemeType
    
    /// The color scheme (light or dark).
    var colorScheme: ColorScheme
    
    // MARK: - Colors
    
    /// Primary background color for the app.
    var backgroundColor: Color {
        switch type {
        case .blossom:
            return colorScheme == .dark ? Color(red: 0.18, green: 0.10, blue: 0.15) : Color(red: 0.98, green: 0.93, blue: 0.96)
        case .ember:
            return colorScheme == .dark ? Color(red: 0.08, green: 0.05, blue: 0.05) : Color(red: 0.98, green: 0.95, blue: 0.94)
        case .forest:
            return colorScheme == .dark ? Color(red: 0.08, green: 0.15, blue: 0.10) : Color(red: 0.92, green: 0.96, blue: 0.93)
        case .midnight:
            return colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.08) : Color(red: 0.85, green: 0.85, blue: 0.90)
        case .ocean:
            return colorScheme == .dark ? Color(red: 0.08, green: 0.12, blue: 0.20) : Color(red: 0.88, green: 0.94, blue: 0.98)
        case .paper:
            return colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.17) : Color(red: 0.95, green: 0.95, blue: 0.97)
        case .sunset:
            return colorScheme == .dark ? Color(red: 0.15, green: 0.10, blue: 0.15) : Color(red: 0.98, green: 0.95, blue: 0.92)
        }
    }
    
    /// Color for cell backgrounds.
    var cellBackgroundColor: Color {
        switch type {
        case .blossom:
            return colorScheme == .dark ? Color(red: 0.25, green: 0.18, blue: 0.22) : Color(red: 0.99, green: 0.96, blue: 0.98)
        case .ember:
            return colorScheme == .dark ? Color(red: 0.14, green: 0.09, blue: 0.09) : Color(red: 1.00, green: 0.98, blue: 0.97)
        case .forest:
            return colorScheme == .dark ? Color(red: 0.15, green: 0.22, blue: 0.17) : Color(red: 0.96, green: 0.98, blue: 0.96)
        case .midnight:
            return colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.15) : Color(red: 0.92, green: 0.92, blue: 0.95)
        case .ocean:
            return colorScheme == .dark ? Color(red: 0.15, green: 0.20, blue: 0.30) : Color(red: 0.95, green: 0.97, blue: 0.99)
        case .paper:
            return colorScheme == .dark ? Color(red: 0.25, green: 0.25, blue: 0.27) : Color.white
        case .sunset:
            return colorScheme == .dark ? Color(red: 0.25, green: 0.18, blue: 0.22) : Color(red: 0.99, green: 0.97, blue: 0.95)
        }
    }
    
    /// Primary accent color for interactive elements.
    var primaryAccent: Color {
        switch type {
        case .blossom:
            return Color(red: 0.95, green: 0.40, blue: 0.70)
        case .ember:
            return Color(red: 0.95, green: 0.18, blue: 0.12)
        case .forest:
            return Color(red: 0.30, green: 0.70, blue: 0.45)
        case .midnight:
            return Color(red: 0.60, green: 0.50, blue: 0.90)
        case .ocean:
            return Color(red: 0.20, green: 0.60, blue: 0.90)
        case .paper:
            return colorScheme == .dark ? Color(red: 0.70, green: 0.70, blue: 0.70) : Color(red: 0.30, green: 0.30, blue: 0.30)
        case .sunset:
            return Color(red: 0.95, green: 0.50, blue: 0.30)
        }
    }
    
    /// Secondary accent color for complementary elements.
    var secondaryAccent: Color {
        switch type {
        case .blossom:
            return Color(red: 0.98, green: 0.60, blue: 0.85)
        case .ember:
            return Color(red: 0.98, green: 0.45, blue: 0.20)
        case .forest:
            return Color(red: 0.50, green: 0.85, blue: 0.40)
        case .midnight:
            return Color(red: 0.70, green: 0.60, blue: 0.95)
        case .ocean:
            return Color(red: 0.10, green: 0.80, blue: 0.70)
        case .sunset:
            return Color(red: 0.90, green: 0.70, blue: 0.30)
        case .paper:
            return colorScheme == .dark ? Color(red: 0.50, green: 0.50, blue: 0.50) : Color(red: 0.45, green: 0.45, blue: 0.45)
        }
    }
    
    /// Color for text on primary surfaces.
    var primaryText: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    /// Color for secondary/subtle text.
    var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    /// Color for initial (given) cell values.
    var initialCellText: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    /// Color for user-entered cell values.
    var userCellText: Color {
        secondaryAccent
    }
    
    /// Color for error/conflict indicators.
    var errorColor: Color {
        Color.red
    }
    
    /// Color for success indicators.
    var successColor: Color {
        Color.green
    }
    
    /// Color for warning/hint indicators.
    var warningColor: Color {
        Color.orange
    }
    
    /// Color for selected cell background.
    var selectedCellColor: Color {
        primaryAccent.opacity(0.6)
    }
    
    /// Color for highlighted cell background.
    var highlightedCellColor: Color {
        primaryAccent.opacity(0.3)
    }
    
    /// Color for hint cell background color.
    var hintCellColor: Color {
        Color.yellow.opacity(0.2)
    }
    
    /// Gradient for glass effects.
    var glassGradient: LinearGradient {
        LinearGradient(
            colors: [
                primaryAccent.opacity(0.3),
                primaryAccent.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Initialization
    
    /// Creates a new theme with the specified type and color scheme.
    ///
    /// - Parameters:
    ///   - type: The theme type to use.
    ///   - colorScheme: The color scheme (light or dark).
    init(type: ThemeType = .blossom, colorScheme: ColorScheme = .dark) {
        self.type = type
        self.colorScheme = colorScheme
    }
}

// MARK: - Environment Key

/// Environment key for accessing the app theme.
struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme()
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

