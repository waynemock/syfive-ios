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

	private struct Keys	{
		static let acknowledgedUpdateVersion = "AcknowledgedUpdateVersion"
		static let deviceID = "DeviceID"
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
