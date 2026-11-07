import SwiftUI
import SyLibUI

// SyFive's text-size ceilings, in one place (D-175, 00B E-2). Change a size here and every use
// follows: the root and all the sheets.
extension DynamicTypeSize {
    /// The game screen's ceiling: the dice tray and scorecard aren't laid out above it.
    static let gameScreenCeiling: DynamicTypeSize = .xxxLarge
    /// Everything else: sheets, and the menus, picker menus and alerts UIKit draws.
    static let appCeiling: DynamicTypeSize = .accessibility2
}

extension View {
    /// The root's ceilings: the game screen at `gameScreenCeiling`, and the scene (what UIKit
    /// draws) at `appCeiling`. Apply once, on the root view.
    func appTextSizeCeilings() -> some View {
        self
            .dynamicTypeCeiling(.gameScreenCeiling)
            .sceneDynamicTypeCeiling(.appCeiling)
    }

    /// A sheet's ceiling, `appCeiling`. A cap doesn't cross a presentation, so apply it as the
    /// last modifier on the outermost view inside every `.sheet` closure.
    func sheetTextSizeCeiling() -> some View {
        dynamicTypeCeiling(.appCeiling)
    }
}
