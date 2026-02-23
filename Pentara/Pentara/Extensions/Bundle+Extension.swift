import UIKit

// MARK: - Bundle Extension

extension Bundle {
    /// The app icon image from the bundle.
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
    
    /// The app version string, including build number if different from version.
    var appVersion: String {
        let version = appVersionShort
        let build = infoDictionary?["CFBundleVersion"] as? String
        
        if let build = build, build != version {
            return "\(version) (\(build))"
        }
        return version
    }

    /// The short version of the app version, no build number
    var appVersionShort: String {
        return (infoDictionary?["CFBundleShortVersionString"] as? String)?.components(separatedBy: " ").first ?? "1.0"
    }
}

