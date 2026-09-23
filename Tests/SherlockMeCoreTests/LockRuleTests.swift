import XCTest
import SherlockMeCore

/// Every sentence of the rule (`LockRule`, `docs/functional.md` §1), one press at a time, on a timeline
/// written out in seconds after the key went down.
final class LockRuleTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_156_901)

    private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    private func play(_ events: [(TimeInterval, TouchIDEvent)], screenIsLocked: Bool = false) -> [RulePlayer.Step] {
        RulePlayer.play(events.map { (at($0.0), $0.1) }, screenIsLocked: screenIsLocked)
    }

    private func actions(_ events: [(TimeInterval, TouchIDEvent)], screenIsLocked: Bool = false) -> [LockRule.Action] {
        play(events, screenIsLocked: screenIsLocked).map(\.action)
    }

    /// The press everyone makes: the key, the lock, the lock screen reading a finger still resting on it.
    private let restingFingerPress: [(TimeInterval, TouchIDEvent)] = [
        (0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn), (1.1, .screenUnlocked),
    ]

    // MARK: The key

    func testTheKeyLocksAnUnlockedMacAtOnce() {
        XCTAssertEqual(play([(0, .keyDown)]), [RulePlayer.Step(time: at(0), action: .lock)])
    }

    func testTheKeyOnTheLockScreenLocksNothing() {
        XCTAssertEqual(actions([(0, .keyDown)], screenIsLocked: true), [])
    }

    func testMacOSsOwnLockOnTheSamePressIsNotASecondPress() {
        XCTAssertEqual(actions([(0, .keyDown), (0.31, .macOSLocksForKey)]), [.lock])
    }

    func testAPressKnownOnlyFromMacOSsOwnLockIsFollowed() {
        let steps = play([(0.31, .macOSLocksForKey), (0.4, .screenLocked), (0.45, .readStart), (0.5, .fingerOn),
                          (1.2, .screenUnlocked)])
        XCTAssertEqual(steps.map(\.action), [.followedMacOSLock, .wake(at: at(1.7)), .relock])
    }

    // MARK: The relock

    func testTheRestingFingersUnlockIsUndoneHalfASecondLater() {
        let steps = play(restingFingerPress)
        XCTAssertEqual(steps, [RulePlayer.Step(time: at(0), action: .lock),
                               RulePlayer.Step(time: at(1.1), action: .wake(at: at(1.6))),
                               RulePlayer.Step(time: at(1.6), action: .relock)])
    }

    func testTheRelockWaitsForItsMoment() {
        var rule = LockRule(screenIsLocked: false)
        for (seconds, event) in restingFingerPress { _ = rule.handle(event, at: at(seconds)) }
        XCTAssertEqual(rule.tick(at: at(1.59)), [])
        XCTAssertEqual(rule.tick(at: at(1.6)), [.relock])
        XCTAssertEqual(rule.tick(at: at(1.7)), [], "a relock is made once")
    }

    func testAFingerThatLeftJustBeforeTheMatchStillCounts() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn),
                             (0.8, .fingerOff), (1.1, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .wake(at: at(1.6)), .relock])
    }

    func testTheScreenLockingMeanwhileLeavesNothingToRelock() {
        XCTAssertEqual(actions(restingFingerPress + [(1.3, .screenLocked)]), [.lock, .wake(at: at(1.6))])
    }

    func testOnlyOneRelockPerPress() {
        let steps = actions(restingFingerPress + [(1.7, .screenLocked), (1.8, .readStart), (1.85, .fingerOn),
                                                  (2.8, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .wake(at: at(1.6)), .relock, .leftUnlocked(.alreadyRelocked)])
    }

    // MARK: What is left alone

    func testAKeyBlipIsNotARestingFinger() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn),
                             (0.32, .fingerOff), (1.0, .fingerOn), (1.6, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .leftUnlocked(.noRestingFinger)])
    }

    func testATouchLaterInTheReadIsDeliberate() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (1.3, .fingerOn),
                             (2.0, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .leftUnlocked(.noRestingFinger)])
    }

    func testAPasswordIsLeftAlone() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (4.0, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .leftUnlocked(.noRestingFinger)])
    }

    func testARestingFingerThatLeftLongBeforeTheUnlockDidNotDoIt() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn),
                             (0.9, .fingerOff), (3.0, .screenUnlocked)])
        XCTAssertEqual(steps.count, 2)
        guard case .leftUnlocked(.fingerLeft(let seconds)) = steps.last else {
            return XCTFail("expected the unlock left alone, got \(steps)")
        }
        XCTAssertEqual(seconds, 2.1, accuracy: 0.001)
    }

    func testAnUnlockAfterTheWindowIsNotTheRulesBusiness() {
        XCTAssertEqual(actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn),
                                (6.5, .screenUnlocked)]), [.lock])
    }

    func testAReadLongAfterTheLockIsNotTheLockScreens() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (3.5, .readStart), (3.6, .fingerOn),
                             (4.0, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .leftUnlocked(.noRead)])
    }

    /// The user pressing the key on the lock screen is the user unlocking, whatever the sensor saw first.
    func testAPressOnTheLockScreenIsTheUserUnlocking() {
        let steps = actions([(0, .keyDown), (0.2, .screenLocked), (0.25, .readStart), (0.3, .fingerOn),
                             (0.9, .keyDown), (1.2, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .leftUnlocked(.pressedOnLockScreen)])
    }

    /// Run 8's case: the key pressed on the lock screen just after a relock, then the unlock that press
    /// asked for.
    func testAPressOnTheLockScreenAfterARelockIsNeverUndone() {
        let steps = actions(restingFingerPress + [(1.7, .screenLocked), (2.5, .keyDown), (2.6, .readStart),
                                                  (2.65, .fingerOn), (3.2, .screenUnlocked)])
        XCTAssertEqual(steps, [.lock, .wake(at: at(1.6)), .relock, .leftUnlocked(.pressedOnLockScreen)])
    }

    /// A second press before the first one's lock has landed starts the press over; one after it is a
    /// press on the lock screen.
    func testTwoQuickPresses() {
        XCTAssertEqual(actions([(0, .keyDown), (0.15, .keyDown), (0.3, .screenLocked), (0.35, .readStart),
                                (0.4, .fingerOn), (1.2, .screenUnlocked)]),
                       [.lock, .lock, .wake(at: at(1.7)), .relock])
        XCTAssertEqual(actions([(0, .keyDown), (0.2, .screenLocked), (0.3, .keyDown), (0.35, .readStart),
                                (0.4, .fingerOn), (1.2, .screenUnlocked)]),
                       [.lock, .leftUnlocked(.pressedOnLockScreen)])
    }

    func testAnUnlockWithNoPressIsNotTheRulesBusiness() {
        XCTAssertEqual(actions([(0, .screenLocked), (0.1, .readStart), (0.2, .fingerOn), (0.9, .screenUnlocked)]), [])
    }

    // MARK: loginwindow's Touch ID hold

    private let coreautha = "coreautha"

    /// An app reading the sensor, its prompt up, holds loginwindow's Touch ID hold from the moment the read
    /// starts; loginwindow refuses the key's lock while it is held. A click of the key meanwhile is the finger
    /// authenticating, and the press is macOS's.
    func testTheKeyDuringAnotherAppsReadIsLeftToMacOS() {
        XCTAssertEqual(actions([(0, .holdTaken(client: coreautha, pid: 35068)), (1.5, .keyDown)]),
                       [.leftToMacOS(holder: coreautha)])
    }

    /// The hold given back is kept `K.holdDebounce` more, as loginwindow keeps it.
    func testTheHoldOutlivesTheReadByItsDebounce() {
        let read: [(TimeInterval, TouchIDEvent)] = [(0, .holdTaken(client: coreautha, pid: 35068)),
                                                    (2, .holdCleared(client: coreautha, pid: 35068))]
        XCTAssertEqual(actions(read + [(4.9, .keyDown)]), [.leftToMacOS(holder: coreautha)])
        XCTAssertEqual(actions(read + [(5.1, .keyDown)]), [.lock])
    }

    /// A hold nobody gives back lapses `K.holdTimeout` after it was last taken, as it does in loginwindow;
    /// taking it again starts that over.
    func testAHoldNotGivenBackLapsesAfterAMinute() {
        let taken: (TimeInterval, TouchIDEvent) = (0, .holdTaken(client: coreautha, pid: 35068))
        XCTAssertEqual(actions([taken, (59, .keyDown)]), [.leftToMacOS(holder: coreautha)])
        XCTAssertEqual(actions([taken, (61, .keyDown)]), [.lock])
        XCTAssertEqual(actions([taken, (50, .holdTaken(client: coreautha, pid: 35068)), (100, .keyDown)]),
                       [.leftToMacOS(holder: coreautha)])
    }

    /// Every holder counts: the key is macOS's until the last hold has lapsed.
    func testEveryHolderCounts() {
        let steps = actions([(0, .holdTaken(client: coreautha, pid: 1)), (0, .holdTaken(client: "touchprobe", pid: 2)),
                             (1, .holdCleared(client: coreautha, pid: 1)), (5, .keyDown)])
        XCTAssertEqual(steps, [.leftToMacOS(holder: "touchprobe")])
    }

    /// A press left to macOS that macOS then locks on (the hold lapsed between the two) is followed like any
    /// other press whose lock is macOS's.
    func testMacOSsOwnLockOnAPressLeftToItIsFollowed() {
        let steps = actions([(0, .holdTaken(client: coreautha, pid: 35068)), (1, .keyDown), (1.31, .macOSLocksForKey),
                             (1.4, .screenLocked), (1.45, .readStart), (1.5, .fingerOn), (2.2, .screenUnlocked)])
        XCTAssertEqual(steps, [.leftToMacOS(holder: coreautha), .followedMacOSLock, .wake(at: at(2.7)), .relock])
    }

    /// The lock screen's own read holds it too, and gives it back with the debounce as it unlocks; that hold
    /// is not the key's business. A click within 3 s of a Touch ID unlock locks at once, where macOS alone
    /// waits: the owner's choice. The lock screen's hold lines arrive while the screen is locked, which is
    /// how they are told from an app's.
    func testTheKeyRightAfterATouchIDUnlockLocksAtOnce() {
        let unlock: [(TimeInterval, TouchIDEvent)] = [
            (0, .screenLocked), (0.02, .holdTaken(client: coreautha, pid: 35068)), (0.03, .readStart),
            (1.0, .fingerOn), (1.5, .holdCleared(client: coreautha, pid: 35068)), (1.6, .screenUnlocked),
        ]
        XCTAssertEqual(actions(unlock + [(2.0, .keyDown)], screenIsLocked: true), [.lock])
    }

    /// An app's read that the screen locking cut short ends with its debounce, as it does in loginwindow: a
    /// click after the unlock is macOS's until then, and the key's again after.
    func testAnAppsHoldCutShortByALockKeepsItsDebounce() {
        let cut: [(TimeInterval, TouchIDEvent)] = [
            (0, .holdTaken(client: coreautha, pid: 35068)), (1, .screenLocked),
            (1.1, .holdCleared(client: coreautha, pid: 35068)), (2, .screenUnlocked),
        ]
        XCTAssertEqual(actions(cut + [(3, .keyDown)]), [.leftToMacOS(holder: coreautha)])
        XCTAssertEqual(actions(cut + [(4.2, .keyDown)]), [.lock])
    }

    /// The relock is not the key: the hold the lock screen takes for its read, and its debounce after the
    /// unwanted unlock, never stop it.
    func testTheHoldNeverStopsTheRelock() {
        let press: [(TimeInterval, TouchIDEvent)] = [
            (0, .keyDown), (0.2, .screenLocked), (0.22, .holdTaken(client: coreautha, pid: 35068)),
            (0.25, .readStart), (0.3, .fingerOn), (1.0, .holdCleared(client: coreautha, pid: 35068)),
            (1.1, .screenUnlocked),
        ]
        XCTAssertEqual(actions(press), [.lock, .wake(at: at(1.6)), .relock])
    }

    // MARK: A lock that was refused

    /// A lock loginwindow refused leaves no press: the key did nothing, and if macOS then locks on it, that
    /// lock is followed.
    func testALockThatFailedLeavesNoPressToFollow() {
        var rule = LockRule(screenIsLocked: false)
        XCTAssertEqual(rule.handle(.keyDown, at: at(0)), [.lock])
        rule.lockFailed()
        XCTAssertEqual(rule.handle(.macOSLocksForKey, at: at(0.31)), [.followedMacOSLock])
    }

    // MARK: A stream that has just started

    /// A lock the log did not show, taken from the window server: the press that follows is a press on the
    /// lock screen, and the unlock it asks for is left alone.
    func testALockTheLogMissedIsTakenFromTheWindowServer() {
        var rule = LockRule(screenIsLocked: false)
        XCTAssertEqual(rule.settle(screenIsLocked: true, at: at(0)), [])
        XCTAssertTrue(rule.screenIsLocked)
        XCTAssertEqual(rule.handle(.keyDown, at: at(1)), [])
        XCTAssertEqual(rule.handle(.readStart, at: at(1.1)), [])
        XCTAssertEqual(rule.handle(.fingerOn, at: at(1.15)), [])
        XCTAssertEqual(rule.handle(.screenUnlocked, at: at(1.8)), [])
    }

    func testAnUnlockIsNeverTakenFromTheWindowServer() {
        var rule = LockRule(screenIsLocked: true)
        XCTAssertEqual(rule.settle(screenIsLocked: false, at: at(0)), [])
        XCTAssertTrue(rule.screenIsLocked)
    }
}
