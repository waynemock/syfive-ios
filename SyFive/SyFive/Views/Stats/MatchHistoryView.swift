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
    var onResume: ((MatchModel) -> Void)? = nil

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
                        NavigationLink {
                            UnfinishedMatchDetailView(matchModel: matchModel) { m in
                                onResume?(m)
                            }
                        } label: {
                            UnfinishedMatchRow(match: matchModel.toDomain())
                        }
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

#Preview {
    MatchHistoryView()
        .modelContainer(for: MatchModel.self, inMemory: true)
}
