import SwiftUI
import SwiftData
import SyLibGameNight
import SyLibScoringData

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
    @State private var showsDeleteAllAlert = false
    @State private var showsStagingLog = false
    @State private var showsPreviousLog = false
    @State private var stagingLogExists = false
    @State private var previousLogExists = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if !inProgressMatches.isEmpty {
                    Picker("", selection: $segment) {
                        Text("Finished").tag(HistorySegment.finished)
                        Text("Unfinished (\(inProgressMatches.count))").tag(HistorySegment.unfinished)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                List {
                    if AppConfig.DebugGameNight.showLogs {
                        if stagingLogExists {
                            Button {
                                showsStagingLog = true
                            } label: {
                                Label("Staging Log (current.log)", systemImage: "doc.text.magnifyingglass")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    GameNightLogBuffer.shared.deleteStagingLog()
                                    stagingLogExists = false
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        if previousLogExists {
                            Button {
                                showsPreviousLog = true
                            } label: {
                                Label("Previous Log (previous.log)", systemImage: "doc.text")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    GameNightLogBuffer.shared.deletePreviousLog()
                                    previousLogExists = false
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
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
                .onAppear {
                    stagingLogExists = GameNightLogBuffer.shared.hasStagingLog()
                    previousLogExists = GameNightLogBuffer.shared.hasPreviousLog()
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if segment == .unfinished && !inProgressMatches.isEmpty {
                            Button(role: .destructive) {
                                showsDeleteAllAlert = true
                            } label: {
                                Text("Delete All")
                            }
                        }
                        Button("Done") { dismiss() }
                    }
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
            .alert(
                "Delete all \(inProgressMatches.count) unfinished games?",
                isPresented: $showsDeleteAllAlert
            ) {
                Button("Delete All", role: .destructive) {
                    let deletingActive = inProgressMatches.contains { $0.id == activeMatchID }
                    for m in inProgressMatches { modelContext.delete(m) }
                    if deletingActive { onActiveMatchDeleted?() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showsStagingLog) {
                GameNightLogSheet(title: "Staging Log", content: GameNightLogBuffer.shared.stagingLogContent())
            }
            .sheet(isPresented: $showsPreviousLog) {
                GameNightLogSheet(title: "Previous Log", content: GameNightLogBuffer.shared.previousLogContent())
            }
        }
    }
}

#Preview {
    MatchHistoryView()
        .modelContainer(for: MatchModel.self, inMemory: true)
}
