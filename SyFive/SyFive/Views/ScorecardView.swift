import SwiftUI
import Observation
import SyLibCore
import SyLibFeel
import SyLibYatzy

struct ScorecardView: View {
    @Bindable var model: MatchController
    let availableWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.theme) private var theme
    @State private var showsPlayerPicker = false
    @State private var measuredLabelWidth: CGFloat = 0

    private let scoreColumnWidth: CGFloat = 64
    private let scoreRowHeight: CGFloat = 32
    private let headerRowHeight: CGFloat = 28
    private let scoreSectionSpacing: CGFloat = 14
    private let scoreRowSpacing: CGFloat = 6
    private let cardEdgeInset: CGFloat = 24
    private let cardGap: CGFloat = 16
    private let peekAmount: CGFloat = 20
    private let logger = AppLogger(category: "ScorecardView")

    var body: some View {
        Group {
            if model.canEditPlayers {
                PreGameGridView(model: model) {
                    showsPlayerPicker = true
                }
            } else {
                inGameView
            }
        }
        .background(
            // Hidden probe: measures the widest label text at the user's actual
            // Dynamic Type size. Rendered at natural size then clipped to 0×0
            // so it has no effect on layout.
            sectionLabelProbe
                .fixedSize(horizontal: true, vertical: true)
                .background(GeometryReader { geo in
                    Color.clear.preference(key: LabelWidthKey.self, value: geo.size.width)
                })
                .frame(width: 0, height: 0)
                .clipped()
        )
        .onPreferenceChange(LabelWidthKey.self) { width in
            if width > 0 { measuredLabelWidth = width }
        }
        .sheet(isPresented: $showsPlayerPicker) {
            PlayerPickerSheet(model: model)
                .environment(\.theme, theme)
        }
    }

    private var inGameView: some View {
        let cardWidth = singleCardWidth(for: availableWidth)
        return ScrollViewReader { verticalProxy in
            ScrollView(.vertical, showsIndicators: false) {
                Color.clear
                    .frame(height: 0)
                    .id("scorecard-top")
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 16) {
                            ForEach(Array(model.slotIDs.enumerated()), id: \.element) { index, _ in
                                let metrics = cardMetrics(for: cardWidth)
                                PlayerScoreCardView(
                                    model: model,
                                    playerIndex: index,
                                    scoreColumnWidth: scoreColumnWidth,
                                    scoreRowHeight: scoreRowHeight,
                                    headerRowHeight: headerRowHeight,
                                    scoreSectionSpacing: scoreSectionSpacing,
                                    scoreRowSpacing: scoreRowSpacing,
                                    horizontalPadding: metrics.horizontalPadding,
                                    sectionGap: metrics.sectionGap
                                )
                                .frame(width: cardWidth)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, cardEdgeInset)
                    }
                    .onAppear {
                        scrollToCurrentPlayer(using: scrollProxy)
                    }
                    .onChange(of: model.currentPlayerIndex) {
                        scrollToCurrentPlayer(using: scrollProxy)
                    }
                    .onChange(of: model.isGameOver) { _, isGameOver in
                        guard isGameOver else { return }
                        celebrateWinningPlayer(using: scrollProxy, verticalProxy: verticalProxy)
                    }
                }
            }
            .onChange(of: model.currentPlayerIndex) {
                let delay = 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        verticalProxy.scrollTo("scorecard-top", anchor: .top)
                    }
                }
            }
        }
        .coordinateSpace(name: "scorecardVertical")
        .onChange(of: availableWidth) { _, width in
            let computed = singleCardWidth(for: width)
            logger.debug(
                self,
                "width update: available=\(width), computed=\(computed), players=\(model.playerCount), sizeCategory=\(sizeCategory)"
            )
        }
    }

    private func scrollToCurrentPlayer(using proxy: ScrollViewProxy) {
        guard model.playerCount > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(model.currentPlayerIndex, anchor: .center)
        }
    }

    private func celebrateWinningPlayer(using horizontalProxy: ScrollViewProxy, verticalProxy: ScrollViewProxy) {
        guard let winningPlayerIndex = model.winnerIndices.first else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            verticalProxy.scrollTo("scorecard-top", anchor: .top)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                horizontalProxy.scrollTo(winningPlayerIndex, anchor: .center)
            }
        }
    }

    private func singleCardWidth(for availableWidth: CGFloat) -> CGFloat {
        let resolved = availableWidth == 0 ? 393 : availableWidth
        let usable = max(0, resolved - cardEdgeInset * 2)

        if model.playerCount <= 1 {
            // Single player: fill available space — no cap needed.
            let result = max(280, usable)
            logger.debug(self, "singleCardWidth(single): \(result)")
            return result
        }

        // Multi-player: compute ideal card width from the probe-measured label
        // width. This accounts for the user's Dynamic Type size automatically.
        // Falls back to 82pt if the probe hasn't fired yet (first frame).
        let labelWidth = measuredLabelWidth > 0 ? measuredLabelWidth : 82
        // Per-section minimum: label + HStack spacing + score column + 4pt breathing room.
        let idealSectionWidth = labelWidth + 2 + scoreColumnWidth + 4
        // Full card: two sections + section gap (12) + horizontal padding each side (14×2=28).
        let idealCardWidth = max(280, 2 * idealSectionWidth + 12 + 28)

        // On wide screens where two content-sized cards fit simultaneously, use
        // that width so the screen fills nicely (sections stretch via maxWidth:.infinity).
        let twoCardFit = (usable - cardGap) / 2
        let result: CGFloat
        if twoCardFit >= 280 && twoCardFit >= idealCardWidth {
            result = twoCardFit
        } else {
            // Narrow screen: use content-driven width but cap so there's always a
            // peek at the adjacent card, which tells the user they can scroll.
            let peekedMax = max(280, resolved - cardEdgeInset - cardGap - peekAmount)
            result = min(idealCardWidth, peekedMax)
        }

        logger.debug(
            self,
            "singleCardWidth(multi): label=\(labelWidth), ideal=\(idealCardWidth), twoCardFit=\(twoCardFit), result=\(result)"
        )
        return result
    }

    // All category label texts + the longest summary label, stacked so SwiftUI
    // sizes the VStack to the widest entry. Measured via a hidden 0×0 probe.
    private var sectionLabelProbe: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(YatzyCategory.allCases) { category in
                Text(category.displayName).font(.subheadline)
            }
            // Summary labels — semibold matches how they render in the card.
            Text("Yatzy Bonus").font(.subheadline.weight(.semibold))
            Text("Subtotal").font(.subheadline.weight(.semibold))
        }
    }

    private func cardMetrics(for cardWidth: CGFloat) -> (horizontalPadding: CGFloat, sectionGap: CGFloat) {
        PlayerScoreCardView.metrics(for: cardWidth)
    }
}

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    ScorecardView(model: MatchController(), availableWidth: 360)
        .environment(FeelDirector(catalog: .syFive))
}
