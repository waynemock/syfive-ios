import Foundation
import SyLibScoring
import SyLibCore

/// Writes Game Night session logs directly to disk as each entry arrives.
/// Logs land in `<Documents>/gnlogs/current.log` from the moment the session
/// starts, then are renamed to `<matchID>.log` once the match ID is known.
/// The open FileHandle follows the renamed file's inode on POSIX, so no entries
/// are lost during the rename. Only active when `AppConfig.DebugGameNight.showLogs` is true.
final class GameNightLogBuffer: @unchecked Sendable {
    static let shared = GameNightLogBuffer()

    private let lock = NSLock()
    private var currentMatchID: UUID?
    nonisolated(unsafe) private var fileHandle: FileHandle?

    private static let gnCategories: Set<String> = [
        "GameNightController", "MatchController", "ContentView",
        "GameNightActivity", "SessionController", "MatchPresenting",
    ]


    // MARK: - Lifecycle

    /// Begin a new session log. Creates (or truncates) the staging file and
    /// opens a FileHandle so every subsequent log line is written immediately.
    func startSession() {
        guard AppConfig.DebugGameNight.showLogs else { return }
        lock.withLock {
            closeFileHandle()
            currentMatchID = nil
        }
        let url = stagingURL()
        prepareDirs(for: url)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let fh = try? FileHandle(forWritingTo: url)
        lock.withLock { fileHandle = fh }
        let categories = Self.gnCategories
        AppLogger.sinks["gameNight"] = { @Sendable [weak self] category, level, message in
            guard categories.contains(category) else { return }
            self?.appendLine(category: category, level: level, message: message)
        }
    }

    /// Associate the running session with a persisted match ID.
    /// Renames the staging file to `<matchID>.log`; the open FileHandle
    /// continues writing to the same inode transparently.
    func associateMatch(matchID: UUID) {
        guard AppConfig.DebugGameNight.showLogs else { return }
        let alreadySet: Bool = lock.withLock {
            guard currentMatchID == nil else { return true }
            currentMatchID = matchID
            return false
        }
        guard !alreadySet else { return }
        let from = stagingURL()
        let to = logFileURL(for: matchID)
        // Remove any stale log for this matchID before renaming.
        try? FileManager.default.removeItem(at: to)
        try? FileManager.default.moveItem(at: from, to: to)
    }

    /// Stop logging and sync the file to disk. Safe to call multiple times.
    func flushToDisk() {
        guard AppConfig.DebugGameNight.showLogs else { return }
        AppLogger.sinks.removeValue(forKey: "gameNight")
        lock.withLock { closeFileHandle() }
    }

    // MARK: - Query

    func hasLog(for matchID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: logFileURL(for: matchID).path)
    }

    func logContent(for matchID: UUID) -> String {
        (try? String(contentsOf: logFileURL(for: matchID), encoding: .utf8)) ?? "(no log found)"
    }

    // MARK: - Private

    private nonisolated func appendLine(category: String, level: String, message: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        let ts = f.string(from: Date())
        let line = "\(ts) [\(category)/\(level)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        lock.withLock {
            guard let fh = fileHandle else { return }
            _ = try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
        }
    }

    private func closeFileHandle() {
        guard let fh = fileHandle else { return }
        try? fh.synchronize()
        try? fh.close()
        fileHandle = nil
    }

    private func stagingURL() -> URL {
        logDir().appendingPathComponent("current.log")
    }

    private func logFileURL(for matchID: UUID) -> URL {
        logDir().appendingPathComponent("\(matchID.uuidString).log")
    }

    private func logDir() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gnlogs")
    }

    private func prepareDirs(for url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
