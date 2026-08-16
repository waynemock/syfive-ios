import Foundation
import UIKit

extension UserDefaults {

    // All UserDefaults key strings in one place. Use Key.* in @AppStorage declarations
    // so key strings are never duplicated across files.
    enum Key {
        static let acknowledgedUpdateVersion    = "syfive.update.acknowledgedVersion"
        static let deviceID                     = "syfive.deviceID"
        static let commentaryVoiceID            = "syfive.commentary.voiceID"

        // Game Night — keyed per-session or per-match UUID.
        static func gnIsHost(sessionID: UUID) -> String      { "syfive.gn.host.\(sessionID.uuidString)" }
        static func gnParticipantID(matchID: UUID) -> String { "syfive.gn.participantID.\(matchID.uuidString)" }
        static func gnWasHost(matchID: UUID) -> String       { "syfive.gn.wasHost.\(matchID.uuidString)" }
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

    // MARK: - Game Night

    func gnIsHost(for sessionID: UUID) -> Bool {
        bool(forKey: Key.gnIsHost(sessionID: sessionID))
    }

    func setGnIsHost(for sessionID: UUID) {
        set(true, forKey: Key.gnIsHost(sessionID: sessionID))
    }

    func removeGnIsHost(for sessionID: UUID) {
        removeObject(forKey: Key.gnIsHost(sessionID: sessionID))
    }

    func gnParticipantID(for matchID: UUID) -> UUID? {
        guard let str = string(forKey: Key.gnParticipantID(matchID: matchID)) else { return nil }
        return UUID(uuidString: str)
    }

    func setGnParticipantID(_ pid: UUID, for matchID: UUID) {
        set(pid.uuidString, forKey: Key.gnParticipantID(matchID: matchID))
    }

    func gnWasHost(for matchID: UUID) -> Bool {
        bool(forKey: Key.gnWasHost(matchID: matchID))
    }

    func setGnWasHost(for matchID: UUID) {
        set(true, forKey: Key.gnWasHost(matchID: matchID))
    }
}
