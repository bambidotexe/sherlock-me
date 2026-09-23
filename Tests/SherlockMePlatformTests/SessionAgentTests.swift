import XCTest
import SherlockMePlatform

/// The one call SherlockMe makes to loginwindow is there on this macOS. It is looked up and never made:
/// making it would lock the Mac running the tests.
final class SessionAgentTests: XCTestCase {
    func testTheLockCallIsThere() {
        XCTAssertTrue(SessionAgent.canLock)
    }
}
