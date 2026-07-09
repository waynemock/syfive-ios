import SwiftUI
import SwiftData

struct MatchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt, order: .reverse)
    
    private var matchModels: [MatchModel]

    var body: some View {
        NavigationStack {
            List {
                ForEach(matchModels) { matchModel in
                    NavigationLink {
                        MatchDetailView(matchModel: matchModel)
                    } label: {
                        MatchHistoryRow(match: matchModel.toDomain())
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if matchModels.isEmpty {
                    ContentUnavailableView(
                        "No completed games",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Finished games will appear here.")
                    )
                }
            }
        }
    }
}

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

struct MatchDetailView: View {
    let matchModel: MatchModel

    private var match: Match { matchModel.toDomain() }

    private var sortedParticipants: [Participant] {
        match.participants.sorted { $0.rank < $1.rank }
    }

    private var playerNames: [UUID: String] {
        Dictionary(uniqueKeysWithValues: match.participants.compactMap { p in
            guard let pid = p.playerID else { return nil }
            return (pid, p.displayName)
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                finalScoresCard
                if let prog = matchProgression(from: match) {
                    progressionCard(prog)
                }
            }
            .padding(16)
        }
        .navigationTitle(match.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
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
            MatchProgressionChart(progression: prog, playerNames: playerNames)
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
