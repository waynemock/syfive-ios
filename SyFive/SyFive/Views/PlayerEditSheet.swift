import SwiftUI
import SwiftData

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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String
    @State private var initials: String
    @State private var themeType: Theme.ThemeType

    init(mode: Mode, matchModel: MatchController) {
        self.mode = mode
        self.matchModel = matchModel
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _initials = State(initialValue: "")
            _themeType = State(initialValue: matchModel.nextPlayerThemeType)
        case .edit(let pm, _):
            _name = State(initialValue: pm.name)
            _initials = State(initialValue: pm.initials)
            _themeType = State(initialValue: Theme.ThemeType(rawValue: pm.themeID) ?? .midnight)
        }
    }

    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { oldName, newName in
                            // Auto-sync initials when they still match the previous auto-derived value.
                            if initials == deriveInitials(from: oldName) || initials.isEmpty {
                                initials = deriveInitials(from: newName)
                            }
                        }

                    HStack {
                        Text("Initials")
                        Spacer()
                        TextField("AB", text: $initials)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Color") {
                    themePicker
                }
            }
            .navigationTitle(isNew ? "New Player" : "Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var themePicker: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Theme.ThemeType.allCases, id: \.self) { type in
                let color = Theme(type: type, colorScheme: colorScheme).primaryAccent
                ZStack {
                    Circle().fill(color)
                    if themeType == type {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 36)
                .onTapGesture { themeType = type }
            }
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let trimmedInitials = initials.trimmingCharacters(in: .whitespaces)
        let finalInitials = trimmedInitials.isEmpty ? deriveInitials(from: trimmedName) : trimmedInitials

        switch mode {
        case .create:
            let pm = PlayerModel()
            pm.name = trimmedName
            pm.initials = finalInitials
            pm.themeID = themeType.rawValue
            context.insert(pm)
            matchModel.addPlayer(from: pm.toDomain())

        case .edit(let pm, let matchSlot):
            pm.name = trimmedName
            pm.initials = finalInitials
            pm.themeID = themeType.rawValue
            if let slot = matchSlot {
                matchModel.updatePlayer(at: slot, name: trimmedName, initials: finalInitials, themeType: themeType)
            }
        }

        dismiss()
    }
}
