import XCTest
import SherlockMePlatform

/// The one call SherlockMe makes to loginwindow is there on this macOS. It is looked up and never made:
/// making it would lock the Mac running the tests.
final class SessionAgentTests: XCTestCase {
    func testTheLockCallIsThere() {
        XCTAssertTrue(SessionAgent.canLock)
    }

    /// No test makes the call: this file is the one place under `Tests/` that names the lock, and only to look
    /// it up.
    func testNoTestMakesTheLockCall() throws {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let files = try XCTUnwrap(FileManager.default.enumerator(at: tests, includingPropertiesForKeys: nil))
        for case let file as URL in files
        where file.pathExtension == "swift" && file.lastPathComponent != "SessionAgentTests.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("lockScreen(") || text.contains("SACLockScreen"),
                           "\(file.lastPathComponent) names the lock call")
        }
    }
}
