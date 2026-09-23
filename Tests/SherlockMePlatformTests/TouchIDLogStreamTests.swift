import XCTest
import SherlockMeCore
import SherlockMePlatform

/// The stream with a stand-in for `log stream`: `/bin/sh` printing lines of its own, then exiting.
final class TouchIDLogStreamTests: XCTestCase {
    private let queue = DispatchQueue(label: "TouchIDLogStreamTests")

    private static let keyDown = #"{"timestamp":"2026-09-23 11:48:21.425235+0200","processImagePath":"/usr/libexec/biometrickitd","eventMessage":"touchIDButtonPressed: 1"}"#
    private static let locked = #"{"timestamp":"2026-09-23 11:48:21.839592+0200","processImagePath":"/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow","eventMessage":"sendDistributedNotification: com.apple.screenIsLocked, with object:501"}"#

    /// A shell script printing each line, then exiting with `status`.
    private func script(_ lines: [String], exit status: Int32) -> [String] {
        ["-c", lines.map { "printf '%s\\n' '\($0)'" }.joined(separator: "; ") + "; exit \(status)"]
    }

    func testTheLinesArriveInOrderThenTheEndOnce() throws {
        var events: [TouchIDEvent] = []
        var ends: [Int32] = []
        let ended = expectation(description: "the end")
        let stream = TouchIDLogStream(queue: queue, executable: URL(fileURLWithPath: "/bin/sh"),
                                      arguments: script([Self.keyDown, "Filtering the log data", Self.locked], exit: 3),
                                      onEvent: { _, event in events.append(event) },
                                      onEnd: { status in
                                          ends.append(status)
                                          ended.fulfill()
                                      })
        try queue.sync { try stream.start() }
        wait(for: [ended], timeout: 5)
        queue.sync {
            XCTAssertEqual(events, [.keyDown, .screenLocked])
            XCTAssertEqual(ends, [3])
        }
    }

    func testAStopIsNotAnEnd() throws {
        let noEnd = expectation(description: "no end")
        noEnd.isInverted = true
        let stream = TouchIDLogStream(queue: queue, executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"],
                                      onEvent: { _, _ in }, onEnd: { _ in noEnd.fulfill() })
        try queue.sync {
            try stream.start()
            stream.stop()
        }
        wait(for: [noEnd], timeout: 1)
    }

    func testAToolThatIsNotThereThrows() {
        let stream = TouchIDLogStream(queue: queue, executable: URL(fileURLWithPath: "/nonexistent/log"),
                                      arguments: [], onEvent: { _, _ in }, onEnd: { _ in })
        XCTAssertThrowsError(try queue.sync { try stream.start() })
    }
}
