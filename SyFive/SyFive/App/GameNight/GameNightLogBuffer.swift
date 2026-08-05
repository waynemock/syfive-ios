import Foundation

/// Thread-safe in-memory log buffer for a single Game Night session.
/// Accumulates entries while a session is live; flushes to disk when the session tears down.
/// Only active when `AppConfig.DebugGameNight.showLogs` is true.
final class GameNightLogBuffer: @unchecked Sendable {
    static let shared = GameNightLogBuffer()

    private let lock = NSLock()
    private var currentMatchID: UUID?
    private var entries: [String] = []

    private static let gnCategories: Set<String> = [
        "GameNightController", "MatchController", "ContentView",
        "GameNightActivity", "SessionController", "MatchPresenting",
    ]

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Lifecycle

    /// Begin a new session log, discarding any prior in-memory entries.
    func startSession() {
        guard AppConfig.DebugGameNight.showLogs else { return }
        lock.withLock {
            currentMatchID = nil
            entries = []
        }
        AppLogger.sinks["gameNight"] = { [weak self] category, level, message in
            guard Self.gnCategories.contains(category) else { return }
            self?.append(category: category, level: level, message: message)
        }
    }

    /// Associate the running session with a persisted match ID so flush can write the file.
    func associateMatch(matchID: UUID) {
        guard AppConfig.DebugGameNight.showLogs else { return }
        lock.withLock {
            guard currentMatchID == nil else { return }
            currentMatchID = matchID
        }
    }

    /// Write accumulated entries to `<Documents>/gnlogs/<matchID>.log`.
    /// Safe to call from any thread. No-op if no matchID has been associated yet.
    func flushToDisk() {
        guard AppConfig.DebugGameNight.showLogs else { return }
        AppLogger.sinks.removeValue(forKey: "gameNight")
        let (matchID, content): (UUID?, String) = lock.withLock {
            (currentMatchID, entries.joined(separator: "\n"))
        }
        guard let matchID, !content.isEmpty else { return }
        let url = logFileURL(for: matchID)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Query

    func hasLog(for matchID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: logFileURL(for: matchID).path)
    }

    func logContent(for matchID: UUID) -> String {
        (try? String(contentsOf: logFileURL(for: matchID), encoding: .utf8)) ?? "(no log found)"
    }

    // MARK: - Private

    private func append(category: String, level: String, message: String) {
        let ts = Self.timeFormatter.string(from: Date())
        let line = "\(ts) [\(category)/\(level)] \(message)"
        lock.withLock { entries.append(line) }
    }

    private func logFileURL(for matchID: UUID) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("gnlogs/\(matchID.uuidString).log")
    }
}
