import Foundation
import SyLibCore
import UIKit

extension UserDefaults {

    // All UserDefaults key strings in one place. Use Key.* in @AppStorage declarations
    // so key strings are never duplicated across files.
    // acknowledgedUpdateVersion is provided by SyLibCore (key: "SyLib.AcknowledgedUpdateVersion").
    enum Key {
        static let deviceID                     = "syfive.deviceID"
        static let commentaryVoiceID            = "syfive.commentary.voiceID"
    }

    // MARK: - App

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
