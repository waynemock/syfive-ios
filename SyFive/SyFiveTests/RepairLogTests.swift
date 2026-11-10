import Foundation
import Testing
@testable import SyFive

// RepairLog is main-actor isolated under the app target's default isolation, so the suite is too.
// The test is synchronous, so nothing in the host app can record while fileURL points elsewhere.
// 34 §2.6, Task 34.7.
@MainActor
struct RepairLogTests {

    /// A timestamp, the device model, then the line recorded.
    private let wholeLine = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z (iPhone|iPad|iPod touch) (.+)$/

    private func lines(at url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    @Test("The repair log appends lines in order, and past its cap keeps the newest, whole")
    func repairLogAppendsInOrderAndKeepsTheNewestWhole() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "RepairLogTests-\(UUID().uuidString)")
        defer {
            RepairLog.fileURL = nil
            try? FileManager.default.removeItem(at: folder)
        }

        // Two records, two lines, in order; the folder and file are created on the first.
        let short = folder.appending(path: "short/repair-log.txt")
        RepairLog.fileURL = short
        RepairLog.record("first")
        RepairLog.record("second")
        let two = try lines(at: short)
        #expect(two.count == 2)
        #expect(two.map { $0.wholeMatch(of: wholeLine)?.output.2 } == ["first", "second"])

        // Past the cap: about 1.5 × capBytes of numbered lines.
        let long = folder.appending(path: "long/repair-log.txt")
        RepairLog.fileURL = long
        let padding = String(repeating: "x", count: 100)
        let count = Int(RepairLog.capBytes) * 3 / 2 / 140
        for i in 0..<count { RepairLog.record("line-\(i) \(padding)") }

        let kept = try lines(at: long)
        let size = try #require(try FileManager.default.attributesOfItem(atPath: long.path(percentEncoded: false))[.size] as? UInt64)
        #expect(size <= RepairLog.capBytes)
        #expect(kept.count < count)
        // The newest line is the last one recorded, and the first line kept is whole.
        #expect(kept.last?.wholeMatch(of: wholeLine)?.output.2 == "line-\(count - 1) \(padding)")
        let first = try #require(kept.first)
        let firstRecorded = try #require(first.wholeMatch(of: wholeLine)?.output.2)
        #expect(firstRecorded.hasPrefix("line-") && firstRecorded.hasSuffix(padding))
        // What's kept runs on, unbroken, to the last line.
        let firstIndex = try #require(Int(firstRecorded.dropFirst("line-".count).prefix { $0.isNumber }))
        #expect(kept.count == count - firstIndex)
    }
}
