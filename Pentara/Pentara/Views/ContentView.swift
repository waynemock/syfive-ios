import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()
    @Environment(\.colorScheme) private var colorScheme
    private let showsDebugLayout = AppConfig.DebugLayout.isEnabled

    var body: some View {
        let theme = Theme(type: .midnight, colorScheme: colorScheme)
        NavigationStack {
            GeometryReader { proxy in
                let isPortrait = proxy.size.height >= proxy.size.width
                Group {
                    if isPortrait {
                        VStack(spacing: 12) {
                            DiceAreaView(model: model)
                                .background(debugColor(Color.red.opacity(0.25)))
                                .frame(maxHeight: .infinity, alignment: .top)
                            ScorecardView(model: model)
                                .padding(.horizontal, -24)
                                .background(debugColor(Color.green.opacity(0.25)))
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                    } else {
                        HStack(spacing: 20) {
                            DiceAreaView(model: model)
                                .background(debugColor(Color.red.opacity(0.25)))
                                .frame(maxWidth: .infinity, alignment: .top)
                            ScorecardView(model: model)
                                .padding(.horizontal, -24)
                                .background(debugColor(Color.green.opacity(0.25)))
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 24)
            }
            .background(debugColor(Color.yellow.opacity(0.25)))
            .background(theme.backgroundColor)
            .overlay(showsDebugLayout ? SafeAreaDebugView() : nil)
            .navigationTitle("Pentara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.resetGame()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Game")
                }
            }
        }
        .tint(theme.primaryAccent)
        .environment(\.theme, theme)
    }

    private func debugColor(_ color: Color) -> Color {
        showsDebugLayout ? color : Color.clear
    }

}

#Preview {
    ContentView()
}
