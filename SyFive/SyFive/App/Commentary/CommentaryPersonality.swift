import Foundation
import SyLibCommentary

extension CommentaryPersonality where Kind == CommentaryEventKind {
    // Defined in Pack+Sports.swift, Pack+Zen.swift, Pack+Steady.swift, Pack+Snarky.swift
    static let all: [CommentaryPersonality<CommentaryEventKind>] = [.sports, .zen, .steady, .snarky]

    static func find(id: String) -> CommentaryPersonality<CommentaryEventKind> {
        all.first { $0.id == id } ?? .zen
    }
}
