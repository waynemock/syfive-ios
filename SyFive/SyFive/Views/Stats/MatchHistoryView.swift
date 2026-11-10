import SwiftUI
import SyLibUI
import SwiftData
import SyLibGameNight
import SyLibScoring
import SyLibScoringData
import SyLibScoringUI

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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.syTheme) private var theme

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "completed" },
           sort: \MatchModel.startedAt, order: .reverse)
    private var completedRows: [MatchModel]
    /// One row per match id, so a game two devices both stored counts once (34 §2.8).
    private var completedMatches: [MatchModel] { completedRows.onePerMatchID() }

    @Query(filter: #Predicate<MatchModel> { $0.statusRaw == "inProgress" },
           sort: \MatchModel.startedAt, order: .reverse)
    private var inProgressRows: [MatchModel]
    /// One row per match id, so a game two devices both stored counts once (34 §2.8).
    private var inProgressMatches: [MatchModel] { inProgressRows.onePerMatchID() }

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
                    SegmentedPicker("", selection: $segment,
                                    segments: [(.finished, "Finished"),
                                               (.unfinished, "Unfinished (\(inProgressMatches.count))")])
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
                            .paletteRowBackground()
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
                            .paletteRowBackground()
                        }
                    }
                    if segment == .finished {
                        ForEach(completedMatches) { matchModel in
                            NavigationLink {
                                MatchDetailView(matchModel: matchModel)
                            } label: {
                                let m = matchModel.toDomain()
                                let winner = m.participants.sorted { $0.rank < $1.rank }.first { $0.rank == 1 }
                                MatchHistoryRow(match: m, accentColor: SyTheme.accent(forParticipant: winner, colorScheme: colorScheme))
                            }
                        }
                        .paletteRowBackground()
                    } else {
                        ForEach(inProgressMatches) { matchModel in
                            NavigationLink {
                                UnfinishedMatchDetailView(matchModel: matchModel) { m in
                                    onResume?(m)
                                }
                            } label: {
                                let m = matchModel.toDomain()
                                let leader = m.participants.sorted { $0.finalScore > $1.finalScore }.first
                                UnfinishedMatchRow(match: m, accentColor: SyTheme.accent(forParticipant: leader, colorScheme: colorScheme))
                            }
                        }
                        .onDelete { indexSet in
                            guard let i = indexSet.first else { return }
                            matchToDelete = inProgressMatches[i]
                        }
                        .paletteRowBackground()
                    }
                }
                .paletteListBackground()
                .animation(.default, value: segment)
                .onAppear {
                    stagingLogExists = GameNightLogBuffer.shared.hasStagingLog()
                    previousLogExists = GameNightLogBuffer.shared.hasPreviousLog()
                }
            }
            .background(theme.backgroundColor)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .paletteBarBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if segment == .unfinished && !inProgressMatches.isEmpty {
                        Button(role: .destructive) {
                            showsDeleteAllAlert = true
                        } label: {
                            Text("Delete All")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: inProgressMatches.isEmpty) { _, isEmpty in
                if isEmpty { segment = .finished }
            }
            .overlay {
                if segment == .finished && completedMatches.isEmpty {
                    EmptyStateView(systemImage: "list.bullet.rectangle",
                                   title: "No completed games",
                                   message: "Finished games will appear here.")
                } else if segment == .unfinished && inProgressMatches.isEmpty {
                    EmptyStateView(systemImage: "checkmark.circle",
                                   title: "No unfinished games",
                                   message: "All your games have been finished.")
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
                        // The match and its participants, so no orphan still names its players (34 §2.4),
                        // and every stored copy of its id, not only the row shown (34 §2.8).
                        _ = try? deleteMatches(id: m.id, in: modelContext)
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
                    // Each match and its participants, so no orphan still names its players (34 §2.4),
                    // over the raw query so every stored copy goes, not only the rows shown (34 §2.8).
                    for m in inProgressRows { deleteMatch(m, in: modelContext) }
                    if deletingActive { onActiveMatchDeleted?() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showsStagingLog) {
                GameNightLogSheet(title: "Staging Log", content: GameNightLogBuffer.shared.stagingLogContent())
                    .sheetTextSizeCeiling()
            }
            .sheet(isPresented: $showsPreviousLog) {
                GameNightLogSheet(title: "Previous Log", content: GameNightLogBuffer.shared.previousLogContent())
                    .sheetTextSizeCeiling()
            }
        }
        .tint(theme.primaryAccent)
    }
}

#Preview {
    MatchHistoryView()
        .modelContainer(for: MatchModel.self, inMemory: true)
}
