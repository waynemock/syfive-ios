import SwiftUI

extension ContentView {

    @ViewBuilder
    func geometryContent(proxy: GeometryProxy) -> some View {
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

    var navigationTitle: String {
        if model.isGameOver {
            let names = model.winnerNames.joined(separator: ", ")
            return names.isEmpty ? "SyFive" : "\(names) Wins"
        }
        if model.hasStarted {
            if let names = model.leadingPlayerLabel, !names.isEmpty {
                return "\(names) • Turn \(model.currentRound)/\(model.totalRounds)"
            }
            return "Turn \(model.currentRound)/\(model.totalRounds)"
        }
        return "SyFive"
    }

    func debugColor(_ color: Color) -> Color {
        showsDebugLayout ? color : Color.clear
    }
}

struct ContentLayoutSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
