import XCTest
import SherlockMeCore

/// The owner's own presses, recorded with `Tools/touchprobe` and kept in `Tools/touchprobe/fixtures/`, played
/// through the rule with the times they were logged. The design says what each recording must give: each
/// morning bug one relock, run 9 its ten relocks and none of its deliberate unlocks. **If one fails, the rule
/// is wrong, or the design is: never change an expected value to match the rule.**
final class LockRuleReplayTests: XCTestCase {
    private typealias Line = (time: Date, event: TouchIDEvent)

    private func recording(_ name: String, without dropped: Set<TouchIDEvent> = []) throws -> [Line] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tools/touchprobe/fixtures/\(name).ndjson")
        let text = try String(contentsOf: url, encoding: .utf8)
        var lines: [Line] = []
        for row in text.split(separator: "\n") {
            let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(row.utf8)) as? [String: String])
            guard let event = TouchIDLog.event(process: object["process"] ?? "", message: object["message"] ?? ""),
                  !dropped.contains(event) else { continue }
            lines.append((try XCTUnwrap(TouchIDLog.time(object["timestamp"] ?? "")), event))
        }
        XCTAssertFalse(lines.isEmpty, "\(name) holds none of the lines the rule reads")
        return lines
    }

    /// Where the recorded run locked the Mac again by itself: an unlock followed by a lock `after` seconds
    /// later, with no press of the key between.
    private func relocksInRecording(_ lines: [Line], after range: ClosedRange<TimeInterval>) -> [Date] {
        var found: [Date] = []
        for (index, line) in lines.enumerated() where line.event == .screenUnlocked {
            for later in lines[(index + 1)...] {
                if later.event == .keyDown || later.event == .screenUnlocked { break }
                if later.event == .screenLocked {
                    if range.contains(later.time.timeIntervalSince(line.time)) { found.append(line.time) }
                    break
                }
            }
        }
        return found
    }

    /// The unlocks the rule decided to undo: when each `.wake` came.
    private func decisions(_ steps: [RulePlayer.Step]) -> [Date] {
        steps.compactMap { step in
            if case .wake = step.action { return step.time }
            return nil
        }
    }

    private func relocks(_ steps: [RulePlayer.Step]) -> Int {
        steps.filter { $0.action == .relock }.count
    }

    func testEachMorningBugIsCaughtOnce() throws {
        for name in ["morning-bug-1148", "morning-bug-1350"] {
            XCTAssertEqual(relocks(RulePlayer.play(try recording(name))), 1, name)
        }
    }

    /// The same two, as if the key's own line were never read: the press is followed from macOS's own lock.
    func testTheMorningBugsAreCaughtWithoutTheKeysLine() throws {
        for name in ["morning-bug-1148", "morning-bug-1350"] {
            let steps = RulePlayer.play(try recording(name, without: [.keyDown]))
            XCTAssertEqual(relocks(steps), 1, name)
            XCTAssertFalse(steps.contains { $0.action == .lock }, name)
        }
    }

    /// Run 9, the rule the owner accepted: it decides exactly where the probe relocked, ten times, and every
    /// one of those is made.
    func testRunNineIsDecidedExactlyAsTheOwnerAccepted() throws {
        let lines = try recording("relock-500ms")
        let steps = RulePlayer.play(lines)
        XCTAssertEqual(decisions(steps), relocksInRecording(lines, after: 0.4...1.0))
        XCTAssertEqual(decisions(steps).count, 10)
        XCTAssertEqual(relocks(steps), 10)
    }
}
