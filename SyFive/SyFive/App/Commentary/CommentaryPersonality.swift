import Foundation

struct CommentaryPersonality {
    let id: String
    let displayName: String
    let blurb: String
    let prosody: CommentaryProsody
    let previewLine: String
    let lines: [CommentaryEventKind: [String]]
}

struct CommentaryProsody {
    var rate: Float
    var pitchMultiplier: Float
    var preUtteranceDelay: TimeInterval
    var postUtteranceDelay: TimeInterval
}

extension CommentaryPersonality {
    // Defined in Pack+Sports.swift, Pack+Zen.swift, Pack+Steady.swift, Pack+Snarky.swift
    static let all: [CommentaryPersonality] = [.sports, .zen, .steady, .snarky]

    static func find(id: String) -> CommentaryPersonality {
        all.first { $0.id == id } ?? .zen
    }
}
