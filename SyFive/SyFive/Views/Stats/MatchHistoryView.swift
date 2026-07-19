import SwiftUI
import SwiftData

private enum HistorySegment: CaseIterable {
    case finished, unfinished
}

struct MatchHistoryView: View {
    /// ID of the match currently loaded in the active game view.
    /// When a deletion targets this match, `onActiveMatchDeleted` is called.
    var activeMatchID: UUID? = nil
    var onActiveMatchDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt, order: .reverse)
    private var completedMatches: [MatchModel]

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "inProgress" },
           sort: \MatchModel.startedAt, order: .reverse)
    private var inProgressMatches: [MatchModel]

    @State private var segment: HistorySegment = .finished
    @State private var matchToDelete: MatchModel? = nil

    var body: some View {
        NavigationStack {
            List {
                if segment == .finished {
                    ForEach(completedMatches) { matchModel in
                        NavigationLink {
                            MatchDetailView(matchModel: matchModel)
                        } label: {
                            MatchHistoryRow(match: matchModel.toDomain())
                        }
                    }
                } else {
                    ForEach(inProgressMatches) { matchModel in
                        UnfinishedMatchRow(match: matchModel.toDomain())
                    }
                    .onDelete { indexSet in
                        guard let i = indexSet.first else { return }
                        matchToDelete = inProgressMatches[i]
                    }
                }
            }
            .animation(.default, value: segment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if inProgressMatches.isEmpty {
                        Text("History").font(.headline)
                    } else {
                        Picker("", selection: $segment) {
                            Text("Finished").tag(HistorySegment.finished)
                            Text("Unfinished (\(inProgressMatches.count))").tag(HistorySegment.unfinished)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: inProgressMatches.isEmpty) { _, isEmpty in
                if isEmpty { segment = .finished }
            }
            .overlay {
                if segment == .finished && completedMatches.isEmpty {
                    ContentUnavailableView(
                        "No completed games",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Finished games will appear here.")
                    )
                } else if segment == .unfinished && inProgressMatches.isEmpty {
                    ContentUnavailableView(
                        "No unfinished games",
                        systemImage: "checkmark.circle",
                        description: Text("All your games have been finished.")
                    )
                }
            }
            .alert(
                "Delete this unfinished game?",
                isPresented: Binding(
                    get: { matchToDelete != nil },
                    set: { if !$0 { matchToDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let m = matchToDelete {
                        if m.id == activeMatchID { onActiveMatchDeleted?() }
                        modelContext.delete(m)
                    }
                    matchToDelete = nil
                }
                Button("Cancel", role: .cancel) { matchToDelete = nil }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

// MARK: - Finished row

private struct MatchHistoryRow: View {
    let match: Match

    private var sortedParticipants: [Participant] {
        match.participants.sorted { $0.rank < $1.rank }
    }

    private var winnerLabel: String {
        sortedParticipants
            .filter { $0.rank == 1 }
            .map(\.displayName)
            .joined(separator: " & ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.startedAt, style: .date)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !winnerLabel.isEmpty {
                    Label(winnerLabel, systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(
                sortedParticipants
                    .map { "\($0.displayName) \(Int(truncating: $0.finalScore as NSDecimalNumber))" }
                    .joined(separator: " · ")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Unfinished row

private struct UnfinishedMatchRow: View {
    let match: Match

    private var playerNames: String {
        let names = match.participants.map(\.displayName)
        return names.isEmpty ? "No players" : names.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(match.startedAt, style: .date)
                .font(.subheadline.weight(.semibold))
            Text(playerNames)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Match detail

struct MatchDetailView: View {
    let matchModel: MatchModel

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [PlayerModel]

    private var match: Match { matchModel.toDomain() }

    private var sortedParticipants: [Participant] {
        match.participants.sorted { $0.rank < $1.rank }
    }

    @Environment(\.colorScheme) private var colorScheme

    // Keyed by participantID (p.id), which is what MatchProgressionChart uses.
    private var playerNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: match.participants.map { p in
            (p.id, p.displayName)
        })
    }

    private var playerColors: [UUID: Color] {
        Dictionary(uniqueKeysWithValues: match.participants.map { p in
            let themeType = Theme.ThemeType(rawValue: p.displayThemeID) ?? .midnight
            return (p.id, Theme(type: themeType, colorScheme: colorScheme).primaryAccent)
        })
    }

    private var missingFromRoster: [Participant] {
        let knownIDs = Set(allPlayers.map(\.id))
        return match.participants.filter { p in
            guard let pid = p.playerID else { return false }
            return !knownIDs.contains(pid)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                finalScoresCard
                if !missingFromRoster.isEmpty {
                    missingPlayersCard
                }
                if let prog = matchProgression(from: match) {
                    progressionCard(prog)
                }
            }
            .padding(16)
        }
        .navigationTitle(match.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var missingPlayersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Not in Roster")
                    .font(.headline)
                Text("These players appeared in this match but aren't in your local roster.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(missingFromRoster) { participant in
                HStack {
                    Text(participant.displayName)
                        .font(.subheadline)
                    Spacer()
                    Button("Add to Roster") {
                        addToRoster(participant)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func addToRoster(_ participant: Participant) {
        guard let playerID = participant.playerID else { return }
        let pm = PlayerModel()
        pm.id = playerID
        pm.name = participant.displayName
        pm.initials = participant.displayInitials
        pm.themeID = participant.displayThemeID
        pm.source = .gameNight
        modelContext.insert(pm)
        try? modelContext.save()
    }

    private var finalScoresCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Final Scores")
                .font(.headline)
            ForEach(sortedParticipants) { participant in
                HStack {
                    Text(rankLabel(participant.rank))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)
                    Text(participant.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(Int(truncating: participant.finalScore as NSDecimalNumber),
                         format: .number)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func progressionCard(_ prog: MatchProgression) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match Progression")
                .font(.headline)
            MatchProgressionChart(progression: prog, playerNames: playerNames, playerColors: playerColors)
                .frame(height: 220)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(rank)th"
        }
    }
}

#Preview {
    MatchHistoryView()
        .modelContainer(for: MatchModel.self, inMemory: true)
}
