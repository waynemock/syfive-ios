//
//  ScoreRow.swift
//  SyFive
//
//  Created by Wayne Mock on 2/22/26.
//


import SwiftUI

struct ScoreRow: View {
    struct PlayerCell: Identifiable {
        let id: Int
        let value: Int?
        let suggested: Int
        let isBestSuggested: Bool
        let isAvailable: Bool
        let canScore: Bool
        let isCurrentPlayer: Bool
        let isWinner: Bool
        let onSelect: () -> Void
    }

    let players: [PlayerCell]
    let theme: Theme
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let rowAction: (() -> Void)?

    @Environment(\.suggestedMoveEnabled) private var suggestedMoveEnabled

    var body: some View {
        let rowContent = HStack(spacing: 12) {
            ForEach(players) { player in
                scoreCell(for: player)
                    .frame(width: columnWidth)
                    .frame(minHeight: rowHeight)
            }
        }

        if let rowAction {
            Button(action: rowAction) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle())
        } else {
            rowContent
        }
    }

    @ViewBuilder
    private func scoreCell(for player: PlayerCell) -> some View {
        let isScorable = player.isAvailable && player.canScore
        let isPulse = isScorable && player.isBestSuggested && suggestedMoveEnabled

        if rowAction == nil, isScorable {
            Button(action: player.onSelect) {
                scoreCellContent(for: player, isScorable: isScorable, isPulse: isPulse)
                    .contentShape(Rectangle())
            }
            .buttonStyle(CardButtonStyle())
        } else {
            scoreCellContent(for: player, isScorable: isScorable, isPulse: isPulse)
        }
    }

    private func scoreCellContent(for player: PlayerCell, isScorable: Bool, isPulse: Bool) -> some View {
        scoreText(for: player)
            .fontWeight(isPulse ? .bold : .regular)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(cellHighlight(for: player))
            )
            .overlay {
                if isScorable {
                    if isPulse {
                        PulsingOutline(color: theme.secondaryAccent)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.primaryAccent.opacity(0.7), lineWidth: 1.5)
                            .shadow(color: theme.primaryAccent.opacity(0.35), radius: 4)
                    }
                }
            }
    }

    private func scoreText(for player: PlayerCell) -> some View {
        Group {
            if let value = player.value {
                Text(value, format: .number)
                    .foregroundStyle(scoreForeground(for: player))
            } else if player.canScore {
                Text(player.suggested, format: .number)
                    .foregroundStyle(scoreForeground(for: player))
            } else {
                Text("--")
                    .foregroundStyle(scoreForeground(for: player))
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cellHighlight(for player: PlayerCell) -> Color {
        if player.isAvailable && player.canScore {
            return theme.primaryAccent.opacity(0.28)
        }
        if player.isWinner {
            return theme.primaryAccent.opacity(0.18)
        }
        if player.isCurrentPlayer {
            return theme.primaryAccent.opacity(0.12)
        }
        return Color.clear
    }

    private func scoreForeground(for player: PlayerCell) -> Color {
        if player.value != nil {
            return theme.primaryAccent.opacity(0.78)
        }
        if player.canScore {
            return theme.primaryAccent.opacity(0.9)
        }
        return theme.primaryAccent.opacity(0.45)
    }
}

private struct PulsingOutline: View {
    let color: Color
    @State private var glowing = false

    var body: some View {
        ZStack {
            // Fill breathes: adds a tint on top of the existing background
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(glowing ? 0.22 : 0))
            // Border: always at least as bright as a static scoreable cell
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(color.opacity(glowing ? 1.0 : 0.6), lineWidth: 1.5)
                .shadow(color: color.opacity(glowing ? 0.75 : 0.1), radius: glowing ? 12 : 3)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    ScoreRow(
        players: [
            ScoreRow.PlayerCell(
                id: 0,
                value: nil,
                suggested: 12,
                isBestSuggested: false,
                isAvailable: true,
                canScore: true,
                isCurrentPlayer: true,
                isWinner: false
            ) {},
            ScoreRow.PlayerCell(
                id: 1,
                value: 18,
                suggested: 0,
                isBestSuggested: false,
                isAvailable: false,
                canScore: false,
                isCurrentPlayer: false,
                isWinner: false
            ) {},
            ScoreRow.PlayerCell(
                id: 2,
                value: nil,
                suggested: 24,
                isBestSuggested: true,
                isAvailable: true,
                canScore: true,
                isCurrentPlayer: false,
                isWinner: false
            ) {}
        ],
        theme: Theme(),
        columnWidth: 64,
        rowHeight: 32,
        rowAction: nil
    )
    .padding()
}
