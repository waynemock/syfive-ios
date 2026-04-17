import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()
    @State private var showsResetAlert = false
    @Environment(\.colorScheme) private var colorScheme
    private let showsDebugLayout = AppConfig.DebugLayout.isEnabled
    private let logger = AppLogger(category: "ContentView")

    var body: some View {
        let theme = Theme(type: .midnight , colorScheme: colorScheme)
        NavigationStack {
            GeometryReader { proxy in
                let isPortrait = proxy.size.height >= proxy.size.width
                let contentWidth = max(0, proxy.size.width - 48)
                let scorecardAvailableWidth = isPortrait
                    ? proxy.size.width
                    : max(0, (contentWidth - 20) / 2 + 48)
                // AnyLayout switches between VStack/HStack while preserving
                // subview identity — this prevents DiceAreaView (and its
                // embedded RealityView) from being destroyed on rotation.
                let layout = isPortrait
                    ? AnyLayout(VStackLayout(spacing: 12))
                    : AnyLayout(HStackLayout(spacing: 20))
                layout {
                    DiceAreaView(model: model)
                        .background(debugColor(Color.red.opacity(0.25)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    ScorecardView(model: model, availableWidth: scorecardAvailableWidth)
                        .padding(.horizontal, -24)
                        .background(debugColor(Color.green.opacity(0.25)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 24)
                .background(Color.clear.preference(key: ContentLayoutSizePreferenceKey.self, value: proxy.size))
                .onAppear {
                    logger.debug(self, "geometry size onAppear: \(proxy.size.width)x\(proxy.size.height)")
                }
                .onChange(of: proxy.size) { _, newSize in
                    let newContentWidth = max(0, newSize.width - 48)
                    let newScorecardWidth = isPortrait
                        ? newSize.width
                        : max(0, (newContentWidth - 20) / 2 + 48)
                    logger.debug(self, "geometry size onChange: \(newSize.width)x\(newSize.height)")
                    logger.debug(self, "scorecardAvailableWidth: \(newScorecardWidth)")
                }
            }
            .background(debugColor(Color.yellow.opacity(0.25)))
            .background(theme.backgroundColor)
            .overlay(showsDebugLayout ? SafeAreaDebugView() : nil)
            .onPreferenceChange(ContentLayoutSizePreferenceKey.self) { size in
                let isPortrait = size.height >= size.width
                logger.debug(self, "content size: \(size.width)x\(size.height), isPortrait=\(isPortrait)")
                logger.debug(self, "scorecard width from GeometryReader: \(size.width)")
            }
            .navigationTitle(model.hasStarted ? "Round \(model.currentRound) of \(model.totalRounds)" : "SyFive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if model.hasStarted && !model.isGameOver {
                            showsResetAlert = true
                        } else {
                            model.resetGame()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Game")
                }
            }
            .alert("Start a new game?", isPresented: $showsResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Start Over", role: .destructive) {
                    model.resetGame()
                }
            } message: {
                Text("This will reset the current game and scores.")
            }
        }
        .tint(theme.primaryAccent)
        .environment(\.theme, theme)
    }

    private func debugColor(_ color: Color) -> Color {
        showsDebugLayout ? color : Color.clear
    }

}

private struct ContentLayoutSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    ContentView()
}
