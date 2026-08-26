//
//  Game+BuiltIn.swift
//  SyFive
//

import Foundation
import SyLibScoring

extension Game {
    /// Well-known UUID for SyFive's built-in Yatzy catalog row.
    ///
    /// Fixed so every device seeds the same CloudKit record, preventing
    /// duplicate catalog entries on first sync. This value is frozen — it is
    /// referenced by records already in users' private CloudKit databases and
    /// must never change.
    public static let builtInYatzyID = UUID(uuidString: "BFB7F8F6-87D2-4700-9267-36A8ED4AC3C8")!
}
