import SwiftUI
import SyLibUI
import SyLibScoring
import SwiftData
import SyLibScoringData

struct PlayerEditSheet: View {
    enum Mode: Identifiable {
        case create
        case edit(PlayerModel, matchSlot: Int?)

        var id: String {
            switch self {
            case .create: return "create"
            case .edit(let pm, _): return pm.id.uuidString
            }
        }
    }

    let mode: Mode
    @Bindable var matchModel: MatchController
    var onSave: (() -> Void)? = nil
    /// When set for `.create` mode, receives the new `PlayerModel` instead of adding it
    /// to `matchModel`. Use this when the caller needs to act on the new player directly
    /// (e.g. game night seat claim) without touching the local match state.
    var onCreated: ((PlayerModel) -> Void)? = nil

    @Environment(\.modelContext) private var context

    init(mode: Mode, matchModel: MatchController, onSave: (() -> Void)? = nil, onCreated: ((PlayerModel) -> Void)? = nil) {
        self.mode = mode
        self.matchModel = matchModel
        self.onSave = onSave
        self.onCreated = onCreated
    }

    var body: some View {
        // SyLib's sheet: Name, Initials and the palette chips; it trims and resolves the name and
        // initials, and dismisses itself after onSave (D-162).
        PalettePlayerEditSheet(
            existing: existing,
            themeID: initialThemeID,
            nameLimit: nil,
            initialsLimit: nil,
            deriveInitials: { deriveInitials(from: $0) },
            onSave: { name, initials, themeID in
                save(name: name, initials: initials, themeType: SyTheme.ThemeType(themeID: themeID))
            }
        )
    }

    private var existing: (name: String, initials: String)? {
        switch mode {
        case .create: return nil
        case .edit(let pm, _): return (pm.name, pm.initials)
        }
    }

    private var initialThemeID: String {
        switch mode {
        case .create: return matchModel.nextPlayerThemeType.rawValue
        case .edit(let pm, _): return pm.themeID
        }
    }

    /// Today's writes: a new player is inserted and handed to onCreated or seated in the match; an
    /// edited one is updated, and so is its match seat when it has one.
    private func save(name: String, initials: String, themeType: SyTheme.ThemeType) {
        switch mode {
        case .create:
            let pm = PlayerModel()
            pm.name = name
            pm.initials = initials
            pm.themeID = themeType.rawValue
            context.insert(pm)
            if let onCreated {
                onCreated(pm)
            } else {
                matchModel.addPlayer(from: pm.toDomain())
            }

        case .edit(let pm, let matchSlot):
            pm.name = name
            pm.initials = initials
            pm.themeID = themeType.rawValue
            if let slot = matchSlot {
                matchModel.updatePlayer(at: slot, name: name, initials: initials, themeType: themeType)
            }
        }

        onSave?()
    }
}

#Preview("New Player") {
    let container = try! ModelContainer(
        for: Schema([PlayerModel.self]),
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    PlayerEditSheet(mode: .create, matchModel: MatchController())
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}

#Preview("Edit Player") {
    let container = try! ModelContainer(
        for: Schema([PlayerModel.self]),
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    let pm = PlayerModel()
    pm.name = "Wayne"
    pm.initials = "WM"
    pm.themeID = SyTheme.ThemeType.midnight.rawValue
    container.mainContext.insert(pm)
    return PlayerEditSheet(mode: .edit(pm, matchSlot: 0), matchModel: MatchController())
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
