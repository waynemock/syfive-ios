import SwiftUI
import SyLibScoring
import SyLibUI
import SwiftData
import SyLibScoringData

struct PlayerPickerSheet: View {
    @Bindable var model: MatchController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.editMode) private var editMode
    @Environment(\.syTheme) private var theme
    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    @State private var playerEditMode: PlayerEditSheet.Mode? = nil

    private var playerIDsInMatch: Set<UUID> {
        Set(model.playerIDs.compactMap { $0 })
    }

    private var availablePlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived && !playerIDsInMatch.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                // In-game players in turn order — reorderable, removable. Always shown; with no
                // one seated it holds a hint (D-190; Score It *'s SeatList).
                Section {
                    if model.playerCount == 0 {
                        Text("Tap a player below to seat them.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.slotIDs.enumerated()), id: \.element) { index, slotID in
                        inGameRow(at: index, slotID: slotID)
                    }
                    .onMove { from, to in
                        guard let source = from.first else { return }
                        // Convert List's insert-before offset to a slot index.
                        let destination = source < to ? to - 1 : to
                        model.movePlayer(from: source, to: destination)
                    }
                } header: {
                    SectionHeader("Playing")
                }
                .paletteRowBackground()

                // Roster players not yet in the game, as chips in their palettes; a tap seats
                // them, and New Player is the last chip (D-190; Score It *'s PlayerPicker).
                Section {
                    FlowLayout {
                        ForEach(availablePlayers) { player in
                            SelectableChip(player.name, isSelected: false,
                                           action: { model.addPlayer(from: player.toDomain()) },
                                           tintsWhenUnselected: true)
                            .tint(SyTheme.accent(forThemeID: player.themeID, colorScheme: colorScheme))
                        }
                        SelectableChip(isSelected: false, action: { playerEditMode = .create }) {
                            Label("New Player", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                                .fixedSize()
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    SectionHeader("Roster")
                }
                .paletteRowBackground()
            }
            .paletteListBackground()
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .paletteBarBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $playerEditMode) { mode in
                PlayerEditSheet(mode: mode, matchModel: model)
                    .environment(\.syTheme, theme)
                    .sheetTextSizeCeiling()
            }
        }
        .tint(theme.primaryAccent)
    }

    // MARK: - Row views

    private func inGameRow(at index: Int, slotID: UUID) -> some View {
        let rowTheme = SyTheme(
            type: model.themeType(for: index),
            colorScheme: colorScheme
        )
        let isEditing = editMode?.wrappedValue.isEditing == true
        // Safe subscripts: SwiftUI calls the body once more during removal animation.
        let name = model.playerDisplayNames.indices.contains(index) ? model.playerDisplayNames[index] : ""

        return HStack(spacing: 12) {
            InitialsCircle(initials: model.playerInitials(for: index), color: rowTheme.primaryAccent, diameter: 28)

            Text(name)
                .font(.body)
                .foregroundStyle(rowTheme.secondaryAccent)

            if !isEditing {
                if model.playerIDs.indices.contains(index),
                   let pid = model.playerIDs[index],
                   let pm = allPlayers.first(where: { $0.id == pid }) {
                    Button {
                        playerEditMode = .edit(pm, matchSlot: index)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(rowTheme.secondaryAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("Turn \(index + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !isEditing {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .font(.title)
            }
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                // Re-derive current index by UUID so a stale captured index can't crash.
                if let current = model.slotIDs.firstIndex(of: slotID) {
                    model.removePlayer(at: current)
                }
            } label: {
                Label("Remove", systemImage: "xmark")
            }
            .tint(.red)
        }
    }
}

#Preview {
    let schema = Schema([
        PlayerModel.self, TeamModel.self, GameModel.self,
        MatchModel.self, ParticipantModel.self, AppSettingsModel.self,
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )

    let p1 = PlayerModel()
    p1.name = "Wayne"
    p1.initials = "WM"
    p1.themeID = SyTheme.ThemeType.midnight.rawValue
    container.mainContext.insert(p1)

    let p2 = PlayerModel()
    p2.name = "Sherida"
    p2.initials = "SM"
    p2.themeID = SyTheme.ThemeType.forest.rawValue
    container.mainContext.insert(p2)

    let model = MatchController()
    model.addPlayer(from: p1.toDomain())

    return PlayerPickerSheet(model: model)
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
