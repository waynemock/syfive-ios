import Foundation
import UIKit
import SyLibCore

// A lasting record of what abandonMatch deletes (34 §2.7), as it was of the legacy match repair's
// deletes from 34.7 until that repair was retired in 34.10. AppLogger writes at info level, which
// iOS doesn't keep, so a lost game couldn't be traced. Each line goes to
// Application Support/RepairLog/repair-log.txt, which survives relaunch. Read it from Xcode ›
// Devices and Simulators › SyFive › Download Container. No in-app screen.
enum RepairLog {
    /// Past this size the file keeps its newest half, cut at a line break.
    static let capBytes: UInt64 = 256 * 1024

    /// Where lines go. Nil, the default, is the app's own file; tests point it at a temporary folder.
    static var fileURL: URL?

    private static let logger = AppLogger(category: "RepairLog")

    private static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "RepairLog/repair-log.txt")
    }

    /// Appends `line`, prefixed with an ISO 8601 UTC timestamp and the device model. Never throws:
    /// a failure is logged and the line is lost.
    static func record(_ line: String) {
        let url = fileURL ?? defaultURL
        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(UIDevice.current.model) \(line)\n"
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                guard FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil) else {
                    logger.error(Self.self, "couldn't create \(url.lastPathComponent)")
                    return
                }
            }
            let handle = try FileHandle(forUpdating: url)
            defer { try? handle.close() }
            // The size comes from the open handle, never from file attributes, so the privacy
            // manifest needs no file-timestamp reason (35).
            let end = try handle.seekToEnd()
            let data = Data(stamped.utf8)
            try handle.write(contentsOf: data)
            if end + UInt64(data.count) > capBytes {
                try keepNewestHalf(of: handle)
            }
        } catch {
            logger.error(Self.self, "record failed: \(error)")
        }
    }

    /// Rewrites the file as its newest half, starting after the first line break in that half so
    /// the first line kept is whole.
    private static func keepNewestHalf(of handle: FileHandle) throws {
        try handle.seek(toOffset: 0)
        let contents = try handle.readToEnd() ?? Data()
        let halfStart = contents.startIndex + contents.count / 2
        let kept: Data
        if let lineBreak = contents[halfStart...].firstIndex(of: UInt8(ascii: "\n")) {
            kept = Data(contents[contents.index(after: lineBreak)...])
        } else {
            kept = Data()
        }
        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: kept)
    }
}
