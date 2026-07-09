import Foundation

/// Checks for app updates available on the App Store.
actor AppUpdateChecker {

    static let shared = AppUpdateChecker()

    private nonisolated static let logger = AppLogger(category: "AppUpdateChecker")

    private var cachedResult: Bool?
    private var lastCheckTime: Date?

    /// Minimum time interval between checks (default: 24 hours)
    private let minimumCheckInterval: TimeInterval = 3600 * 24

    /// Optional: keep the last store version for UI/debug
    private var cachedStoreVersion: String?

    /// Checks if an update is available on the App Store.
    /// Caches the result and only queries the App Store if the cache is stale.
    func isUpdateAvailable() async -> Bool {
        if let cached = cachedResult,
           let lastCheck = lastCheckTime,
           Date().timeIntervalSince(lastCheck) < minimumCheckInterval {
            Self.logger.debug(Self.self, "Returning cached result: \(cached) (store=\(cachedStoreVersion ?? "n/a"))")
            return cached
        }

        let (result, storeVersion) = await performUpdateCheck()

        cachedResult = result
        cachedStoreVersion = storeVersion
        lastCheckTime = Date()

        return result
    }

    /// Performs the actual App Store lookup.
    /// - Returns: (isUpdateAvailable, storeVersion)
    private func performUpdateCheck() async -> (Bool, String?) {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            Self.logger.error(Self.self, "Missing bundle identifier")
            return (false, nil)
        }

        let currentVersion = await MainActor.run {
            Bundle.main.appVersionShort
        }

        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "us"),
            // Bust upstream caches (keyed by full URL)
            URLQueryItem(name: "_", value: String(Int(Date().timeIntervalSince1970)))
        ]

        guard let url = components.url else {
            Self.logger.error(Self.self, "Failed to build lookup URL")
            return (false, nil)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.timeoutInterval = 8

        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse {
                Self.logger.debug(Self.self, "App Store status=\(http.statusCode)")
            }

            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let first = results.first,
                let storeVersion = first["version"] as? String
            else {
                Self.logger.info(Self.self, "No results found (may be propagation or storefront visibility)")
                return (false, nil)
            }

            Self.logger.info(Self.self, "Store version: \(storeVersion) vs Current: \(currentVersion)")

            let updateAvailable =
                storeVersion.compare(currentVersion, options: .numeric) == .orderedDescending

            return (updateAvailable, storeVersion)

        } catch {
            Self.logger.error(Self.self, "Update check failed: \(error.localizedDescription)")
            // Fail closed; don't nag or crash.
            return (false, nil)
        }
    }
}
