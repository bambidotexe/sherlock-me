import XCTest
import SherlockMeCore

/// The log lines SherlockMe reads, as macOS 27 writes them, and nothing else.
final class TouchIDLogTests: XCTestCase {
    func testEachLineTheRuleReads() {
        let sensor = "biometrickitd"
        let session = "loginwindow"
        XCTAssertEqual(TouchIDLog.event(process: sensor, message: "touchIDButtonPressed: 1"), .keyDown)
        XCTAssertEqual(TouchIDLog.event(process: sensor, message: "match:withOptions:withClient: <private>"),
                       .readStart)
        XCTAssertEqual(TouchIDLog.event(process: sensor, message: "statusMessage:withData:timestamp: 63, NSData(length:36), 1"),
                       .fingerOn)
        XCTAssertEqual(TouchIDLog.event(process: sensor, message: "statusMessage:withData:timestamp: 64, NSData(length:36), 1"),
                       .fingerOff)
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[SessionAgentNotificationCenter sendDistributedNotification:object:] | sendDistributedNotification: com.apple.screenIsLocked, with object:501"),
                       .screenLocked)
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[SessionAgentNotificationCenter sendDistributedNotification:object:] | sendDistributedNotification: com.apple.screenIsUnlocked, with object:501"),
                       .screenUnlocked)
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[ApplicationManager handleSystemEvent:] |      No assertions, calling to lock screen immediate"),
                       .macOSLocksForKey)
    }

    func testEverythingElseIsIgnored() {
        XCTAssertNil(TouchIDLog.event(process: "biometrickitd", message: "touchIDButtonPressed: 0"))
        XCTAssertNil(TouchIDLog.event(process: "biometrickitd", message: "statusMessage:withData:timestamp: 65, NSData(length:36), 1"))
        XCTAssertNil(TouchIDLog.event(process: "loginwindow", message: "-[LWScreenLock startScreenLock:] | entered kLWLockFromDirectLock (8)"))
        XCTAssertNil(TouchIDLog.event(process: "loginwindow", message: "-[Other method] | calling to lock screen immediate"))
        XCTAssertNil(TouchIDLog.event(process: "coreauthd", message: "touchIDButtonPressed: 1"))
    }

    func testALineOfTheStream() throws {
        let line = #"{"timestamp":"2026-09-23 11:48:21.425235+0200","processImagePath":"\/usr\/libexec\/biometrickitd","eventMessage":"touchIDButtonPressed: 1","messageType":"Default"}"#
        let parsed = try XCTUnwrap(TouchIDLog.parse(Data(line.utf8)))
        XCTAssertEqual(parsed.event, .keyDown)
        XCTAssertEqual(parsed.time.timeIntervalSince1970, 1_790_156_901.425, accuracy: 0.001)
    }

    func testTheStreamsHeaderAndOtherLinesAreNotEvents() {
        XCTAssertNil(TouchIDLog.parse(Data(#"Filtering the log data using "process == \"biometrickitd\"""#.utf8)))
        let keyUp = #"{"timestamp":"2026-09-23 11:48:21.425235+0200","processImagePath":"\/usr\/libexec\/biometrickitd","eventMessage":"touchIDButtonPressed: 0"}"#
        XCTAssertNil(TouchIDLog.parse(Data(keyUp.utf8)))
        let noTime = #"{"processImagePath":"\/usr\/libexec\/biometrickitd","eventMessage":"touchIDButtonPressed: 1"}"#
        XCTAssertNil(TouchIDLog.parse(Data(noTime.utf8)))
    }

    func testThePredicateAsksForEveryLineTheRuleReads() {
        for text in ["\"biometrickitd\"", "touchIDButtonPressed: 1", "match:withOptions",
                     "statusMessage:withData:timestamp: 63,", "statusMessage:withData:timestamp: 64,",
                     "\"loginwindow\"", "sendDistributedNotification: com.apple.screenIs",
                     "calling to lock screen immediate"] {
            XCTAssertTrue(TouchIDLog.predicate.contains(text), text)
        }
    }
}
