import Foundation
import GroupActivities
import CoreTransferable
import SyLibGameNight

/// The GroupActivities activity type for a SyFive Game Night session.
/// One instance per active table; the metadata title is surfaced by the system
/// in the FaceTime call UI and in the SharePlay system sheet.
nonisolated struct GameNightActivity: GroupActivity, Codable, Transferable, GameNightHostTokenCarrying {
    static let activityIdentifier = "com.syzygy.syfive.gamenight"
    static let title = "SyFive Game Night"

    /// The Tap to Play host's token (17 §2.8, D-215); nil for the picker path.
    var hostToken: UUID? = nil

    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata()
        m.title = Self.title
        m.type = .generic
        return m
    }
}
