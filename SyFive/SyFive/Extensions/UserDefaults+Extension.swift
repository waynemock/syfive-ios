//
//  UserDefaultsExtension.swift
//  SyFLUX
//
//  Created by Wayne Mock on 1/25/19.
//  Copyright © 2020 Syzygy Softwerks LLC. All rights reserved.
//

import Foundation
import UIKit

extension UserDefaults {

	private struct Keys {
		static let acknowledgedUpdateVersion = "AcknowledgedUpdateVersion"
		static let deviceID = "DeviceID"
        static let commentaryVoiceID = "commentaryVoiceID"
	}

    // MARK: - Commentary

    var commentaryVoiceID: String? {
        get { string(forKey: Keys.commentaryVoiceID) }
        set { set(newValue, forKey: Keys.commentaryVoiceID) }
    }

    // MARK: - Game Night

    func gnIsHost(for sessionID: UUID) -> Bool {
        bool(forKey: "gn.host.\(sessionID.uuidString)")
    }

    func setGnIsHost(for sessionID: UUID) {
        set(true, forKey: "gn.host.\(sessionID.uuidString)")
    }

    func removeGnIsHost(for sessionID: UUID) {
        removeObject(forKey: "gn.host.\(sessionID.uuidString)")
    }

    func gnParticipantID(for matchID: UUID) -> UUID? {
        guard let str = string(forKey: "gn.participantID.\(matchID.uuidString)") else { return nil }
        return UUID(uuidString: str)
    }

    func setGnParticipantID(_ pid: UUID, for matchID: UUID) {
        set(pid.uuidString, forKey: "gn.participantID.\(matchID.uuidString)")
    }

    func gnWasHost(for matchID: UUID) -> Bool {
        bool(forKey: "gn.wasHost.\(matchID.uuidString)")
    }

    func setGnWasHost(for matchID: UUID) {
        set(true, forKey: "gn.wasHost.\(matchID.uuidString)")
    }

	/// The app version that the user has acknowledged for updates.
	///
	/// When an update is available, we show a badge until the user opens the menu.
	/// After opening the menu, we store the current version so the badge doesn't show again
	/// for this version, but the menu item remains visible.
	public var acknowledgedUpdateVersion: String? {
		get {
			return string(forKey: Keys.acknowledgedUpdateVersion)
		}
		set {
			set(newValue, forKey: Keys.acknowledgedUpdateVersion)
		}
	}
	
	/// Unique device identifier for device-specific settings.
	///
	/// Uses identifierForVendor when available, falls back to a random UUID.
	/// Persisted in UserDefaults to remain stable across app launches.
	/// Read-only to prevent accidental overwrites.
	public var deviceID: String {
		if let stored = string(forKey: Keys.deviceID) {
			return stored
		}
		let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
		set(newID, forKey: Keys.deviceID)
		return newID
	}
}
