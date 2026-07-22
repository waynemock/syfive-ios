import SwiftUI
import SwiftData

struct PlayerPickerSheet: View {
    @Bindable var model: MatchController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.editMode) private var editMode
    @Query(sort: \PlayerModel.createdAt) private var allPlayers: [PlayerModel]

    @State private var playerEditMode: PlayerEditSheet.Mode? = nil
    @State private var pendingArchive: PlayerModel? = nil
    @ScaledMetric private var initialsCircleSize: CGFloat = 28
    @ScaledMetric private var initialsFontSize: CGFloat = 10

    private var playerIDsInMatch: Set<UUID> {
        Set(model.playerIDs.compactMap { $0 })
    }

    private var availablePlayers: [PlayerModel] {
        allPlayers.filter { !$0.isArchived && !playerIDsInMatch.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    private var archivedPlayers: [PlayerModel] {
        allPlayers.filter { $0.isArchived }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                // In-game players in turn order — reorderable, removable.
                if model.playerCount > 0 {
                    Section("Playing") {
                        ForEach(Array(model.slotIDs.enumerated()), id: \.element) { index, slotID in
                            inGameRow(at: index, slotID: slotID)
                        }
                        .onMove { from, to in
                            guard let source = from.first else { return }
                            // Convert List's insert-before offset to a slot index.
                            let destination = source < to ? to - 1 : to
                            model.movePlayer(from: source, to: destination)
                        }
                    }
                }

                // Roster players not yet in the game.
                Section("Roster") {
                    if model.playerCount == 0 && availablePlayers.isEmpty {
                        emptyRosterPrompt
                    }

                    ForEach(availablePlayers) { playerModel in
                        rosterRow(for: playerModel)
                    }

                    Button {
                        playerEditMode = .create
                    } label: {
                        Label("New Player", systemImage: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                if !archivedPlayers.isEmpty {
                    Section("Archived") {
                        ForEach(archivedPlayers) { playerModel in
                            archivedRow(for: playerModel)
                        }
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $playerEditMode) { mode in
                PlayerEditSheet(mode: mode, matchModel: model)
            }
            .alert(
                pendingArchive.map { "Archive \($0.name)?" } ?? "",
                isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }),
                presenting: pendingArchive
            ) { player in
                Button("Archive", role: .destructive) {
                    player.isArchived = true
                    pendingArchive = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("They'll be moved to the archive and removed from your roster.")
            }
        }
    }

    // MARK: - Row views

    private func inGameRow(at index: Int, slotID: UUID) -> some View {
        let theme = Theme(
            type: model.themeType(for: index),
            colorScheme: colorScheme
        )
        let isEditing = editMode?.wrappedValue.isEditing == true
        // Safe subscripts: SwiftUI calls the body once more during removal animation.
        let name = model.playerDisplayNames.indices.contains(index) ? model.playerDisplayNames[index] : ""

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.primaryAccent)
                Text(model.playerInitials(for: index))
                    .font(.system(size: initialsFontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: initialsCircleSize, height: initialsCircleSize)

            Text(name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent)

            if !isEditing {
                if model.playerIDs.indices.contains(index),
                   let pid = model.playerIDs[index],
                   let pm = allPlayers.first(where: { $0.id == pid }) {
                    Button {
                        playerEditMode = .edit(pm, matchSlot: index)
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(theme.secondaryAccent)
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

    private func rosterRow(for playerModel: PlayerModel) -> some View {
        let theme = Theme(
            type: Theme.ThemeType(rawValue: playerModel.themeID) ?? .midnight,
            colorScheme: colorScheme
        )

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.primaryAccent)
                Text(playerModel.initials)
                    .font(.system(size: initialsFontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: initialsCircleSize, height: initialsCircleSize)
 
            Text(playerModel.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent)

            Button {
                playerEditMode = .edit(playerModel, matchSlot: nil)
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(theme.secondaryAccent)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                model.addPlayer(from: playerModel.toDomain())
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                pendingArchive = playerModel
            } label: {
                Label("Archive", systemImage: "archivebox.fill")
            }
            .tint(.red)
        }
    }

    private func archivedRow(for playerModel: PlayerModel) -> some View {
        let theme = Theme(
            type: Theme.ThemeType(rawValue: playerModel.themeID) ?? .midnight,
            colorScheme: colorScheme
        )

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(theme.primaryAccent.opacity(0.4))
                Text(playerModel.initials)
                    .font(.system(size: initialsFontSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: initialsCircleSize, height: initialsCircleSize)

            Text(playerModel.name)
                .font(.body)
                .foregroundStyle(theme.secondaryAccent.opacity(0.4))

            Spacer()

            Button {
                playerModel.isArchived = false
            } label: {
                Image(systemName: "arrow.up.trash")
                    .foregroundStyle(.secondary)
                    .font(.title)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .leading) {
            Button {
                playerModel.isArchived = false
            } label: {
                Label("Unarchive", systemImage: "arrow.up.trash")
            }
            .tint(.green)
        }
    }

    private var emptyRosterPrompt: some View {
        VStack(spacing: 8) {
            Text("No players yet")
                .font(.headline)
            Text("Create a player below to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .padding(.vertical, 24)
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
    p1.themeID = Theme.ThemeType.midnight.rawValue
    container.mainContext.insert(p1)

    let p2 = PlayerModel()
    p2.name = "Sherida"
    p2.initials = "SM"
    p2.themeID = Theme.ThemeType.forest.rawValue
    container.mainContext.insert(p2)

    let model = MatchController()
    model.addPlayer(from: p1.toDomain())

    return PlayerPickerSheet(model: model)
        .modelContainer(container)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
}
