import Foundation
import UIKit

extension UserDefaults {

    // All UserDefaults key strings in one place. Use Key.* in @AppStorage declarations
    // so key strings are never duplicated across files.
    enum Key {
        static let acknowledgedUpdateVersion    = "syfive.update.acknowledgedVersion"
        static let deviceID                     = "syfive.deviceID"
        static let commentaryVoiceID            = "syfive.commentary.voiceID"

    }

    // MARK: - App

    var acknowledgedUpdateVersion: String? {
        get { string(forKey: Key.acknowledgedUpdateVersion) }
        set { set(newValue, forKey: Key.acknowledgedUpdateVersion) }
    }

    var deviceID: String {
        if let stored = string(forKey: Key.deviceID) { return stored }
        let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        set(newID, forKey: Key.deviceID)
        return newID
    }

    // MARK: - Commentary

    var commentaryVoiceID: String? {
        get { string(forKey: Key.commentaryVoiceID) }
        set { set(newValue, forKey: Key.commentaryVoiceID) }
    }

}
