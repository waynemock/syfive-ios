import Foundation
import GroupActivities
import CoreTransferable

/// The GroupActivities activity type for a SyFive Game Night session.
/// One instance per active table; the metadata title is surfaced by the system
/// in the FaceTime call UI and in the SharePlay system sheet.
nonisolated struct GameNightActivity: GroupActivity, Codable, Transferable {
    static let activityIdentifier = "com.syzygy.syfive.gamenight"
    static let title = "SyFive Game Night"

    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata()
        m.title = Self.title
        m.type = .generic
        return m
    }
}
