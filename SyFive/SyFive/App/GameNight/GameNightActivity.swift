import Foundation
import GroupActivities

/// The GroupActivities activity type for a SyFive Game Night session.
/// One instance per active table; the metadata title is surfaced by the system
/// in the FaceTime call UI and in the SharePlay system sheet.
struct GameNightActivity: GroupActivity, Codable {
    static let activityIdentifier = "com.syzygy.syfive.gamenight"

    var metadata: GroupActivityMetadata {
        var m = GroupActivityMetadata()
        m.title = "SyFive Game Night"
        m.type = .generic
        return m
    }
}
