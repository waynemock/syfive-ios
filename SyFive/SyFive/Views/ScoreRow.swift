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
        let background = RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(cellHighlight(for: player))
        let outline = RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(theme.primaryAccent.opacity(player.isAvailable && player.canScore ? 0.7 : 0), lineWidth: 1.5)
            .shadow(color: theme.primaryAccent.opacity(player.isAvailable && player.canScore ? 0.35 : 0), radius: 4, x: 0, y: 0)

        if rowAction == nil, player.isAvailable && player.canScore {
            Button(action: player.onSelect) {
                scoreText(for: player)
                    .background(background)
                    .overlay(outline)
            }
            .buttonStyle(CardButtonStyle())
        } else {
            scoreText(for: player)
                .background(background)
                .overlay(outline)
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
            return theme.successColor.opacity(0.18)
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
                isAvailable: true,
                canScore: true,
                isCurrentPlayer: true,
                isWinner: false
            ) {},
            ScoreRow.PlayerCell(
                id: 1,
                value: 18,
                suggested: 0,
                isAvailable: false,
                canScore: false,
                isCurrentPlayer: false,
                isWinner: false
            ) {},
            ScoreRow.PlayerCell(
                id: 2,
                value: nil,
                suggested: 24,
                isAvailable: true,
                canScore: false,
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
