//
//  DicePill.swift
//  SyFive
//
//  Created by Wayne Mock on 2/22/26.
//


import SwiftUI

struct DicePill: View {
    let value: Int
    let isHeld: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .frame(width: 72, height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isHeld ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isHeld ? Color.primary : Color.primary.opacity(0.2), lineWidth: isHeld ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isEnabled)
    }
}
