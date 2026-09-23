import XCTest
import SherlockMeCore

/// When a `log stream` that ended is started again.
final class WatcherTests: XCTestCase {
    func testTheWaitsGrowThenHold() {
        XCTAssertEqual((1...6).map { WatchRestart.delay(afterFailures: $0) }, [1, 5, 30, 60, 60, 60])
        XCTAssertEqual(WatchRestart.delay(afterFailures: 0), 1)
    }

    func testAStreamThatRanAWhileStartsTheCountOver() {
        XCTAssertEqual(WatchRestart.failures(previous: 3, ranFor: K.watchSteadyAfter), 1)
        XCTAssertEqual(WatchRestart.failures(previous: 3, ranFor: 2), 4)
        XCTAssertEqual(WatchRestart.failures(previous: 0, ranFor: 0), 1)
    }
}
