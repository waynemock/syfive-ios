//
//  ScoreRow.swift
//  Pentara
//
//  Created by Wayne Mock on 2/22/26.
//


import SwiftUI

struct ScoreRow: View {
    let title: String
    let value: Int?
    let suggested: Int
    let isAvailable: Bool
    let canScore: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            guard isAvailable, canScore else { return }
            onSelect()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                Spacer()
                if let value {
                    Text(value, format: .number)
                        .foregroundStyle(.secondary)
                } else if canScore {
                    Text(suggested, format: .number)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1 : 0.45)
    }
}