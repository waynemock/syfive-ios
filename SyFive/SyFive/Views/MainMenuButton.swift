//
//  MainMenuButton.swift
//  SyFLUX
//
//  Created by Wayne Mock on 2/20/26.
//


import SwiftUI
import SwiftData
import SpriteKit

struct MainMenuButton: View {
    @Environment(\.theme) var theme: Theme
    
    let showBadge: Bool

    @ScaledMetric private var badgeSize: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)

            if showBadge {
                Circle()
                    .fill(theme.primaryAccent)
                    .frame(width: badgeSize, height: badgeSize)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.8), lineWidth: 1)
                    )
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(showBadge ? "Menu, update available" : "Menu")
    }
}
