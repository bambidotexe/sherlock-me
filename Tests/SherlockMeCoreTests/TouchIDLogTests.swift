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

    /// loginwindow's Touch ID hold, taken and given back, as loginwindow logs it: who holds it, by name and
    /// pid. The other lines of the same method (the list of holders, "already has an assertion", the
    /// return code) carry the method's name too and are not events.
    func testTheHoldLinesAreRead() {
        let session = "loginwindow"
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] | addNewTouchIDBlockScreenLockAssertionForClient: coreautha, with PID: 35068"),
                       .holdTaken(client: "coreautha", pid: 35068))
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen clearTouchIDBlockScreenLockAssertionForClient:withPID:withDebounce:] | clearTouchIDBlockScreenLockAssertionForClient: coreautha, with PID: 35068"),
                       .holdCleared(client: "coreautha", pid: 35068))
        // System Settings' Touch ID pane, as it names itself on a French Mac: spaces, non-breaking spaces
        // and parentheses are all the client's name.
        XCTAssertEqual(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] | addNewTouchIDBlockScreenLockAssertionForClient: Touch\u{A0}ID et mot de passe (Réglages\u{A0}Système), with PID: 80399"),
                       .holdTaken(client: "Touch\u{A0}ID et mot de passe (Réglages\u{A0}Système)", pid: 80399))
        XCTAssertNil(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] | 35068 already has an assertion, resetting timeout"))
        XCTAssertNil(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] | current assertions: {\n    35068 = \"811892240.795993\";\n}"))
        XCTAssertNil(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen clearTouchIDBlockScreenLockAssertionForClient:withPID:withDebounce:] | returning: 0"))
        XCTAssertNil(TouchIDLog.event(process: session, message: "-[LWTouchIDLockScreen addNewTouchIDBlockScreenLockAssertionForClient:withPID:] | addNewTouchIDBlockScreenLockAssertionForClient: coreautha, with PID: none"))
        XCTAssertNil(TouchIDLog.event(process: "coreautha", message: "| addNewTouchIDBlockScreenLockAssertionForClient: coreautha, with PID: 35068"))
    }

    /// The screen's lock and unlock are posted per session, with the user's id as the object. With another
    /// user's session in front, its loginwindow's lines are not this session's; a line that names no session
    /// is taken as this one's, so a macOS that stops writing the id costs nothing.
    func testAnotherSessionsLockAndUnlockAreNotOurs() {
        let session = "loginwindow"
        let locked = "-[SessionAgentNotificationCenter sendDistributedNotification:object:] | sendDistributedNotification: com.apple.screenIsLocked, with object:"
        XCTAssertEqual(TouchIDLog.event(process: session, message: locked + "501", uid: 501), .screenLocked)
        XCTAssertNil(TouchIDLog.event(process: session, message: locked + "502", uid: 501))
        XCTAssertNil(TouchIDLog.event(process: session, message: locked + "5011", uid: 501))
        XCTAssertEqual(TouchIDLog.event(process: session, message: "sendDistributedNotification: com.apple.screenIsUnlocked", uid: 501),
                       .screenUnlocked)
        let line = #"{"timestamp":"2026-09-23 11:48:21.839592+0200","processImagePath":"/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow","eventMessage":"sendDistributedNotification: com.apple.screenIsLocked, with object:502"}"#
        XCTAssertNil(TouchIDLog.parse(Data(line.utf8), uid: 501))
        XCTAssertEqual(TouchIDLog.parse(Data(line.utf8), uid: 502)?.event, .screenLocked)
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
                     "calling to lock screen immediate",
                     "| addNewTouchIDBlockScreenLockAssertionForClient: ",
                     "| clearTouchIDBlockScreenLockAssertionForClient: "] {
            XCTAssertTrue(TouchIDLog.predicate.contains(text), text)
        }
    }
}
