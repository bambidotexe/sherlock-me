# SherlockMe core: build plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build SherlockMe's one behaviour: lock the Mac the instant the Touch ID key goes down, and lock it
again 0.5 s after the finger that pressed the key unlocks it, once per press, with the menu line, the Health
page, the wizard's words and the documents that go with it.

**Architecture:** A pure rule in `SherlockMeCore` (`LockRule`: the log's lines with their times in; lock,
relock, wake out), fed by one `/usr/bin/log stream` child (`SherlockMePlatform.TouchIDLogStream`), acted on
through loginwindow's own immediate lock (`SessionAgent.lockScreen`, the private login.framework through
`dlsym`), and wired by one object on a serial queue of its own in the app (`TouchIDGuard`). No hold, no
permission, no setting.

**Tech Stack:** Swift 5.10 tools, SwiftPM, macOS 26+, XCTest, the existing AppKit and SwiftUI shell,
Collaboration.framework for the administrator check. No third-party dependency.

**Spec:** `docs/superpowers/specs/2026-09-23-sherlockme-core-design.md`. Read it whole, with
`docs/pitfalls.md` and `docs/macOS.md`, before Task 2. `CLAUDE.md` and `docs/shared/workflow.md` are the
house rules.

## Global Constraints

- Swift tools 5.10, `platforms: [.macOS("26.0")]`, no dependency. `swift build` shows no warning from
  `Sources/` or `Tests/`; `swift test` prints **two** bundle summary lines, `SherlockMeCoreTests.xctest` and
  `SherlockMePlatformTests.xctest`, both passing.
- **`SherlockMeCore` imports Foundation and CoreGraphics only and never reads a clock**: no `Date()` in any
  file under `Sources/SherlockMeCore` (`PurityTests` fails otherwise). Time is passed in.
- **Nothing locks the Mac.** No test calls `SessionAgent.lockScreen()`. Never run `swift run touchprobe` in
  any mode, never run the app's binary (`.build/*/SherlockMe`), never `make install`, `make release`,
  `make app`. The owner is away, and every one of these either locks the Mac or puts a build on it.
- **Never run and never add `LockRuleReplayTests`**, the replay of the owner's recordings. Task H holds it
  for the owner.
- Every sentence a user reads is in `Sources/SherlockMeCore/Strings*.swift`, in English and French, one
  accessor switching over `Language`, listed in `LocalizationTests.everySentence`. No dash longer than `-`
  in any of them. The app's name is `AppIdentity.name`, never written out in a table.
- Comments and documents state the present: no dates, task numbers, "used to", or history.
- `docs/functional.md` changes in the same commit as the behaviour it describes.
- Stage by path, never `git add -A` or `git add .`; never stage `.claude/`. Conventional commits
  (`feat|fix|docs|build|test(scope): why`) ending with the attribution trailers from the session's system
  reminder.
- The project's `.claude/settings.local.json` turns the Bash sandbox off for this tree: never pass
  `dangerouslyDisableSandbox`. If a command is refused, stop and report it; do not look for another way.
- Implementers do not commit. The controller reviews the diff, runs `swift build` and `swift test` itself,
  and commits (`docs/shared/workflow.md`, *Subagents*).

## Decisions made without the owner

The owner approved the design and asked for the build to run to its end without questions. The design left
four questions for the build, and some words are the owner's; this plan decides them, each reversible, and
the final report lists them for the owner's review.

1. **No Touch ID hold** (open question 1). SherlockMe's lock lands 0.09 to 0.14 s after the key goes down,
   before loginwindow hears of the key at 0.31 s, and loginwindow's handler declines while the shield is up
   (read from loginwindow, not measured with SherlockMe running). Without the hold there is no crash window:
   SherlockMe gone is macOS's own behaviour at once. The manual checklist looks at loginwindow's own lock
   arriving second.
2. **The built-in button** (open question 2) is not measured. The rule also follows a press known only from
   loginwindow's own lock on it, so a keyboard whose press never reaches biometrickitd's key line still gets
   the relock; only the instant lock would then be macOS's.
3. **No launch agent** (open question 3). Without the hold, a crash costs the protection and nothing else;
   the family's login item starts SherlockMe at login and the Health page shows the crash.
4. **A non-administrator account** (open question 4): nothing is started; the menu line, the Health page
   and the wizard's last page say so. Not the System page: it holds only states with a button beside them
   (`macos-building-settings-pages`), and nothing in the app can make an account an administrator.
5. **One Health check**, *Watching the Touch ID key*, where the design listed two (the watcher runs, the log
   can be read): the Settings skill's rule is one cause, one line.
6. **The readings** *Running for* and *Memory used* give way to *Last lock with the Touch ID key* and *Last
   unlock caught* (the Settings skill: those two are for an app with nothing better to say).
7. **Every new sentence** (the pitch, the menu line, the Health line and its fixes, the readings, the
   wizard's last page, the README, the disk image's line) is proposed here in both languages.
8. **The replay of the owner's recordings is held** (Task H): running it was refused in the session that
   wrote this plan, and it is not worked around.

## Review Focus

The inputs most likely to bite someone using SherlockMe that the spec implies and no happy path exercises,
most likely first, and the test that pins each:

1. **The key pressed on the lock screen just after a relock**, then the unlock that press asked for: never
   relocked. `LockRuleTests.testAPressOnTheLockScreenAfterARelockIsNeverUndone` (Task 2).
2. **A password, a later touch, or a resting finger that left long before**, inside the 6 s window: left
   alone. `testAPasswordIsLeftAlone`, `testATouchLaterInTheReadIsDeliberate`,
   `testARestingFingerThatLeftLongBeforeTheUnlockDidNotDoIt` (Task 2).
3. **Two quick presses**: a second key-down before the first lock has landed starts the press over; one
   after it is a press on the lock screen. `testTwoQuickPresses` (Task 2).
4. **The log stream ending or failing to start**: its end reported once and after its last line, restarts
   with growing waits and no tight loop, the menu and Health saying *Stopped*.
   `TouchIDLogStreamTests`, `WatcherTests` (Task 3), `HealthTests.testAStoppedStreamIsRedAndSaysItComesBack`
   (Task 6), and the Task 5 review.
5. **An account that is not an administrator**: no stream, no restart loop, the menu, Health and the
   wizard say why. `HealthTests.testAnAccountThatCannotReadTheLogIsRedAndSaysWhoCanChangeThat` (Task 6),
   `LoginSessionTests` (Task 4), and the Task 5 review.

## Before Task 1 (the controller)

- [ ] The tree has no commit. Make the first one, of the tree as it stands (the template's app, the design,
  the probe and its fixtures, this plan), staged by path:

```bash
cd ~/Projects/sherlock-me
git add .github .gitignore .vscode CHANGELOG.md CLAUDE.md LICENSE Makefile Package.swift README.md \
        Resources Sources Tests Tools docs scripts
git status --short        # nothing staged under .claude/
git commit -m "feat: SherlockMe, from the template, with the core's design and the Touch ID probe" \
           -m "<attribution trailers>"
```

- [ ] `swift build` and `swift test`: clean, two summary lines (Core 77, Platform 14).

## File map

| File | Task | Responsibility |
|---|---|---|
| `Sources/SherlockMeCore/TouchIDLog.swift` | 1 | `TouchIDEvent`; `TouchIDLog.predicate`, `event(process:message:)`, `time(_:)`, `parse(_:)` |
| `Sources/SherlockMeCore/LockRule.swift` | 2 | the rule: events and times in, `[LockRule.Action]` out |
| `Sources/SherlockMeCore/Constants.swift` | 2, 3 | the rule's numbers and the restart's, with their evidence |
| `Sources/SherlockMeCore/Watcher.swift` | 3 | `WatcherState`; `WatchRestart.delay(afterFailures:)`, `failures(previous:ranFor:)` |
| `Sources/SherlockMePlatform/TouchIDLogStream.swift` | 3 | the `log stream` child: lines in order, one end |
| `Sources/SherlockMePlatform/SessionAgent.swift` | 4 | `SACLockScreenImmediate` through `dlsym`: `canLock`, `lockScreen()` |
| `Sources/SherlockMePlatform/LoginSession.swift` | 4 | `screenIsLocked`, `userIsAdministrator` |
| `Sources/SherlockMePlatform/Log.swift` | 4 | the `touchid` category |
| `Sources/SherlockMeApp/TouchIDGuard.swift` | 5 | the behaviour on its own queue; `status` for the menu and Health |
| `Sources/SherlockMeApp/AppDelegate.swift` | 5 | start at launch, stop at quit |
| `Sources/SherlockMeCore/StringsMenu.swift`, `StringsHealthPage.swift`, `HealthReport.swift` | 6 | the menu line, the Health line and readings, in words |
| `Sources/SherlockMeApp/MenuBarController.swift`, `HealthCheck.swift`, `SettingsHealthPage.swift` | 6 | draw them |
| `Sources/SherlockMePlatform/ProcessStats.swift` | 6 | deleted: nothing reads it any more |
| `Sources/SherlockMeCore/StringsOnboarding.swift`, `Sources/SherlockMeApp/OnboardingWindow.swift` | 7 | the pitch, the last page on a non-administrator account |
| Tests: `TouchIDLogTests`, `RulePlayer`, `LockRuleTests`, `WatcherTests`, `TouchIDLogStreamTests`, `SessionAgentTests`, `LoginSessionTests`; `HealthTests`, `LocalizationTests` changed | 1 to 7 | |
| `docs/*.md`, `CLAUDE.md`, `README.md`, `CHANGELOG.md`, the spec | 5 to 8 | the same app in words |

---

### Task 1: What SherlockMe reads

**Model:** sonnet. **Reviewer:** sonnet.

**Files:**
- Create: `Sources/SherlockMeCore/TouchIDLog.swift`
- Create: `Tests/SherlockMeCoreTests/TouchIDLogTests.swift`
- Modify: `Package.swift` (the probe's target excludes its recordings)

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum TouchIDEvent: Equatable, Sendable { case keyDown, macOSLocksForKey, readStart,
  fingerOn, fingerOff, screenLocked, screenUnlocked }`; `public enum TouchIDLog` with `static let predicate:
  String`, `static func event(process: String, message: String) -> TouchIDEvent?`, `static func time(_ stamp:
  String) -> Date?`, `static func parse(_ line: Data) -> (time: Date, event: TouchIDEvent)?`.

- [ ] **Step 1: Write the failing test** — `Tests/SherlockMeCoreTests/TouchIDLogTests.swift`:

```swift
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
```

- [ ] **Step 2: Run it and see it fail**

Run: `swift test --filter TouchIDLogTests`
Expected: a build failure, `cannot find 'TouchIDLog' in scope`.

- [ ] **Step 3: Write the code** — `Sources/SherlockMeCore/TouchIDLog.swift`:

```swift
import Foundation

/// What the unified log says about the Touch ID key, the sensor and the screen: the only lines SherlockMe
/// reads. Measured on macOS 27.0 (26A428) with a Magic Keyboard with Touch ID (`docs/macOS.md`, *What a
/// Touch ID key press does*). Every one is logged at the default level, which an administrator account
/// reads without sudo.
public enum TouchIDEvent: Equatable, Sendable {
    /// biometrickitd `touchIDButtonPressed: 1`: the key went down, 0.31 s before loginwindow hears of it.
    case keyDown
    /// loginwindow `handleSystemEvent:` locking the screen on the key itself, 0.31 s after it went down.
    case macOSLocksForKey
    /// biometrickitd `match:withOptions:`: something started reading the sensor. After a lock, it is the
    /// lock screen, 0.03 to 0.15 s after the screen locked.
    case readStart
    /// biometrickitd status 63: a finger is on the sensor. Reported only while something reads it.
    case fingerOn
    /// biometrickitd status 64: the finger left the sensor.
    case fingerOff
    /// loginwindow sent `com.apple.screenIsLocked`.
    case screenLocked
    /// loginwindow sent `com.apple.screenIsUnlocked`.
    case screenUnlocked
}

/// Reading those lines: the predicate `log stream` is given, and what one line of its output means.
public enum TouchIDLog {
    /// The lines SherlockMe reads and nothing else, so the stream costs nothing between presses.
    public static let predicate = """
        (process == "biometrickitd" AND (eventMessage BEGINSWITH "touchIDButtonPressed: 1" \
        OR eventMessage BEGINSWITH "match:withOptions" \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 63," \
        OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 64,")) \
        OR (process == "loginwindow" AND (eventMessage CONTAINS "sendDistributedNotification: com.apple.screenIs" \
        OR eventMessage CONTAINS "calling to lock screen immediate"))
        """

    /// What a line means, from the name of the process that wrote it and its message; nil for any other line.
    public static func event(process: String, message: String) -> TouchIDEvent? {
        switch process {
        case "biometrickitd":
            if message.hasPrefix("touchIDButtonPressed: 1") { return .keyDown }
            if message.hasPrefix("match:withOptions") { return .readStart }
            if message.hasPrefix("statusMessage:withData:timestamp: 63,") { return .fingerOn }
            if message.hasPrefix("statusMessage:withData:timestamp: 64,") { return .fingerOff }
        case "loginwindow":
            if message.contains("sendDistributedNotification: com.apple.screenIsLocked") { return .screenLocked }
            if message.contains("sendDistributedNotification: com.apple.screenIsUnlocked") { return .screenUnlocked }
            if message.contains("handleSystemEvent:"), message.contains("calling to lock screen immediate") {
                return .macOSLocksForKey
            }
        default:
            break
        }
        return nil
    }

    /// The log's own time stamp, `2026-09-23 11:48:21.425235+0200`; nil when it does not parse.
    public static func time(_ stamp: String) -> Date? { stampFormat.date(from: stamp) }

    /// One line of `log stream --style ndjson`: when it was written and what it means. nil for a line that
    /// is not one of these, or not a log entry at all (the stream opens with a line saying what it filters).
    public static func parse(_ line: Data) -> (time: Date, event: TouchIDEvent)? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let stamp = object["timestamp"] as? String, let time = time(stamp),
              let path = object["processImagePath"] as? String,
              let message = object["eventMessage"] as? String,
              let event = event(process: (path as NSString).lastPathComponent, message: message)
        else { return nil }
        return (time, event)
    }

    private static let stampFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
        return formatter
    }()
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `swift test --filter TouchIDLogTests`
Expected: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: Keep the recordings out of the probe's sources.** `swift build` warns `found 5 file(s) which
  are unhandled` for `Tools/touchprobe/fixtures/*.ndjson`. In `Package.swift`, replace

```swift
        // The Touch ID probe: what happens around a Touch ID key press, read off the unified log, and the
        // hold and lock calls the design rests on, tried on the owner's hardware. Never put in the bundle
        // either; every run ends by itself.
        .executableTarget(name: "touchprobe", path: "Tools/touchprobe"),
```

with

```swift
        // The Touch ID probe: what happens around a Touch ID key press, read off the unified log, and the
        // hold and lock calls the design rests on, tried on the owner's hardware. Never put in the bundle
        // either; every run ends by itself. Its `fixtures/` are the owner's recorded presses: data, not
        // source.
        .executableTarget(name: "touchprobe", path: "Tools/touchprobe", exclude: ["fixtures"]),
```

- [ ] **Step 6: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; `SherlockMeCoreTests.xctest` passed, 82 tests; `SherlockMePlatformTests.xctest`
passed, 14 tests.

- [ ] **Step 7: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/TouchIDLog.swift Tests/SherlockMeCoreTests/TouchIDLogTests.swift Package.swift
git commit -m "feat(core): read the Touch ID lines of the unified log" -m "<attribution trailers>"
```

---

### Task 2: The rule

**Model:** opus. **Reviewer:** fable-xhigh-reviewer (a defect here undoes an unlock the user made on
purpose, or leaves one in place that it should catch).

**Files:**
- Modify: `Sources/SherlockMeCore/Constants.swift` (the Touch ID numbers)
- Create: `Sources/SherlockMeCore/LockRule.swift`
- Create: `Tests/SherlockMeCoreTests/RulePlayer.swift`
- Create: `Tests/SherlockMeCoreTests/LockRuleTests.swift`

**Interfaces:**
- Consumes: `TouchIDEvent` (Task 1).
- Produces: `public struct LockRule: Sendable` with `init(screenIsLocked: Bool)`, `private(set) var
  screenIsLocked: Bool`, `mutating func handle(_ event: TouchIDEvent, at time: Date) -> [Action]`, `mutating
  func tick(at time: Date) -> [Action]`; `enum Action: Equatable, Sendable { case lock, relock, wake(at:
  Date), followedMacOSLock, leftUnlocked(Reason) }`; `enum Reason: Equatable, Sendable { case
  pressedOnLockScreen, alreadyRelocked, noRead, noRestingFinger, fingerLeft(secondsBeforeUnlock:
  TimeInterval) }`. `K.readAfterLock`, `K.restingFinger`, `K.keyBlip`, `K.matchAfterLift`,
  `K.relockWindow`, `K.relockDelay`, `K.relocksPerPress`, `K.sameKeyPress`. Test helper `RulePlayer.play(_:
  screenIsLocked:) -> [RulePlayer.Step]`.

The rule is the probe's `relock` mode, validated in run 9, ported to a value that takes the log's own times.
Read the spec's *The rule* and *The numbers* before writing it.

- [ ] **Step 1: Write the test helper** — `Tests/SherlockMeCoreTests/RulePlayer.swift`:

```swift
import Foundation
import SherlockMeCore

/// Plays lines through a `LockRule` in the order and with the times they were logged, waking it when it asked
/// to be woken, the way the app does. What the rule decides changes nothing that follows: a recording
/// already holds whatever locked the Mac at the time.
enum RulePlayer {
    struct Step: Equatable {
        let time: Date
        let action: LockRule.Action
    }

    static func play(_ lines: [(time: Date, event: TouchIDEvent)], screenIsLocked: Bool = false) -> [Step] {
        var rule = LockRule(screenIsLocked: screenIsLocked)
        var wakes: [Date] = []
        var steps: [Step] = []
        func record(_ actions: [LockRule.Action], at time: Date) {
            for action in actions {
                steps.append(Step(time: time, action: action))
                if case .wake(let due) = action { wakes.append(due) }
            }
        }
        for line in lines {
            while let due = wakes.min(), due <= line.time {
                wakes.removeAll { $0 == due }
                record(rule.tick(at: due), at: due)
            }
            record(rule.handle(line.event, at: line.time), at: line.time)
        }
        for due in wakes.sorted() { record(rule.tick(at: due), at: due) }
        return steps
    }
}
```

- [ ] **Step 2: Write the failing tests** — `Tests/SherlockMeCoreTests/LockRuleTests.swift`:

```swift
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
}
```

- [ ] **Step 3: Run them and see them fail**

Run: `swift test --filter LockRuleTests`
Expected: a build failure, `cannot find type 'LockRule' in scope`.

- [ ] **Step 4: Add the numbers.** In `Sources/SherlockMeCore/Constants.swift`, the doc comment of `K` loses
  its placeholder: replace

```swift
/// taste is not here and is not offered as a setting either: it is a rule.
///
/// TEMPLATE: the app's own numbers go above the update's, each with the measurement that chose it.
public enum K {
```

with

```swift
/// taste is not here and is not offered as a setting either: it is a rule.
public enum K {
```

and insert, directly above `    // MARK: - Updates`:

```swift
    // MARK: - The Touch ID key

    /// A read of the sensor that begins this long after the lock is not the lock screen's. Measured: the lock
    /// screen starts reading 0.03 to 0.15 s after the screen locked, which comes 0.1 to 0.4 s after the key.
    public static let readAfterLock: TimeInterval = 3

    /// A finger seen this soon after the read began was already on the sensor: the finger that pressed the
    /// key, resting. Measured on the owner's presses: resting fingers 0.001 to 0.42 s into the read,
    /// deliberate touches 0.97 s and later (the owner's log, runs 1, 1b, 4, 7, 8, 9).
    public static let restingFinger: TimeInterval = 0.5

    /// A finger that leaves this soon after it was seen was the key coming up, not a finger resting.
    /// Measured: 17 ms (run 4).
    public static let keyBlip: TimeInterval = 0.1

    /// When the resting finger is the one that unlocked, the unlock comes this soon after it leaves: the
    /// match lands 0.2 to 0.25 s after the finger that gave the image leaves. A later unlock was another touch.
    public static let matchAfterLift: TimeInterval = 0.5

    /// An unlock this soon after the lock the rule follows may be undone. Every unwanted unlock came 0.9 to
    /// 1.6 s after the press.
    public static let relockWindow: TimeInterval = 6

    /// How long after the unwanted unlock the Mac is locked again. At once, the desktop showed for 0.10 to
    /// 0.12 s and the relocked screen stayed on the wallpaper with no login box until a key was pressed
    /// (run 7). After 1 s, a normal lock screen, and the Mac unlocked for 1.16 to 1.19 s (run 8). After
    /// 0.5 s, a normal lock screen, unlocked for 0.61 to 0.64 s (run 9): the owner's choice.
    public static let relockDelay: TimeInterval = 0.5

    /// Relocks per press. In 23 relocks (runs 7 to 9) not one Mac unlocked by itself afterwards, so a second
    /// one could only undo a deliberate unlock.
    public static let relocksPerPress = 1

    /// loginwindow's own lock on the key belongs to the press whose key line came this soon before it.
    /// Measured: loginwindow hears of the key 0.305 to 0.321 s after it goes down (ten presses).
    public static let sameKeyPress: TimeInterval = 1
```

- [ ] **Step 5: Write the rule** — `Sources/SherlockMeCore/LockRule.swift`:

```swift
import Foundation

/// SherlockMe's behaviour, as a value: what the log says, with the time it says it, in; what to do, out. It
/// never reads a clock and never touches the Mac, so the owner's recorded presses replay through it
/// (`LockRuleReplayTests`). `docs/functional.md` §1 states the same rule in words.
///
/// 1. **The Touch ID key goes down while the screen is unlocked: lock now.** That press is the current one.
///    A press whose key line was not read, known only from loginwindow locking on it, becomes the current
///    one the same way, with nothing to lock.
/// 2. **The lock screen starts reading the sensor within `K.readAfterLock` of that lock**: when it did is
///    kept.
/// 3. **A finger seen within `K.restingFinger` of that read beginning was already there**: the finger that
///    pressed the key, resting. One that leaves within `K.keyBlip` was the key coming up, and is forgotten.
/// 4. **The screen unlocks within `K.relockWindow` of the lock, with that finger still on the sensor or gone
///    at most `K.matchAfterLift` before: lock again `K.relockDelay` later**, if the screen has stayed
///    unlocked. At most `K.relocksPerPress` times per press.
/// 5. **Anything else is left alone**: the key pressed on the lock screen (which also cancels a relock
///    still to come), a finger that arrives later in the read, a password, an unlock after the window.
public struct LockRule: Sendable {
    public enum Action: Equatable, Sendable {
        /// Lock the Mac now: the key went down on an unlocked Mac.
        case lock
        /// Lock the Mac again now: the finger that pressed the key unlocked it.
        case relock
        /// Call `tick(at:)` at this moment.
        case wake(at: Date)
        /// For the log alone: macOS locked on a press whose key line was not read, and the rule follows it.
        case followedMacOSLock
        /// For the log alone: an unlock soon after a lock the rule follows, left alone, and why.
        case leftUnlocked(Reason)
    }

    public enum Reason: Equatable, Sendable {
        /// The key was pressed on the lock screen: the user unlocking.
        case pressedOnLockScreen
        /// This press was locked again once already.
        case alreadyRelocked
        /// The lock screen did not start reading the sensor after the lock.
        case noRead
        /// No finger was on the sensor as the read began: a later touch, a password, a watch.
        case noRestingFinger
        /// The resting finger had left this long before the unlock: another touch did it.
        case fingerLeft(secondsBeforeUnlock: TimeInterval)
    }

    /// Whether the screen is locked, as the log last said.
    public private(set) var screenIsLocked: Bool

    /// The press the rule follows, while it can still be relocked or reported on.
    private var press: Press?

    private struct Press: Sendable {
        /// When the rule last locked for it, or macOS did: the key going down, then the relock.
        var lockedAt: Date
        var readStart: Date?
        var restingOn: Date?
        var restingOff: Date?
        var relocks = 0
        var relockDue: Date?
        /// The key was pressed on the lock screen after this press's lock.
        var cancelled = false
    }

    public init(screenIsLocked: Bool) {
        self.screenIsLocked = screenIsLocked
    }

    public mutating func handle(_ event: TouchIDEvent, at time: Date) -> [Action] {
        switch event {
        case .keyDown:
            guard !screenIsLocked else {
                press?.cancelled = true
                press?.relockDue = nil
                return []
            }
            press = Press(lockedAt: time)
            return [.lock]
        case .macOSLocksForKey:
            if let current = press, time.timeIntervalSince(current.lockedAt) < K.sameKeyPress { return [] }
            guard !screenIsLocked else { return [] }
            press = Press(lockedAt: time)
            return [.followedMacOSLock]
        case .readStart:
            guard var current = press, !current.cancelled else { return [] }
            let sinceLock = time.timeIntervalSince(current.lockedAt)
            guard sinceLock >= 0, sinceLock < K.readAfterLock else { return [] }
            current.readStart = time
            current.restingOn = nil
            current.restingOff = nil
            press = current
        case .fingerOn:
            guard var current = press, let read = current.readStart, current.restingOn == nil,
                  time.timeIntervalSince(read) <= K.restingFinger else { return [] }
            current.restingOn = time
            press = current
        case .fingerOff:
            guard var current = press, let on = current.restingOn, current.restingOff == nil else { return [] }
            if time.timeIntervalSince(on) < K.keyBlip {
                current.restingOn = nil
            } else {
                current.restingOff = time
            }
            press = current
        case .screenLocked:
            screenIsLocked = true
            press?.relockDue = nil
        case .screenUnlocked:
            screenIsLocked = false
            return unlocked(at: time)
        }
        return []
    }

    /// The moment a `.wake` asked for has come: the relock, if the screen has stayed unlocked since.
    public mutating func tick(at time: Date) -> [Action] {
        guard var current = press, let due = current.relockDue, time >= due else { return [] }
        current.relockDue = nil
        guard !screenIsLocked else {
            press = current
            return []
        }
        current.lockedAt = time
        press = current
        return [.relock]
    }

    private mutating func unlocked(at time: Date) -> [Action] {
        guard var current = press, time.timeIntervalSince(current.lockedAt) < K.relockWindow else { return [] }
        let read = current.readStart
        let on = current.restingOn
        let off = current.restingOff
        // What the read showed is spent on this unlock, whatever is decided.
        current.readStart = nil
        current.restingOn = nil
        current.restingOff = nil
        let reason: Reason?
        if current.cancelled {
            reason = .pressedOnLockScreen
        } else if current.relocks >= K.relocksPerPress {
            reason = .alreadyRelocked
        } else if read == nil {
            reason = .noRead
        } else if on == nil {
            reason = .noRestingFinger
        } else if let off, time.timeIntervalSince(off) > K.matchAfterLift {
            reason = .fingerLeft(secondsBeforeUnlock: time.timeIntervalSince(off))
        } else {
            reason = nil
        }
        if let reason {
            press = current
            return [.leftUnlocked(reason)]
        }
        current.relocks += 1
        let due = time.addingTimeInterval(K.relockDelay)
        current.relockDue = due
        press = current
        return [.wake(at: due)]
    }
}
```

- [ ] **Step 6: Run them and see them pass**

Run: `swift test --filter LockRuleTests`
Expected: `Executed 19 tests, with 0 failures`.

If one fails, the rule is wrong, not the test: each test is a sentence of the spec's *The rule*. Do not
change an expected value to match the code.

- [ ] **Step 7: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 101 tests, Platform 14, both passed. `PurityTests` passes: no `Date()` under
`Sources/SherlockMeCore`.

- [ ] **Step 8: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/Constants.swift Sources/SherlockMeCore/LockRule.swift \
        Tests/SherlockMeCoreTests/RulePlayer.swift Tests/SherlockMeCoreTests/LockRuleTests.swift
git commit -m "feat(core): the rule that locks at the key and catches the resting finger's unlock" \
           -m "<attribution trailers>"
```

---

### Task 3: The log stream, and when it starts again

**Model:** sonnet. **Reviewer:** opus.

**Files:**
- Modify: `Sources/SherlockMeCore/Constants.swift` (the restart's numbers)
- Create: `Sources/SherlockMeCore/Watcher.swift`
- Create: `Tests/SherlockMeCoreTests/WatcherTests.swift`
- Create: `Sources/SherlockMePlatform/TouchIDLogStream.swift`
- Create: `Tests/SherlockMePlatformTests/TouchIDLogStreamTests.swift`

**Interfaces:**
- Consumes: `TouchIDEvent`, `TouchIDLog.parse`, `TouchIDLog.predicate` (Task 1).
- Produces: `public enum WatcherState: Equatable, Sendable { case watching, stopped, needsAdministrator }`;
  `public enum WatchRestart` with `static func delay(afterFailures: Int) -> TimeInterval` and `static func
  failures(previous: Int, ranFor: TimeInterval) -> Int`; `K.watchRestartDelays: [TimeInterval]`,
  `K.watchSteadyAfter`. `public final class TouchIDLogStream: @unchecked Sendable` with `init(queue:
  DispatchQueue, executable: URL = /usr/bin/log, arguments: [String] = [stream --style ndjson --predicate
  …], onEvent: @escaping (Date, TouchIDEvent) -> Void, onEnd: @escaping (Int32) -> Void)`, `func start()
  throws`, `func stop()`, every one called on `queue`.

- [ ] **Step 1: Write the failing Core test** — `Tests/SherlockMeCoreTests/WatcherTests.swift`:

```swift
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
```

- [ ] **Step 2: Run it and see it fail**

Run: `swift test --filter WatcherTests`
Expected: a build failure, `cannot find 'WatchRestart' in scope`.

- [ ] **Step 3: Add the numbers.** In `Sources/SherlockMeCore/Constants.swift`, insert directly above
  `    // MARK: - Updates` (so after `K.sameKeyPress`):

```swift
    /// The waits before `log stream` is started again after it ended, by how many times in a row it has
    /// ended; the last one repeats. Not measured: the stream never ended in any run. They keep a stream that
    /// cannot start from being started again in a tight loop, and bring a working one back within a second.
    public static let watchRestartDelays: [TimeInterval] = [1, 5, 30, 60]

    /// A stream that ran this long before it ended was working: its end starts the waits over.
    public static let watchSteadyAfter: TimeInterval = 60
```

- [ ] **Step 4: Write the watcher's state and its restart rule** — `Sources/SherlockMeCore/Watcher.swift`:

```swift
import Foundation

/// Whether SherlockMe can see the Touch ID key: what the menu's status line and the Health page report.
public enum WatcherState: Equatable, Sendable {
    /// `log stream` runs and its lines reach the rule.
    case watching
    /// The stream ended or could not start, and starts again after `WatchRestart.delay`. Meanwhile the key
    /// does what macOS makes it do.
    case stopped
    /// This account is not an administrator and cannot read the log: nothing is started, and the key does
    /// what macOS makes it do.
    case needsAdministrator
}

/// When a stream that ended is started again.
public enum WatchRestart {
    /// The wait before starting the stream again, after it has ended `failures` times in a row (1 for the
    /// first): `K.watchRestartDelays`, the last one repeated.
    public static func delay(afterFailures failures: Int) -> TimeInterval {
        let delays = K.watchRestartDelays
        return delays[min(max(failures, 1), delays.count) - 1]
    }

    /// How many ends in a row this one makes. A stream that ran `K.watchSteadyAfter` or longer was working,
    /// so its end is the first of a new run.
    public static func failures(previous: Int, ranFor seconds: TimeInterval) -> Int {
        seconds >= K.watchSteadyAfter ? 1 : previous + 1
    }
}
```

- [ ] **Step 5: Run it and see it pass**

Run: `swift test --filter WatcherTests`
Expected: `Executed 2 tests, with 0 failures`.

- [ ] **Step 6: Write the failing Platform test** — `Tests/SherlockMePlatformTests/TouchIDLogStreamTests.swift`.
  It uses `/bin/sh` and `/bin/sleep` as stand-ins for `log stream`; it never starts `/usr/bin/log`.

```swift
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
```

- [ ] **Step 7: Run it and see it fail**

Run: `swift test --filter TouchIDLogStreamTests`
Expected: a build failure, `cannot find 'TouchIDLogStream' in scope`.

- [ ] **Step 8: Write the stream** — `Sources/SherlockMePlatform/TouchIDLogStream.swift`:

```swift
import Foundation
import SherlockMeCore

/// `log stream`, reading the Touch ID lines as they are written: one child process for as long as it runs.
/// Its lines are parsed by `TouchIDLog` and handed over on the queue the stream was given, in the order they
/// came, and its end is reported there once, after its last line. `stop()` is not an end.
///
/// Every method is called on that queue.
public final class TouchIDLogStream: @unchecked Sendable {
    private let queue: DispatchQueue
    private let executable: URL
    private let arguments: [String]
    private let onEvent: (Date, TouchIDEvent) -> Void
    private let onEnd: (Int32) -> Void

    private var process: Process?
    private var buffer = Data()
    private var pipeClosed = false
    private var exitStatus: Int32?
    private var finished = false

    /// The real stream is `/usr/bin/log stream --style ndjson` with `TouchIDLog.predicate`; a test passes a
    /// stand-in that prints lines of its own.
    public init(queue: DispatchQueue,
                executable: URL = URL(fileURLWithPath: "/usr/bin/log"),
                arguments: [String] = ["stream", "--style", "ndjson", "--predicate", TouchIDLog.predicate],
                onEvent: @escaping (Date, TouchIDEvent) -> Void,
                onEnd: @escaping (Int32) -> Void) {
        self.queue = queue
        self.executable = executable
        self.arguments = arguments
        self.onEvent = onEvent
        self.onEnd = onEnd
    }

    /// Starts the child. Throws when it cannot be started at all.
    public func start() throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            // An empty read is the end of the pipe; the handler would be called for it again and again.
            if chunk.isEmpty { handle.readabilityHandler = nil }
            self?.queue.async { chunk.isEmpty ? self?.pipeDidClose() : self?.consume(chunk) }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            self?.queue.async { self?.childDidExit(status) }
        }
        try process.run()
        self.process = process
    }

    /// Ends the child, and reports nothing more: no line, no end.
    public func stop() {
        finished = true
        (process?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
    }

    private func consume(_ chunk: Data) {
        guard !finished else { return }
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let (time, event) = TouchIDLog.parse(Data(line)) { onEvent(time, event) }
        }
    }

    private func pipeDidClose() {
        pipeClosed = true
        reportTheEndOnce()
    }

    private func childDidExit(_ status: Int32) {
        exitStatus = status
        reportTheEndOnce()
    }

    /// Only once both the child has exited and its last line has been read, so no line comes after the end.
    private func reportTheEndOnce() {
        guard !finished, pipeClosed, let status = exitStatus else { return }
        finished = true
        process = nil
        onEnd(status)
    }
}
```

- [ ] **Step 9: Run it and see it pass**

Run: `swift test --filter TouchIDLogStreamTests`
Expected: `Executed 3 tests, with 0 failures` (the stop test takes about a second: it waits to see that no
end comes).

- [ ] **Step 10: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 103 tests, Platform 17, both passed.

- [ ] **Step 11: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/Constants.swift Sources/SherlockMeCore/Watcher.swift \
        Tests/SherlockMeCoreTests/WatcherTests.swift Sources/SherlockMePlatform/TouchIDLogStream.swift \
        Tests/SherlockMePlatformTests/TouchIDLogStreamTests.swift
git commit -m "feat(platform): the log stream the rule reads, and when it starts again" \
           -m "<attribution trailers>"
```

---

### Task 4: The lock, and the session

**Model:** sonnet. **Reviewer:** opus (a private framework, and a call that must never be made by a test).

**Files:**
- Create: `Sources/SherlockMePlatform/SessionAgent.swift`
- Create: `Sources/SherlockMePlatform/LoginSession.swift`
- Modify: `Sources/SherlockMePlatform/Log.swift` (the `touchid` category)
- Create: `Tests/SherlockMePlatformTests/SessionAgentTests.swift`
- Create: `Tests/SherlockMePlatformTests/LoginSessionTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `public enum SessionAgent { static var canLock: Bool; @discardableResult static func
  lockScreen() -> Int32 }`; `public enum LoginSession { static var screenIsLocked: Bool; static var
  userIsAdministrator: Bool }`; `Log.touchID: Logger`.

`SACLockScreenImmediate` is loginwindow's own immediate lock, the one the Touch ID key runs, in the session
agent's public interface on macOS 27 (`docs/macOS.md`). **Calling it locks the Mac: the test looks it up and
never calls it.** The membership functions of `<membership.h>` are not visible to Swift; the directory
service is asked through Collaboration.framework instead.

- [ ] **Step 1: Write the failing tests** — `Tests/SherlockMePlatformTests/SessionAgentTests.swift`:

```swift
import XCTest
import SherlockMePlatform

/// The one call SherlockMe makes to loginwindow is there on this macOS. It is looked up and never made:
/// making it would lock the Mac running the tests.
final class SessionAgentTests: XCTestCase {
    func testTheLockCallIsThere() {
        XCTAssertTrue(SessionAgent.canLock)
    }
}
```

and `Tests/SherlockMePlatformTests/LoginSessionTests.swift`:

```swift
import XCTest
import SherlockMePlatform

final class LoginSessionTests: XCTestCase {
    /// The directory service agrees with `id -Gn`, which lists `admin` for an administrator.
    func testTheAdministratorAnswerAgreesWithId() throws {
        let id = Process()
        id.executableURL = URL(fileURLWithPath: "/usr/bin/id")
        id.arguments = ["-Gn"]
        let pipe = Pipe()
        id.standardOutput = pipe
        try id.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        id.waitUntilExit()
        let groups = output.split(whereSeparator: \.isWhitespace).map(String.init)
        XCTAssertEqual(LoginSession.userIsAdministrator, groups.contains("admin"))
    }
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `swift test --filter 'SessionAgentTests|LoginSessionTests'`
Expected: a build failure, `cannot find 'SessionAgent' in scope`.

- [ ] **Step 3: Write the lock** — `Sources/SherlockMePlatform/SessionAgent.swift`:

```swift
import Foundation

/// loginwindow's session agent, reached through the private login.framework, loaded once and looked up with
/// `dlsym`. On macOS 27 `SACLockScreenImmediate` is in the session agent's public interface
/// (`LFSessionAgentListenerPublicInterface`), which needs no entitlement (`docs/macOS.md`).
public enum SessionAgent {
    private typealias Call = @convention(c) () -> Int32

    private static let lockCall: Call? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_NOW),
              let address = dlsym(handle, "SACLockScreenImmediate") else { return nil }
        return unsafeBitCast(address, to: Call.self)
    }()

    /// Whether this macOS has the call. Looked up, never made.
    public static var canLock: Bool { lockCall != nil }

    /// Locks the screen now: loginwindow's own immediate lock, the one the Touch ID key runs. Measured: the
    /// Mac locked 0.09 to 0.14 s after the key went down when this was called on the key's log line (runs 7
    /// to 9). A synchronous round trip to loginwindow; 0 on success, -1 when the call is missing.
    @discardableResult
    public static func lockScreen() -> Int32 { lockCall?() ?? -1 }
}
```

- [ ] **Step 4: Write the session** — `Sources/SherlockMePlatform/LoginSession.swift`:

```swift
import Collaboration
import CoreGraphics
import Foundation

/// The login session the app runs in: whether its screen is locked, and whether its user may read the log.
public enum LoginSession {
    /// Whether the screen is locked now, as the window server says (`CGSSessionScreenIsLocked`); false when
    /// the session cannot be read.
    public static var screenIsLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    /// Whether the user is an administrator, a member of the `admin` group (80): the one kind of account
    /// that reads the unified log without sudo. Asked of the directory service, so a membership through a
    /// nested group counts; false when it cannot answer.
    public static var userIsAdministrator: Bool {
        let authority = CBIdentityAuthority.default()
        guard let user = CBUserIdentity(posixUID: getuid(), authority: authority),
              let admin = CBGroupIdentity(posixGID: 80, authority: authority) else { return false }
        return user.isMember(ofGroup: admin)
    }
}
```

- [ ] **Step 5: Add the log category.** In `Sources/SherlockMePlatform/Log.swift`, replace

```swift
    // TEMPLATE: one category per feature, so one predicate reads one behaviour.
```

with

```swift
    /// The Touch ID key: the log stream starting, ending and starting again, every lock and relock with
    /// loginwindow's answer, every unlock left alone and why, and at `debug` every line the rule was given.
    public static let touchID = Logger(subsystem: AppIdentity.logSubsystem, category: "touchid")
```

- [ ] **Step 6: Run them and see them pass**

Run: `swift test --filter 'SessionAgentTests|LoginSessionTests'`
Expected: `Executed 2 tests, with 0 failures` across the two.

- [ ] **Step 7: Check that no test makes the call**

Run: `rg -n 'lockScreen\(' Tests/`
Expected: nothing.

- [ ] **Step 8: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 103 tests, Platform 19, both passed.

- [ ] **Step 9: Commit** (the controller, after review)

```bash
git add Sources/SherlockMePlatform/SessionAgent.swift Sources/SherlockMePlatform/LoginSession.swift \
        Sources/SherlockMePlatform/Log.swift Tests/SherlockMePlatformTests/SessionAgentTests.swift \
        Tests/SherlockMePlatformTests/LoginSessionTests.swift
git commit -m "feat(platform): loginwindow's immediate lock, and the session it runs in" \
           -m "<attribution trailers>"
```

---

### Task 5: The behaviour, wired

**Model:** opus. **Reviewer:** fable-xhigh-reviewer (the queue, the restart loop, the stop at quit, and the
guarantee that SherlockMe holds nothing).

**Files:**
- Create: `Sources/SherlockMeApp/TouchIDGuard.swift`
- Modify: `Sources/SherlockMeApp/AppDelegate.swift`
- Modify: `docs/functional.md` (§0 and §1 new, §6), `docs/architecture.md`, `CLAUDE.md`

**Interfaces:**
- Consumes: `LockRule`, `TouchIDEvent` (Tasks 1, 2); `WatcherState`, `WatchRestart`, `TouchIDLogStream`
  (Task 3); `SessionAgent`, `LoginSession`, `Log.touchID` (Task 4).
- Produces: `final class TouchIDGuard: @unchecked Sendable` with `static let shared`, `func start()`, `func
  stop()`, `var status: Status`; `struct Status: Equatable { var watcher: WatcherState; var lastLock: Date?;
  var lastRelock: Date? }`.

The app target has no automated tests (`CLAUDE.md`). What stands in for them here: every decision is in the
rule, which Task 2 tests; this file only carries lines in and actions out, and the reviewer reads it against
the Review Focus. **Do not run the app to try it.**

- [ ] **Step 1: Write the object** — `Sources/SherlockMeApp/TouchIDGuard.swift`:

```swift
import Foundation
import SherlockMeCore
import SherlockMePlatform

/// SherlockMe's one behaviour. It reads the Touch ID lines off the log (`TouchIDLogStream`), runs them
/// through `LockRule`, and locks when the rule says so. Every decision is the rule's; this carries the lines
/// in and the actions out, and starts the stream again when it ends.
///
/// **Everything it does runs on one serial queue of its own**, never the main thread, so a window being drawn
/// never delays a lock. The menu and the Health page read `status`, a copy kept under a lock.
///
/// **It holds nothing in macOS** (`docs/functional.md` §0): no hold on loginwindow, no preference, no setting.
/// Whenever it is not running or cannot read the log, the Touch ID key does exactly what macOS makes it do.
final class TouchIDGuard: @unchecked Sendable {
    static let shared = TouchIDGuard()

    struct Status: Equatable {
        var watcher: WatcherState = .stopped
        /// When the Touch ID key last locked the Mac, and when the rule last locked it again.
        var lastLock: Date?
        var lastRelock: Date?
    }

    private let queue = DispatchQueue(label: "\(AppIdentity.bundleIdentifier).touchid", qos: .userInteractive)
    private let statusLock = NSLock()
    private var current = Status()

    // Read and written on `queue` only.
    private var running = false
    private var rule = LockRule(screenIsLocked: false)
    private var stream: TouchIDLogStream?
    private var streamStarted: Date?
    private var failures = 0

    /// What the menu and the Health page show. Any thread.
    var status: Status { statusLock.withLock { current } }

    /// Starts watching, at launch. Nothing here asks for a permission: an administrator account reads the log
    /// without one, and on any other account nothing is started.
    func start() {
        queue.async { [self] in
            guard !running else { return }
            running = true
            guard LoginSession.userIsAdministrator else {
                update { $0.watcher = .needsAdministrator }
                Log.touchID.notice("not watching: this account is not an administrator, and only one can read the log")
                return
            }
            startStream()
        }
    }

    /// Stops the stream before the process goes: a quit, an update's install and the uninstall all leave
    /// through `NSApp.terminate`. Synchronous, so the `log` child is gone when this returns.
    func stop() {
        queue.sync { [self] in
            running = false
            stream?.stop()
            stream = nil
            update { $0.watcher = .stopped }
        }
    }

    // MARK: - The stream

    private func startStream() {
        guard running else { return }
        // A fresh rule each time: a press that was under way when a stream ended is forgotten, which can
        // only cost a relock, never make one in error.
        rule = LockRule(screenIsLocked: LoginSession.screenIsLocked)
        let stream = TouchIDLogStream(queue: queue,
                                      onEvent: { [weak self] time, event in self?.handle(event, at: time) },
                                      onEnd: { [weak self] status in self?.streamEnded(status: status) })
        do {
            try stream.start()
        } catch {
            Log.touchID.error("log stream could not start: \(error.localizedDescription, privacy: .public)")
            startAgainLater(ranFor: 0)
            return
        }
        self.stream = stream
        streamStarted = Date()
        update { $0.watcher = .watching }
        Log.touchID.notice("watching the Touch ID key, the screen \(self.rule.screenIsLocked ? "locked" : "unlocked", privacy: .public)")
    }

    private func streamEnded(status: Int32) {
        stream = nil
        let ranFor = streamStarted.map { Date().timeIntervalSince($0) } ?? 0
        Log.touchID.error("log stream ended, status \(status), after \(Int(ranFor)) s")
        startAgainLater(ranFor: ranFor)
    }

    private func startAgainLater(ranFor: TimeInterval) {
        update { $0.watcher = .stopped }
        failures = WatchRestart.failures(previous: failures, ranFor: ranFor)
        let delay = WatchRestart.delay(afterFailures: failures)
        Log.touchID.notice("starting log stream again in \(Int(delay)) s, end \(self.failures) in a row")
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in self?.startStream() }
    }

    // MARK: - The rule

    private func handle(_ event: TouchIDEvent, at time: Date) {
        Log.touchID.debug("\(String(describing: event), privacy: .public) at \(time.timeIntervalSince1970, privacy: .public)")
        perform(rule.handle(event, at: time))
    }

    private func perform(_ actions: [LockRule.Action]) {
        for action in actions {
            switch action {
            case .lock:
                let result = SessionAgent.lockScreen()
                update { $0.lastLock = Date() }
                if result == 0 {
                    Log.touchID.notice("the Touch ID key went down: locked")
                } else {
                    Log.touchID.error("the Touch ID key went down: the lock failed, result \(result)")
                }
            case .relock:
                let result = SessionAgent.lockScreen()
                update { $0.lastRelock = Date() }
                if result == 0 {
                    Log.touchID.notice("the finger that pressed the key unlocked the Mac: locked again")
                } else {
                    Log.touchID.error("the finger that pressed the key unlocked the Mac: the relock failed, result \(result)")
                }
            case .wake(let due):
                queue.asyncAfter(deadline: .now() + max(0, due.timeIntervalSinceNow)) { [weak self] in
                    guard let self, self.running else { return }
                    // Never earlier than the rule asked, even if the wall clock stepped meanwhile.
                    self.perform(self.rule.tick(at: max(Date(), due)))
                }
            case .followedMacOSLock:
                update { $0.lastLock = Date() }
                Log.touchID.notice("macOS locked on a press whose key line was not read: following that press")
            case .leftUnlocked(let reason):
                Log.touchID.notice("unlock left alone: \(String(describing: reason), privacy: .public)")
            }
        }
    }

    private func update(_ change: (inout Status) -> Void) {
        statusLock.withLock { change(&current) }
    }
}
```

- [ ] **Step 2: Start it at launch.** In `Sources/SherlockMeApp/AppDelegate.swift`, replace

```swift
        // TEMPLATE: start the app's own behaviour here, in the layer that owns it. Nothing here may ask
        // macOS for a permission: the wizard's own button is the only thing in the app that does, because a
        // prompt nobody clicked for arrives with no explanation beside it and macOS remembers a refusal for
        // good (the macos-building-onboarding skill).
```

with

```swift
        // The Touch ID key, from now until the app quits. Nothing here asks macOS for a permission: an
        // administrator account reads the log without one, and on any other account the key is left to
        // macOS and the menu says so.
        TouchIDGuard.shared.start()
```

- [ ] **Step 3: Stop it at quit.** In the same file, replace

```swift
    /// Reached by every quit, the menu's, the Settings button's and the update's alike, because all three go
    /// through `NSApplication.terminate`. TEMPLATE: put back here anything the app changed on the Mac that
    /// must not outlive it.
    func applicationWillTerminate(_ notification: Notification) {
```

with

```swift
    /// Reached by every quit, the menu's, the Settings button's, the update's and the uninstall's alike,
    /// because all of them go through `NSApplication.terminate`. The `log stream` child is stopped here so it
    /// does not outlive the app; SherlockMe changes nothing else on the Mac.
    func applicationWillTerminate(_ notification: Notification) {
        TouchIDGuard.shared.stop()
```

- [ ] **Step 4: Build and test**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 103, Platform 19, both passed.

- [ ] **Step 5: The guarantees and the feature, in `docs/functional.md`.** Replace the whole section from
  the line `## 1. The feature` down to, not including, `## 2. Settings` with:

```markdown
## 0. The guarantees

**SherlockMe must never leave the Touch ID key unable to lock the Mac, and never undo an unlock the user made
on purpose.** The sections below are the rules the app follows; these are the rules every other one is held
to. **A request that would loosen one is a conflict** under step 2 of `docs/shared/workflow.md`: the rule is
quoted to the owner, and nothing changes until the owner has said so for that rule. `LockRuleTests` pins 2
and 3.

1. **It holds nothing in macOS**: no hold on loginwindow, no preference, no Touch ID setting. Whenever
   SherlockMe is not running, has crashed or cannot read the log, the key does exactly what macOS makes it
   do. §1.
2. **It locks the Mac again at most `K.relocksPerPress` (1) time per press**, and only after an unlock that
   comes within `K.relockWindow` (6 s) of the lock, by the finger the lock screen found resting on the
   sensor as it began to read. §1.
3. **A press of the key on the lock screen, a password, a touch later in the read and every unlock outside
   that window are left alone.** §1.
4. **It never touches the Touch ID settings, and never runs anything as root.** §1.
5. **It asks for no permission.** §4.
6. **Nothing it does waits on the main thread**, so a window being drawn never delays a lock.
   `docs/architecture.md`, *Threading*.

## 1. The feature

SherlockMe does one thing: **when the Touch ID key is clicked, the Mac locks, and stays locked.** macOS alone
locks 0.31 s after the key goes down, and the lock screen then reads the finger still resting on the sensor
and unlocks the Mac again, 1.1 to 1.4 s after the press (`docs/macOS.md`). There is no setting.

**What it watches**: one `/usr/bin/log stream` child process, reading these lines and no other
(`TouchIDLog`). All are logged at the default level, which an administrator account reads without sudo.

| Line | What it means |
|---|---|
| biometrickitd `touchIDButtonPressed: 1` | the key went down, the built-in button or a Magic Keyboard with Touch ID |
| loginwindow `handleSystemEvent:` … `calling to lock screen immediate` | macOS locking on the key itself, 0.31 s after it went down |
| biometrickitd `match:withOptions:` | something started reading the sensor |
| biometrickitd status 63, status 64 | a finger arrived on the sensor, left it; reported only while it is read |
| loginwindow `com.apple.screenIsLocked`, `com.apple.screenIsUnlocked` | the screen locked, unlocked |

**What it does** (`LockRule`), on the log's own times:

1. **The key goes down while the screen is unlocked: SherlockMe locks the Mac at once**, with loginwindow's
   own immediate lock (`SACLockScreenImmediate`). Measured: locked 0.09 to 0.14 s after the key went down,
   where macOS alone takes 0.38 s. That press is the current one. A press whose key line was not read, known
   only from macOS locking on it, becomes the current one the same way.
2. **The lock screen starts reading the sensor within `K.readAfterLock` (3 s) of that lock**: when it did is
   kept.
3. **A finger seen within `K.restingFinger` (0.5 s) of that read beginning was already there**: the finger
   that pressed the key, resting. One that leaves within `K.keyBlip` (0.1 s) was the key coming up, and is
   forgotten.
4. **The screen unlocks within `K.relockWindow` (6 s) of the lock, with that finger still on the sensor or
   gone at most `K.matchAfterLift` (0.5 s) before: SherlockMe locks the Mac again `K.relockDelay` (0.5 s)
   later**, if the screen has stayed unlocked. Once per press (`K.relocksPerPress`). The Mac is unlocked for
   about 0.6 s in between, and in every measured run a Mac locked again stayed locked until the owner
   unlocked it.
5. **Everything else is left alone**: the key pressed on the lock screen (the user unlocking, which also
   gives up a relock still to come), a finger that arrives later in the read, a password, an Apple Watch, an
   unlock after the window, and any unlock that follows no press.

**When it cannot watch**, the key does exactly what macOS makes it do, and the menu and the Health page say
why:

- **An account that is not an administrator** cannot read the log: nothing is started. The wizard's last
  page says so too.
- **The stream ends or cannot start**: it is started again after 1, 5, 30, then every 60 s
  (`K.watchRestartDelays`); a stream that ran `K.watchSteadyAfter` (60 s) or longer before it ended starts
  the waits over. Each start reads again whether the screen is locked and forgets any press under way.

**What it logs**, category `touchid`: the stream starting, ending and starting again; every lock and relock
with loginwindow's answer; every unlock left alone soon after a lock, and why; at `debug`, every line the
rule was given.
```

- [ ] **Step 6: The uninstall, in `docs/functional.md` §6.** Replace

```markdown
1. The **login item**, while the bundle it names is still where it names it. TEMPLATE: a permission the app
   was granted is given back first, in the same step, for the same reason: `tccutil reset` against a bundle
   identifier with no bundle behind it fails, and nothing puts that right afterwards.
```

with

```markdown
1. The **login item**, while the bundle it names is still where it names it. SherlockMe is granted no
   permission, so there is none to give back.
```

and replace

```markdown
5. The app quits. Whatever could not be done is named, with what the system said about it.
```

with

```markdown
5. The app quits, and the `log stream` it started stops with it. Whatever could not be done is named, with
   what the system said about it.
```

- [ ] **Step 7: `docs/architecture.md`.** Replace

```text
                                  ←  Tools/axprobe (its own, imports nothing of the app's)
```

with

```text
                                  ←  Tools/axprobe, Tools/touchprobe (their own, import nothing of the app's)
```

replace

```markdown
- **`Tools/axprobe`** never ships. `scripts/make-app.sh` copies one executable into the bundle and this is
  not it.
```

with

```markdown
- **`Tools/axprobe`** and **`Tools/touchprobe`** never ship. `scripts/make-app.sh` copies one executable into
  the bundle, and neither is it.
```

replace the three rows

```markdown
| Core | TEMPLATE: the feature's rules | Values in, a decision out. |
```

```markdown
| Platform | TEMPLATE: the one call that touches the system for the feature | |
```

```markdown
| App | `SherlockMeMain`, `AppDelegate`, `MenuBarController` | The app, and TEMPLATE: the one object that decides the behaviour. |
```

with, in the same places,

```markdown
| Core | `TouchIDLog`, `LockRule`, `Watcher` | The feature: the lines SherlockMe reads and what each means, the rule that turns them into a lock or a relock, when a stream that ended starts again. Values in, a decision out. |
```

```markdown
| Platform | `TouchIDLogStream`, `SessionAgent`, `LoginSession` | The feature's system boundary: the `log stream` child, loginwindow's immediate lock through the private login.framework, whether the screen is locked and whether the user is an administrator. |
```

```markdown
| App | `SherlockMeMain`, `AppDelegate`, `MenuBarController`, `TouchIDGuard` | The app, and the one object that runs the behaviour: the stream's lines into the rule, the rule's actions out. |
```

replace

```markdown
- Everything is on the **main actor**: the windows, the settings store, the wiring. TEMPLATE: a feature
  that must answer fast, or that blocks, gets a queue of its own and says so here.
```

with

```markdown
- Everything is on the **main actor**: the windows, the settings store, the wiring, **except the Touch ID
  key**. `TouchIDGuard` runs on one serial queue of its own (`<bundle identifier>.touchid`,
  user-interactive): the stream's lines, the rule, the lock call and the relock's timer, so a window being
  drawn never delays a lock. The menu and the Health page read its status, a copy kept under a lock, and
  never wait on that queue; the one wait on it is `stop()` at quit, which returns once the `log` child is
  gone.
```

and at the end of the bullet that starts `- **Nothing polls while idle.**`, after `also two seconds.`, add
` The \`log stream\` child is not a poll: it writes only when one of the lines SherlockMe reads is logged, a
few per press.`

- [ ] **Step 8: `CLAUDE.md`.** Replace

```markdown
the sensor, unlocks it again about a second later. **Its core is designed and not built yet.** It will lock
the Mac the instant the key goes down (0.1 s, against macOS's 0.38 s) and, when the finger that pressed the
key unlocks it anyway, lock it again 0.5 s later, once per press; a deliberate unlock is never undone. It
```

with

```markdown
the sensor, unlocks it again about a second later. SherlockMe locks the Mac the instant the key goes down
(0.1 s, against macOS's 0.38 s) and, when the finger that pressed the key unlocks it anyway, locks it again
0.5 s later, once per press; a deliberate unlock is never undone. It
```

and replace

```markdown
unable to lock.** **Before changing the mechanism, read the design
```

with

```markdown
unable to lock**: `docs/functional.md` §0 holds its guarantees. **Before changing the mechanism, read the design
```

In *Where a change usually lands*, replace the row

```markdown
| TEMPLATE: the feature | `Core/…` for anything decidable from values alone, `Platform/…` for the one call that touches the system, `App/…` for wiring and windows | `functional.md` §1 |
```

with

```markdown
| the Touch ID key: what is read, the rule, a lock | **`functional.md` §0 and `docs/pitfalls.md` first.** `Core/TouchIDLog.swift` (the lines), `Core/LockRule.swift` (the rule), `Core/Watcher.swift` (the restarts), the Touch ID numbers in `Core/Constants.swift` — `TouchIDLogTests`, `LockRuleTests`, `WatcherTests`; `Platform/TouchIDLogStream.swift`, `SessionAgent.swift`, `LoginSession.swift` — their tests; `App/TouchIDGuard.swift` | `functional.md` §0, §1 |
```

In *Commands*, replace

```markdown
  (`log` alone is a zsh builtin, hence the full path). Categories: `app`, `update`, `onboarding` (the
  wizard's poll, the stepping button's word, and at `debug` where that button actually is).
```

with

```markdown
  (`log` alone is a zsh builtin, hence the full path). Categories: `app`, `update`, `onboarding` (the
  wizard's poll, the stepping button's word, and at `debug` where that button actually is), `touchid` (the
  stream starting and ending, every lock and relock, every unlock left alone and why, and at `debug` every
  line the rule was given).
```

In *Architecture*, replace

```markdown
  build otherwise), and it never reads a clock. `Settings` · `Constants` (`K`, every number with its
```

with

```markdown
  build otherwise), and it never reads a clock. `TouchIDLog` + `LockRule` + `Watcher` (the Touch ID key:
  what is read, the rule, the restarts) · `Settings` · `Constants` (`K`, every number with its
```

replace

```markdown
- **`Sources/SherlockMePlatform`** — the only code that talks to the system. `LoginItem` · `SettingsStore` ·
```

with

```markdown
- **`Sources/SherlockMePlatform`** — the only code that talks to the system. `TouchIDLogStream` +
  `SessionAgent` + `LoginSession` (the Touch ID key: the `log stream` child, the lock, the session) ·
  `LoginItem` · `SettingsStore` ·
```

and replace

```markdown
- **`Sources/SherlockMeApp`** — `AppDelegate` wires everything. `MenuBarController` · the onboarding wizard
```

with

```markdown
- **`Sources/SherlockMeApp`** — `AppDelegate` wires everything. `TouchIDGuard` (the behaviour, on a queue of
  its own) · `MenuBarController` · the onboarding wizard
```

In *Rules*, replace

```markdown
- TEMPLATE: the invariants of the feature, each one sentence, bold, with the reason.
```

with

```markdown
- **SherlockMe holds nothing in macOS**: no hold on loginwindow, no preference, no Touch ID setting. Not
  running must always mean the key does what macOS makes it do (`functional.md` §0).
- **A relock needs every condition of the rule**: a press SherlockMe followed, the lock screen's read within
  3 s, a finger in its first half-second, the unlock within 6 s, once. Each one is what keeps a deliberate
  unlock alone; widening one to catch more undoes one (`docs/pitfalls.md` 6).
- **Nothing locks the Mac unless the owner is at the keyboard and has said so**: no test, no probe run, no
  build step. `SessionAgentTests` looks the call up and never makes it.
- **Everything the key does runs on `TouchIDGuard`'s queue**, never on the main thread.
```

- [ ] **Step 9: Check the words**

Run: `rg -n 'TEMPLATE' docs/functional.md docs/architecture.md CLAUDE.md`
Expected: only the lines Tasks 6 to 8 fill: functional.md §2, §3, §4; CLAUDE.md's Health row, *Traps*.

- [ ] **Step 10: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeApp/TouchIDGuard.swift Sources/SherlockMeApp/AppDelegate.swift \
        docs/functional.md docs/architecture.md CLAUDE.md
git commit -m "feat: the Touch ID key locks the Mac at once and keeps it locked" -m "<attribution trailers>"
```

---

### Task 6: The menu line and the Health page

**Model:** sonnet. **Reviewer:** sonnet, with the `macos-building-settings-pages` skill's *The Health page*
and *The words* in hand.

**Invoke the `macos-building-settings-pages` skill before the first edit** (`CLAUDE.md` says so for any work
on the Health page).

**Files:**
- Modify: `Sources/SherlockMeCore/StringsMenu.swift`
- Replace: `Sources/SherlockMeCore/StringsHealthPage.swift`
- Modify: `Sources/SherlockMeCore/HealthReport.swift`
- Modify: `Sources/SherlockMeApp/MenuBarController.swift`
- Replace: `Sources/SherlockMeApp/HealthCheck.swift`
- Modify: `Sources/SherlockMeApp/SettingsHealthPage.swift`
- Delete: `Sources/SherlockMePlatform/ProcessStats.swift`
- Replace: `Tests/SherlockMeCoreTests/HealthTests.swift`
- Modify: `Tests/SherlockMeCoreTests/LocalizationTests.swift`, `Tests/SherlockMeCoreTests/WatcherTests.swift`
- Modify: `docs/functional.md` §2 and §3, `docs/architecture.md`, `docs/manual-test-checklist.md` §2,
  `CLAUDE.md`

**Interfaces:**
- Consumes: `WatcherState` (Task 3), `TouchIDGuard.shared.status` (Task 5).
- Produces: `MenuStrings.status(_: WatcherState) -> String`, `.watching`, `.stoppedStartingAgain`,
  `.needsAdministrator`; `HealthFacts(watcher:sinceLastLock:sinceLastRelock:recentCrashes:)`;
  `HealthReport.watching(_:) -> HealthRow`; `HealthPageStrings` `watchingLabel`, `running`, `stopped`,
  `stoppedFix`, `needsAdministratorFix`, `lastLockLabel`, `lastRelockLabel`, `noneYet`, `ago(seconds:)`.
  Gone: `HealthFacts.runningSeconds`, `.memoryBytes`, `HealthPageStrings.everythingWorks`, `runningForLabel`,
  `memoryLabel`, `megabytes`, `ProcessStats`.

The sentences are proposals the owner has not read (*Decisions made without the owner*, 7). The Users &
Groups pane and its switch are quoted from macOS's own strings: `UsersGroups.appex`, `InfoPlist.loctable`
(“Users & Groups”, “Utilisateurs et groupes”) and `Localizable.loctable` (“Allow this user to administer this
computer”, « Autoriser cet utilisateur à administrer cet ordinateur »).

- [ ] **Step 1: Write the failing tests.** Replace `Tests/SherlockMeCoreTests/HealthTests.swift` with:

```swift
import XCTest
@testable import SherlockMeCore

/// The Health page's rules: which colour a check takes, which lines every app adds while they are wrong,
/// how long the two tables may grow, and which files are this app's crash reports.
final class HealthTests: XCTestCase {
    override func tearDown() {
        Loc.language = .en
        super.tearDown()
    }

    private func facts(_ watcher: WatcherState = .watching, lastLock: TimeInterval? = 125,
                       lastRelock: TimeInterval? = nil, crashes: [Date] = []) -> HealthFacts {
        HealthFacts(watcher: watcher, sinceLastLock: lastLock, sinceLastRelock: lastRelock, recentCrashes: crashes)
    }

    // MARK: Levels

    func testAMissingGrantIsRedOnlyWhenTheWizardMarksItRequired() {
        XCTAssertEqual(HealthRules.grant(held: true, required: true), .good)
        XCTAssertEqual(HealthRules.grant(held: true, required: false), .good)
        XCTAssertEqual(HealthRules.grant(held: false, required: true), .failure)
        XCTAssertEqual(HealthRules.grant(held: false, required: false), .warning)
    }

    func testAFixIsShownOnlyWhileItsRowIsOrangeOrRed() {
        let fine = HealthRow(id: "a", label: "A", level: .good, word: "x", fix: "Do this.")
        let wrong = HealthRow(id: "b", label: "B", level: .warning, word: "x", fix: "Do that.")
        let twice = HealthRow(id: "c", label: "C", level: .failure, word: "x", fix: "Do that.")
        XCTAssertEqual([fine, wrong, twice].warnings, ["Do that."])
        XCTAssertEqual([fine].warnings, [])
    }

    // MARK: Watching the Touch ID key

    func testWatchingTheKeyIsGreen() {
        let checks = HealthReport.checks(for: facts())
        XCTAssertEqual(checks.map(\.id), ["touch id key"])
        XCTAssertEqual(checks.first?.level, .good)
        XCTAssertEqual(checks.first?.word, "Running")
        XCTAssertEqual(checks.warnings, [])
    }

    func testAStoppedStreamIsRedAndSaysItComesBack() {
        let checks = HealthReport.checks(for: facts(.stopped))
        XCTAssertEqual(checks.first?.level, .failure)
        XCTAssertEqual(checks.first?.word, "Stopped")
        XCTAssertEqual(checks.warnings, [Loc.settings.health.stoppedFix])
    }

    func testAnAccountThatCannotReadTheLogIsRedAndSaysWhoCanChangeThat() {
        let checks = HealthReport.checks(for: facts(.needsAdministrator))
        XCTAssertEqual(checks.first?.level, .failure)
        XCTAssertEqual(checks.warnings, [Loc.settings.health.needsAdministratorFix])
        XCTAssertEqual(HealthReport.readings(for: facts(.needsAdministrator)), [])
    }

    // MARK: The tables

    func testTheReadings() {
        XCTAssertEqual(HealthReport.readings(for: facts()).map(\.value), ["2 min ago", "None yet"])
        XCTAssertEqual(HealthReport.readings(for: facts(lastLock: nil, lastRelock: 30)).map(\.value),
                       ["None yet", "Just now"])
    }

    func testACrashIsALineOnlyWhileThereIsOne() {
        let crash = Date(timeIntervalSince1970: 1_790_000_000)
        let checks = HealthReport.checks(for: facts(crashes: [crash]))
        XCTAssertEqual(checks.map(\.id), ["touch id key", "crashes"])
        XCTAssertEqual(checks.last?.level, .warning)
        XCTAssertEqual(checks.last?.word, "1")
        XCTAssertEqual(checks.last?.detail, "Last one \(HealthReport.stamp(crash))")
        XCTAssertEqual(checks.warnings, [Loc.settings.health.crashesFix])
    }

    func testTheTablesStayShortInTheWorstCase() {
        let worst = facts(.stopped, lastLock: 60, lastRelock: 60, crashes: [Date(), Date()])
        XCTAssertLessThanOrEqual(HealthReport.checks(for: worst).count, HealthLimits.checks)
        XCTAssertLessThanOrEqual(HealthReport.readings(for: worst).count, HealthLimits.readings)
    }

    // MARK: Crash reports

    func testOnlyThisProcesssCrashReportsAreCounted() {
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.ips", process: "SherlockMe"))
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.crash", process: "SherlockMe"))
        XCTAssertTrue(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010-1.ips", process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "ExcUserFault_SherlockMe-2026-09-21-101010.ips",
                                                  process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMeHelper-2026-09-21-101010.ips",
                                                  process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMe-notes.ips", process: "SherlockMe"))
        XCTAssertFalse(HealthRules.isCrashReport(fileName: "SherlockMe-2026-09-21-101010.diag", process: "SherlockMe"))
    }

    // MARK: The words

    func testDurationsReadInTheTwoLargestUnits() {
        let t = Loc.settings.health
        XCTAssertEqual(t.duration(seconds: 30), "Less than a minute")
        XCTAssertEqual(t.duration(seconds: 125), "2 min")
        XCTAssertEqual(t.duration(seconds: 3_720), "1 h 2 min")
        XCTAssertEqual(t.duration(seconds: 2 * 86_400 + 3 * 3_600 + 59), "2 d 3 h")
        Loc.language = .fr
        XCTAssertEqual(Loc.settings.health.duration(seconds: 2 * 86_400 + 3 * 3_600), "2 j 3 h")
    }

    func testHowLongAgo() {
        let t = Loc.settings.health
        XCTAssertEqual(t.ago(seconds: 30), "Just now")
        XCTAssertEqual(t.ago(seconds: 125), "2 min ago")
        XCTAssertEqual(t.ago(seconds: 2 * 86_400 + 3 * 3_600), "2 d 3 h ago")
        Loc.language = .fr
        XCTAssertEqual(Loc.settings.health.ago(seconds: 30), "À l'instant")
        XCTAssertEqual(Loc.settings.health.ago(seconds: 125), "Il y a 2 min")
    }
}
```

and add to `Tests/SherlockMeCoreTests/WatcherTests.swift`, inside the class, after
`testAStreamThatRanAWhileStartsTheCountOver`:

```swift

    func testTheMenuLineFollowsTheWatcher() {
        let menu = Loc.menu
        XCTAssertEqual(menu.status(.watching), menu.watching)
        XCTAssertEqual(menu.status(.stopped), menu.stoppedStartingAgain)
        XCTAssertEqual(menu.status(.needsAdministrator), menu.needsAdministrator)
    }
```

- [ ] **Step 2: Run them and see them fail**

Run: `swift test --filter 'HealthTests|WatcherTests'`
Expected: a build failure: `HealthFacts` has no `watcher`, `MenuStrings` has no `status`.

- [ ] **Step 3: The menu's words.** Replace `Sources/SherlockMeCore/StringsMenu.swift` with:

```swift
import Foundation

/// The menu-bar menu. `MenuBarController` rebuilds it from scratch on every open and reads these then, so
/// the menu is never a language or a state behind.
///
/// SherlockMe has no switch of its own, so its one line of its own is the read-only status line.
public struct MenuStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: What SherlockMe is doing

    /// The read-only line for what the watcher is doing right now.
    public func status(_ state: WatcherState) -> String {
        switch state {
        case .watching: watching
        case .stopped: stoppedStartingAgain
        case .needsAdministrator: needsAdministrator
        }
    }

    public var watching: String {
        switch language {
        case .en: "Watching the Touch ID key"
        case .fr: "Touche Touch ID surveillée"
        }
    }

    public var stoppedStartingAgain: String {
        switch language {
        case .en: "Touch ID key not watched: starting again"
        case .fr: "Touche Touch ID non surveillée : redémarrage"
        }
    }

    public var needsAdministrator: String {
        switch language {
        case .en: "Touch ID key not watched: not an administrator"
        case .fr: "Touche Touch ID non surveillée : compte non administrateur"
        }
    }

    // MARK: The items every app has

    public var launchAtLogin: String {
        switch language {
        case .en: "Launch at Login"
        case .fr: "Lancer à la connexion"
        }
    }

    public var settings: String {
        switch language {
        case .en: "Settings…"
        case .fr: "Réglages…"
        }
    }

    public var quit: String {
        switch language {
        case .en: "Quit \(AppIdentity.name)"
        case .fr: "Quitter \(AppIdentity.name)"
        }
    }
}
```

- [ ] **Step 4: The Health page's words.** Replace `Sources/SherlockMeCore/StringsHealthPage.swift` with:

```swift
import Foundation

/// The Health page: a table of checks that says whether the app works, and a table of readings.
///
/// A row's word comes from the shared vocabulary (`StatusWords`) wherever one fits; this table holds the
/// labels, the readings and the sentences that say how to put a row right. Console's own name for its crash
/// list is quoted from its loctable (`plutil -extract fr xml1` on
/// `/System/Applications/Utilities/Console.app/Contents/Resources/Localizable.loctable`), like a pane's, and so
/// are the Users & Groups pane and its switch (`UsersGroups.appex`, `InfoPlist.loctable` and
/// `Localizable.loctable`).
public struct HealthPageStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: The two tables

    public var healthTitle: String {
        switch language {
        case .en: "Health"
        case .fr: "Santé"
        }
    }

    public var informationTitle: String {
        switch language {
        case .en: "Information"
        case .fr: "Informations"
        }
    }

    public var checkAgainButton: String {
        switch language {
        case .en: "Check Again"
        case .fr: "Vérifier à nouveau"
        }
    }

    // MARK: Watching the Touch ID key

    public var watchingLabel: String {
        switch language {
        case .en: "Watching the Touch ID key"
        case .fr: "Surveillance de la touche Touch ID"
        }
    }

    public var running: String {
        switch language {
        case .en: "Running"
        case .fr: "En marche"
        }
    }

    public var stopped: String {
        switch language {
        case .en: "Stopped"
        case .fr: "Arrêtée"
        }
    }

    /// The log stream ended, and is started again by itself.
    public var stoppedFix: String {
        switch language {
        case .en: "\(AppIdentity.name) starts it again by itself, and until then the Touch ID key locks the Mac "
            + "the way macOS does. If this stays red, quit \(AppIdentity.name) and open it again."
        case .fr: "\(AppIdentity.name) la relance tout seul, et d'ici là la touche Touch ID verrouille le Mac "
            + "comme le fait macOS. Si cette ligne reste rouge, quittez \(AppIdentity.name) et rouvrez-le."
        }
    }

    /// The account is not an administrator, which only an administrator can change.
    public var needsAdministratorFix: String {
        switch language {
        case .en: "Only an administrator account can see the Touch ID key, and on this one the key locks the Mac "
            + "the way macOS does. In System Settings › Users & Groups, an administrator can turn on "
            + "“Allow this user to administer this computer” for this account."
        case .fr: "Seul un compte administrateur peut voir la touche Touch ID, et sur celui-ci la touche "
            + "verrouille le Mac comme le fait macOS. Dans Réglages Système › Utilisateurs et groupes, un "
            + "administrateur peut activer « Autoriser cet utilisateur à administrer cet ordinateur » pour ce "
            + "compte."
        }
    }

    // MARK: The line every app adds while there is a crash

    public func crashesLabel(days: Int) -> String {
        switch language {
        case .en: "Crashes in the last \(days) days"
        case .fr: "Plantages ces \(days) derniers jours"
        }
    }

    public func lastCrash(_ stamp: String) -> String {
        switch language {
        case .en: "Last one \(stamp)"
        case .fr: "Le dernier le \(stamp)"
        }
    }

    public var crashesFix: String {
        switch language {
        case .en: "Console shows what happened, under “Crash Reports”."
        case .fr: "Console montre ce qui s'est passé, sous « Rapports de blocage »."
        }
    }

    // MARK: Readings

    public var lastLockLabel: String {
        switch language {
        case .en: "Last lock with the Touch ID key"
        case .fr: "Dernier verrouillage par la touche Touch ID"
        }
    }

    public var lastRelockLabel: String {
        switch language {
        case .en: "Last unlock caught"
        case .fr: "Dernier déverrouillage rattrapé"
        }
    }

    /// A reading with nothing to show yet.
    public var noneYet: String {
        switch language {
        case .en: "None yet"
        case .fr: "Aucun pour l'instant"
        }
    }

    /// How long ago something happened, in the two largest units that mean anything.
    public func ago(seconds: TimeInterval) -> String {
        if seconds < 60 {
            switch language {
            case .en: return "Just now"
            case .fr: return "À l'instant"
            }
        }
        switch language {
        case .en: return "\(duration(seconds: seconds)) ago"
        case .fr: return "Il y a \(duration(seconds: seconds))"
        }
    }

    /// How long something lasted, to the minute, in the two largest units that mean anything.
    public func duration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        switch language {
        case .en:
            if days > 0 { return "\(days) d \(hours) h" }
            if hours > 0 { return "\(hours) h \(minutes) min" }
            return minutes > 0 ? "\(minutes) min" : "Less than a minute"
        case .fr:
            if days > 0 { return "\(days) j \(hours) h" }
            if hours > 0 { return "\(hours) h \(minutes) min" }
            return minutes > 0 ? "\(minutes) min" : "Moins d'une minute"
        }
    }
}
```

- [ ] **Step 5: The Health page's rules.** Replace `Sources/SherlockMeCore/HealthReport.swift` with:

```swift
import Foundation

/// Everything the Health page reports, as values. The app gathers them (`Platform` reads the system, `App`
/// reads its own state); this layer turns them into the page's two tables, so what a fact reads as, in which
/// colour and with which sentence, is decided here and tested.
public struct HealthFacts: Equatable, Sendable {
    /// Whether SherlockMe can see the Touch ID key.
    public var watcher: WatcherState
    /// How long ago the Touch ID key last locked the Mac, and the last unwanted unlock was caught; nil
    /// before the first.
    public var sinceLastLock: TimeInterval?
    public var sinceLastRelock: TimeInterval?
    /// When each crash report of this app in the last `K.healthCrashWindow` was written, newest first.
    public var recentCrashes: [Date]

    public init(watcher: WatcherState, sinceLastLock: TimeInterval?, sinceLastRelock: TimeInterval?,
                recentCrashes: [Date]) {
        self.watcher = watcher
        self.sinceLastLock = sinceLastLock
        self.sinceLastRelock = sinceLastRelock
        self.recentCrashes = recentCrashes
    }
}

/// The Health page's two tables: the checks, green, orange or red, and the readings, blue.
///
/// **A check is something that has to be in place or running for the app to work**: a permission, a setup
/// the onboarding asks for (a hook, a rule, an agent), the service or the sensor the feature rests on. A
/// preference is never a check, whichever way it is set (Launch at login, a feature's own switch, a macOS
/// setting that does not stop the app), and neither is a reading. The skill
/// `macos-building-settings-pages` (*The Health page*) holds the rules and every app's list.
public enum HealthReport {
    /// The Health table, in page order: the one mechanism SherlockMe rests on, always there, then the
    /// crashes while there are some. SherlockMe asks for no permission and sets nothing up, so there is no
    /// grant line.
    public static func checks(for facts: HealthFacts) -> [HealthRow] {
        [watching(facts.watcher), crashes(facts.recentCrashes)].compactMap { $0 }
    }

    /// The Information table: when each of the two things SherlockMe does last happened, *None yet* until
    /// the first. Nothing on an account that cannot read the log, where SherlockMe does nothing.
    public static func readings(for facts: HealthFacts) -> [InfoRow] {
        guard facts.watcher != .needsAdministrator else { return [] }
        let t = Loc.settings.health
        return [
            InfoRow(id: "last lock", label: t.lastLockLabel,
                    value: facts.sinceLastLock.map { t.ago(seconds: $0) } ?? t.noneYet),
            InfoRow(id: "last relock", label: t.lastRelockLabel,
                    value: facts.sinceLastRelock.map { t.ago(seconds: $0) } ?? t.noneYet),
        ]
    }

    /// Watching the Touch ID key: one line whatever stops it (one cause, one line), green while the log is
    /// read, red while it is not, with the fix that matches the cause.
    public static func watching(_ state: WatcherState) -> HealthRow {
        let t = Loc.settings.health
        switch state {
        case .watching:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .good, word: t.running)
        case .stopped:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .failure, word: t.stopped,
                             fix: t.stoppedFix)
        case .needsAdministrator:
            return HealthRow(id: "touch id key", label: t.watchingLabel, level: .failure, word: t.stopped,
                             fix: t.needsAdministratorFix)
        }
    }

    /// The line every app of the family ends its Health table with, **only while there is a crash** in the
    /// last `K.healthCrashWindow`: a crash is a problem while it is recent, and no crash is nothing to say.
    public static func crashes(_ recentCrashes: [Date]) -> HealthRow? {
        guard let last = recentCrashes.first else { return nil }
        let t = Loc.settings.health
        return HealthRow(id: "crashes", label: t.crashesLabel(days: Int(K.healthCrashWindow / 86_400)),
                         level: .warning, word: "\(recentCrashes.count)", detail: t.lastCrash(stamp(last)),
                         fix: t.crashesFix)
    }

    /// A moment as a tooltip wants it: the same in every language, sortable, to the minute, in the Mac's own
    /// time zone.
    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
```

The app target no longer builds after these three (it still reads `runningSeconds` and `everythingWorks`);
Steps 6 to 8 put it right before anything runs.

- [ ] **Step 6: The menu.** In `Sources/SherlockMeApp/MenuBarController.swift`, replace

```swift
    /// The family's order: the feature's own state first, a separator, Launch at Login, a separator, the
    /// read-only status lines, a separator, Settings…, a separator, Quit. This app has no feature yet, so
    /// the first two groups are absent.
```

with

```swift
    /// The family's order: the feature's own state first, a separator, Launch at Login, a separator, the
    /// read-only status lines, a separator, Settings…, a separator, Quit. SherlockMe has no switch of its
    /// own, so the first group is absent and its one status line says what it is doing.
```

and replace

```swift
        // TEMPLATE: the feature's own switch and state go first, then a separator, then a read-only line
        // saying what the app is doing right now (`isEnabled = false`), then a separator.

        let login = NSMenuItem(title: words.launchAtLogin, action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
```

with

```swift
        let login = NSMenuItem(title: words.launchAtLogin, action: #selector(toggleLaunchAtLogin),
                               keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let status = NSMenuItem(title: words.status(TouchIDGuard.shared.status.watcher), action: nil,
                                keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
```

- [ ] **Step 7: The Health page's readings.** Replace `Sources/SherlockMeApp/HealthCheck.swift` with:

```swift
import SherlockMeCore
import SherlockMePlatform
import Foundation

/// The readings only the Health page shows: whether the Touch ID key is watched, when it last locked the Mac
/// and when an unwanted unlock was last caught, and the app's crashes. What the rest of the window also shows
/// (the login item) is `SystemStatus`'s, polled every 2 s while the window is open; these are read when the
/// page is shown and when Check Again is pressed, and never on a timer, so a page nobody is looking at costs
/// nothing.
///
/// **The window drives this, not a view**, like `SystemStatus`: `SettingsWindow` reads it when it opens on
/// the Health page and when the page is picked.
@MainActor
final class HealthCheck: ObservableObject {
    struct Readings: Equatable {
        var watcher: WatcherState = .stopped
        var sinceLastLock: TimeInterval?
        var sinceLastRelock: TimeInterval?
        var recentCrashes: [Date] = []
    }

    @Published private(set) var readings = Readings()
    /// True from a press of Check Again until its readings have landed, and for at least
    /// `K.healthMinimumBusy`.
    @Published private(set) var isChecking = false

    /// Everything the page reports, the polled states from `status` and the rest from here.
    func facts(_ status: SystemStatus) -> HealthFacts {
        HealthFacts(watcher: readings.watcher, sinceLastLock: readings.sinceLastLock,
                    sinceLastRelock: readings.sinceLastRelock, recentCrashes: readings.recentCrashes)
    }

    /// Reads everything again. Cheap: a copy taken under a lock and a directory listing.
    func read() {
        let now = Date()
        let process = Bundle.main.executableURL?.lastPathComponent ?? AppIdentity.name
        let touchID = TouchIDGuard.shared.status
        let fresh = Readings(
            watcher: touchID.watcher,
            sinceLastLock: touchID.lastLock.map { now.timeIntervalSince($0) },
            sinceLastRelock: touchID.lastRelock.map { now.timeIntervalSince($0) },
            recentCrashes: CrashReports.recent(process: process, since: now.addingTimeInterval(-K.healthCrashWindow)))
        if fresh != readings { readings = fresh }
    }

    /// Check Again: every reading now, the polled states with them, and a spinner beside the button long
    /// enough to be seen.
    func checkAgain(_ status: SystemStatus) {
        guard !isChecking else { return }
        isChecking = true
        status.refresh()
        read()
        DispatchQueue.main.asyncAfter(deadline: .now() + K.healthMinimumBusy) { [weak self] in
            self?.isChecking = false
        }
    }
}
```

In `Sources/SherlockMeApp/SettingsHealthPage.swift`, delete

```swift
                // TEMPLATE: an app always has checks of its own, and drops this line.
                if checks.isEmpty {
                    StatusRow(AppIdentity.name, mark: .good(t.everythingWorks))
                }
```

Then delete `Sources/SherlockMePlatform/ProcessStats.swift` (`git rm`): nothing reads it any more.

- [ ] **Step 8: Every sentence, listed.** In `Tests/SherlockMeCoreTests/LocalizationTests.swift`, replace

```swift
/// TEMPLATE: every table the app adds gets its accessors listed in `everySentence`, one line per sentence.
/// A table added without a line here is a table nothing checks, and the compiler cannot say so.
```

with

```swift
/// Every accessor of every table is listed in `everySentence`, one line per sentence. A table or a sentence
/// added without a line here is one nothing checks, and the compiler cannot say so.
```

replace

```swift
        for pair in [("menu.launchAtLogin", menu.launchAtLogin),
                     ("menu.settings", menu.settings), ("menu.quit", menu.quit)] { add(pair.0, pair.1) }
```

with

```swift
        for pair in [("menu.launchAtLogin", menu.launchAtLogin),
                     ("menu.settings", menu.settings), ("menu.quit", menu.quit),
                     ("menu.watching", menu.watching),
                     ("menu.stoppedStartingAgain", menu.stoppedStartingAgain),
                     ("menu.needsAdministrator", menu.needsAdministrator)] { add(pair.0, pair.1) }
```

and replace

```swift
                     ("health.everythingWorks", health.everythingWorks),
                     ("health.checkAgainButton", health.checkAgainButton),
                     ("health.runningForLabel", health.runningForLabel),
                     ("health.duration.seconds", health.duration(seconds: 12)),
                     ("health.duration.minutes", health.duration(seconds: 720)),
                     ("health.duration.hours", health.duration(seconds: 11_520)),
                     ("health.duration.days", health.duration(seconds: 190_000)),
                     ("health.memoryLabel", health.memoryLabel), ("health.megabytes", health.megabytes(48)),
```

with

```swift
                     ("health.checkAgainButton", health.checkAgainButton),
                     ("health.watchingLabel", health.watchingLabel), ("health.running", health.running),
                     ("health.stopped", health.stopped), ("health.stoppedFix", health.stoppedFix),
                     ("health.needsAdministratorFix", health.needsAdministratorFix),
                     ("health.lastLockLabel", health.lastLockLabel),
                     ("health.lastRelockLabel", health.lastRelockLabel), ("health.noneYet", health.noneYet),
                     ("health.ago.now", health.ago(seconds: 12)), ("health.ago.minutes", health.ago(seconds: 720)),
                     ("health.duration.seconds", health.duration(seconds: 12)),
                     ("health.duration.minutes", health.duration(seconds: 720)),
                     ("health.duration.hours", health.duration(seconds: 11_520)),
                     ("health.duration.days", health.duration(seconds: 190_000)),
```

- [ ] **Step 9: Run the tests and see them pass**

Run: `swift test --filter 'HealthTests|WatcherTests|LocalizationTests'`
Expected: `HealthTests` 11 tests, `WatcherTests` 3, `LocalizationTests` 6, 0 failures.

- [ ] **Step 10: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 107 tests, Platform 19, both passed. Then the skill's own checks:
`rg -n '[—–‒―‐‑−]' Sources/SherlockMeCore/Strings*.swift` prints nothing, and
`rg -n 'ProcessStats|everythingWorks|runningSeconds|memoryBytes' Sources Tests` prints nothing.

- [ ] **Step 11: `docs/functional.md` §2.** Replace the two rows

```markdown
| **Health** | Health | the checks, green, orange or red, never blue: in SherlockMe only *Crashes in the last 7 days* (`K.healthCrashWindow`, read from `~/Library/Logs/DiagnosticReports`), a count in orange with the last one's date as the tooltip, while there is one; *Everything works* in green in its place while there is none · **Check Again**, with a spinner beside it for at least `K.healthMinimumBusy` (0.5 s) |
| | Information | *Running for* and *Memory used*, in blue |
```

with

```markdown
| **Health** | Health | the checks, green, orange or red, never blue: **Watching the Touch ID key**, always there, green *Running* while the log is read, red *Stopped* while it is not, with the fix that matches why (SherlockMe starts the stream again by itself; only an administrator account can read the log); *Crashes in the last 7 days* (`K.healthCrashWindow`, read from `~/Library/Logs/DiagnosticReports`), a count in orange with the last one's date as the tooltip, only while there is one · **Check Again**, with a spinner beside it for at least `K.healthMinimumBusy` (0.5 s) |
| | Information | *Last lock with the Touch ID key* and *Last unlock caught*, how long ago, *None yet* before the first, in blue; neither on an account that cannot read the log |
```

and replace the paragraph

```markdown
TEMPLATE: a feature page goes between General and System, and the app's own switches live on it. The Health
table gains, before the crash line, one line per permission and per setup the wizard asks for (red when the
wizard marks it required, orange otherwise) and one for the service, listener or sensor the feature rests on;
a check with nothing to say while fine is a line only while it is wrong. The Information table's two readings
give way to the app's own (the last time the feature acted, a sensor's value), five at most. The
`*Everything works*` stand-in goes: an app always has checks of its own.
```

with

```markdown
SherlockMe has no setting of its own, so there is no feature page. It asks for no permission and sets nothing
up, so its Health table has no grant line: the one mechanism it rests on is the log stream, one line whatever
stops it.
```

- [ ] **Step 12: `docs/functional.md` §3.** Replace

```text
Launch at Login             ✓
──────────
Settings…                   ⌘,
```

with

```text
Launch at Login             ✓
──────────
Watching the Touch ID key
──────────
Settings…                   ⌘,
```

and replace

```markdown
TEMPLATE: the feature's own switch comes first, then a separator; a read-only line saying what the app is
doing right now sits above Settings…, with a separator on each side.
```

with

```markdown
The line between the separators is read-only and says what SherlockMe is doing: *Watching the Touch ID key*;
*Touch ID key not watched: starting again* while the stream is started again; *Touch ID key not watched: not
an administrator* on an account that cannot read the log. SherlockMe has no switch of its own.
```

- [ ] **Step 13: The other documents.** In `docs/architecture.md`, replace

```markdown
| | `CrashReports`, `ProcessStats` | What the Health page reads about the app itself: its crash reports, its age and memory. |
```

with

```markdown
| | `CrashReports` | What the Health page reads about the app itself: its crash reports. |
```

In `docs/manual-test-checklist.md`, replace

```markdown
- [ ] TEMPLATE: the feature page, every row, and that each setting survives a quit and relaunch.
```

with

```markdown
- [ ] There is no feature page. Health: *Watching the Touch ID key*, green *Running*; the two readings read
      *None yet*, then how long ago after a press and after a caught unlock (Check Again). The menu's status
      line reads *Watching the Touch ID key*.
```

In `CLAUDE.md`, in the Health row of *Where a change usually lands*, replace

```markdown
the readers `Platform/CrashReports.swift`, `ProcessStats.swift` — `HealthTests` (the worst case holds `HealthLimits`), `CrashReportsTests`. TEMPLATE: the app's own checks and readings |
```

with

```markdown
the reader `Platform/CrashReports.swift` — `HealthTests` (the worst case holds `HealthLimits`), `CrashReportsTests`. SherlockMe's own: *Watching the Touch ID key* (`HealthReport.watching`, one line whatever stops it) and the last lock and the last unlock caught, read from `TouchIDGuard.status` |
```

and in *Architecture* replace

```markdown
  `CrashReports` + `ProcessStats` (what the Health page reads about the app itself) ·
```

with

```markdown
  `CrashReports` (what the Health page reads about the app itself) ·
```

- [ ] **Step 14: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/StringsMenu.swift Sources/SherlockMeCore/StringsHealthPage.swift \
        Sources/SherlockMeCore/HealthReport.swift Sources/SherlockMeApp/MenuBarController.swift \
        Sources/SherlockMeApp/HealthCheck.swift Sources/SherlockMeApp/SettingsHealthPage.swift \
        Sources/SherlockMePlatform/ProcessStats.swift Tests/SherlockMeCoreTests/HealthTests.swift \
        Tests/SherlockMeCoreTests/LocalizationTests.swift Tests/SherlockMeCoreTests/WatcherTests.swift \
        docs/functional.md docs/architecture.md docs/manual-test-checklist.md CLAUDE.md
git commit -m "feat: the menu and the Health page say whether the Touch ID key is watched" \
           -m "<attribution trailers>"
```

---

### Task 7: The wizard, the README, the changelog

**Model:** sonnet. **Reviewer:** sonnet, with the `macos-building-onboarding` skill in hand.

**Invoke the `macos-building-onboarding` skill before the first edit** (`CLAUDE.md` says so for any work on
the wizard).

**Files:**
- Modify: `Sources/SherlockMeCore/StringsOnboarding.swift`
- Modify: `Sources/SherlockMeApp/OnboardingWindow.swift`
- Modify: `Tests/SherlockMeCoreTests/LocalizationTests.swift`
- Modify: `docs/functional.md` §4, `docs/manual-test-checklist.md` §3, `docs/README.md`, `README.md`,
  `CHANGELOG.md`, `scripts/dmg-background.swift`

**Interfaces:**
- Consumes: `LoginSession.userIsAdministrator` (Task 4).
- Produces: `OnboardingStrings.doneBodyNotAdministrator`; the pitch's three sentences changed.

The headline's accent is found case-insensitively and only its first occurrence is drawn in the icon's
colour, so the accent word appears once in the headline.

- [ ] **Step 1: The failing test.** In `Tests/SherlockMeCoreTests/LocalizationTests.swift`, replace

```swift
                     ("onboarding.doneBody", onboarding.doneBody),
```

with

```swift
                     ("onboarding.doneBody", onboarding.doneBody),
                     ("onboarding.doneBodyNotAdministrator", onboarding.doneBodyNotAdministrator),
```

- [ ] **Step 2: Run it and see it fail**

Run: `swift test --filter LocalizationTests`
Expected: a build failure, `value of type 'OnboardingStrings' has no member 'doneBodyNotAdministrator'`.

- [ ] **Step 3: The words.** Replace `Sources/SherlockMeCore/StringsOnboarding.swift` with the file below.
  Against the template's, it changes the header's last paragraph, the pitch's headline, accent and body,
  and adds `doneBodyNotAdministrator`; everything else is as it was.

```swift
import Foundation

/// The onboarding wizard's three pages: the pitch, where the app lives, and "All set".
///
/// The window's own title is the app's name and is not a sentence, so it is not here.
///
/// SherlockMe asks for no permission, so no page stands between the pitch and where it lives. The last page
/// has a second body for an account that cannot read the log.
public struct OnboardingStrings {
    private let language: Language
    init(_ language: Language) { self.language = language }

    // MARK: The pitch

    public var pitchHeadline: String {
        switch language {
        case .en: "Locked, and it stays locked."
        case .fr: "Verrouillé, et il le reste."
        }
    }

    /// The one word of the headline drawn in the app's colour. Localized on its own, so the French accents
    /// its own word and not a fragment of another.
    public var pitchAccent: String {
        switch language {
        case .en: "stays"
        case .fr: "reste"
        }
    }

    public var pitchBody: String {
        switch language {
        case .en: "Clicking the Touch ID key locks your Mac, and the finger still on the key unlocks it a "
            + "second later. \(AppIdentity.name) locks the moment the key goes down, and locks again if that "
            + "finger gets in anyway."
        case .fr: "Un clic sur la touche Touch ID verrouille votre Mac, et le doigt encore posé dessus le "
            + "déverrouille une seconde plus tard. \(AppIdentity.name) verrouille dès que la touche s'enfonce, "
            + "et reverrouille si ce doigt passe quand même."
        }
    }

    public var pitchMenuBarPill: String {
        switch language {
        case .en: "Menu bar"
        case .fr: "Barre des menus"
        }
    }

    public var pitchPrivatePill: String {
        switch language {
        case .en: "Nothing leaves your Mac"
        case .fr: "Rien ne quitte votre Mac"
        }
    }

    /// The tooltip and the accessibility description of the mark beside a row the app cannot work without.
    public var requiredMark: String {
        switch language {
        case .en: "Required"
        case .fr: "Requis"
        }
    }

    // MARK: Where it lives

    public var homeHeader: String {
        switch language {
        case .en: "Where it lives"
        case .fr: "Où il se trouve"
        }
    }

    public var homeIntro: String {
        switch language {
        case .en: "Neither of these is required. \(AppIdentity.name) has no window of its own and no "
            + "icon in the Dock: it waits in the menu bar. Both can be changed later in Settings."
        case .fr: "Facultatif. \(AppIdentity.name) n'a pas de fenêtre à lui ni d'icône dans le Dock : "
            + "il attend dans la barre des menus. Ces deux réglages sont modifiables plus tard dans les "
            + "réglages."
        }
    }

    /// **Exactly what the Login Items and Extensions pane calls the list the app appears in**, quoted from
    /// `LoginItems.appex`'s own strings.
    public var openAtLoginTitle: String {
        switch language {
        case .en: "Open at Login"
        case .fr: "Ouvrir avec la session"
        }
    }

    public var openAtLoginWhy: String {
        switch language {
        case .en: "Starts \(AppIdentity.name) when you log in, so it is there without opening anything. "
            + "It starts with no window."
        case .fr: "Lance \(AppIdentity.name) à l'ouverture de votre session, pour qu'il soit là sans rien "
            + "ouvrir. Il démarre sans fenêtre."
        }
    }

    public var menuBarWhy: String {
        switch language {
        case .en: "Its menu holds the way back to these settings. Hidden, \(AppIdentity.name) keeps "
            + "working: open it again from the Applications folder to get the window back."
        case .fr: "Son menu contient le chemin de retour vers ces réglages. Masquée, \(AppIdentity.name) "
            + "continue de fonctionner : rouvrez-le depuis le dossier Applications pour revenir à la fenêtre."
        }
    }

    public var turnOnButton: String {
        switch language {
        case .en: "Turn On"
        case .fr: "Activer"
        }
    }

    public var turnOffButton: String {
        switch language {
        case .en: "Turn Off"
        case .fr: "Désactiver"
        }
    }

    // MARK: All set

    public var doneHeadline: String {
        switch language {
        case .en: "All set"
        case .fr: "Tout est prêt"
        }
    }

    public var doneBody: String {
        switch language {
        case .en: "Look for \(AppIdentity.name) in the menu bar, at the top right, whenever you want to "
            + "change something."
        case .fr: "Retrouvez \(AppIdentity.name) dans la barre des menus, en haut à droite, pour changer "
            + "un réglage."
        }
    }

    /// The last page on an account that is not an administrator, where SherlockMe cannot read the log.
    public var doneBodyNotAdministrator: String {
        switch language {
        case .en: "This account is not an administrator, so \(AppIdentity.name) cannot see the Touch ID key "
            + "here, and the key locks the Mac the way macOS does. Look for \(AppIdentity.name) in the menu "
            + "bar, at the top right."
        case .fr: "Ce compte n'est pas administrateur : \(AppIdentity.name) ne peut pas voir la touche Touch ID "
            + "ici, et la touche verrouille le Mac comme le fait macOS. Retrouvez \(AppIdentity.name) dans la "
            + "barre des menus, en haut à droite."
        }
    }

    // MARK: The stepping button

    public var continueButton: String {
        switch language {
        case .en: "Continue"
        case .fr: "Continuer"
        }
    }

    /// What the stepping button reads until the page's own rule is met.
    public var skipButton: String {
        switch language {
        case .en: "Skip"
        case .fr: "Passer"
        }
    }

    public var finishButton: String {
        switch language {
        case .en: "Finish"
        case .fr: "Terminer"
        }
    }
}
```

- [ ] **Step 4: The wizard's last page.** In `Sources/SherlockMeApp/OnboardingWindow.swift`, replace

```swift
    /// TEMPLATE: an app that needs a permission puts a list page between the first two, `.list(header:
    /// words.permissionHeader, intro: words.permissionIntro, items: GrantCatalogue.permissions, advanceWhen:
    /// everyRequiredGrant, height: OnboardingMetrics.shortListHeight)`, and its pitch page names what the app
    /// does. The list page here carries two rows, so it takes the short height.
```

with

```swift
    /// SherlockMe asks for no permission, so no list page stands between the first two; on an account that
    /// cannot read the log, the last page says so. The list page here carries two rows, so it takes the short
    /// height.
```

and replace

```swift
            .final(title: words.doneHeadline, body: words.doneBody, button: words.finishButton),
```

with

```swift
            .final(title: words.doneHeadline,
                   body: LoginSession.userIsAdministrator ? words.doneBody : words.doneBodyNotAdministrator,
                   button: words.finishButton),
```

- [ ] **Step 5: Run it and see it pass**

Run: `swift test --filter LocalizationTests`
Expected: `Executed 6 tests, with 0 failures`.

- [ ] **Step 6: The disk image's line.** In `scripts/dmg-background.swift`, replace

```swift
// TEMPLATE: the one line under the app's name on the disk image.
let description = arguments.count >= 6 ? arguments[5] : "A small menu-bar app for your Mac"
```

with

```swift
// The one line under the app's name on the disk image.
let description = arguments.count >= 6 ? arguments[5] : "Locked, and it stays locked."
```

- [ ] **Step 7: `docs/functional.md` §4.** Replace

```markdown
| 3 | **All set**: where the menu-bar item is | Finish |
```

with

```markdown
| 3 | **All set**: where the menu-bar item is; on an account that is not an administrator, first that SherlockMe cannot see the Touch ID key there and that the key locks the Mac the way macOS does | Finish |
```

and replace

```markdown
TEMPLATE: an app that needs a permission puts a **Permission** page between 1 and 2, one row per grant,
titled exactly what System Settings calls the switch, marked required when the app cannot work without it;
its button reads *Skip* until every required grant is there.
```

with

```markdown
SherlockMe asks for no permission, so there is no **Permission** page.
```

- [ ] **Step 8: `docs/manual-test-checklist.md` §3.** Replace

```markdown
- [ ] The pitch page: the icon, the headline with *well* in the icon's colour, the two capsules. Nothing is
      cut off, nothing is truncated, every sentence wraps. TEMPLATE: the permission page, if there is one,
      by the shared checklist's *The permission* section.
```

with

```markdown
- [ ] The pitch page: the icon, the headline with *stays* (*reste*) in the icon's colour, the two capsules.
      Nothing is cut off, nothing is truncated, every sentence wraps. There is no permission page.
- [ ] On an account that is not an administrator (a standard account made for the test), the last page says
      SherlockMe cannot see the Touch ID key there; Health is red, and the menu line says why.
```

- [ ] **Step 9: `docs/README.md`.** Replace

```markdown
TEMPLATE: one line saying what the app is. Swift, SwiftPM, no Xcode project.
```

with

```markdown
SherlockMe locks the Mac the instant the Touch ID key is clicked, and locks it again when the finger still on
the key unlocks it. Swift, SwiftPM, no Xcode project.
```

- [ ] **Step 10: `README.md`.** Replace

```markdown
  <strong>TEMPLATE: one sentence saying what the app does for the person reading this.</strong><br>
  TEMPLATE: two or three lines on the problem it solves, and that it does nothing else.
```

with

```markdown
  <strong>Click the Touch ID key, and your Mac locks, and stays locked.</strong><br>
  macOS locks when the key is clicked, and the finger still resting on it unlocks the Mac a second later.
  SherlockMe locks the instant the key goes down and catches that unlock. It does nothing else.
```

replace

```markdown
TEMPLATE: a table of *You do* / *What happens*, then the rules a user would want to know, in plain words.
```

with

```markdown
| You do | What happens |
|---|---|
| Click the Touch ID key | The Mac locks the instant the key goes down |
| Leave your finger on the key after the click | If the lock screen unlocks with it, SherlockMe locks the Mac again half a second later, once |
| Touch the sensor on the lock screen, click the key there, or type your password | The Mac unlocks, and stays unlocked |

- There is nothing to set up and nothing to choose, and SherlockMe asks for no permission.
- It needs an **administrator account**: it watches the key through the Mac's own log, which only an
  administrator can read. On any other account it does nothing, and says so.
- When SherlockMe is not running, the key works exactly as macOS makes it.
```

replace

```markdown
A three-page window, opened from the menu-bar item (⌘,) or by opening the app again, which is the way in
when the icon is hidden. Every change applies as you make it.

| Page | What is on it |
|---|---|
| **General** | Launch at login · Show in menu bar · Updates · Quit · Uninstall |
| **System** | the way back to the welcome wizard |
| **Tip** | everything is free and stays free · a one-time tip on Ko-fi |

The menu-bar item carries Launch at Login, Settings and Quit.
```

with

```markdown
A four-page window, opened from the menu-bar item (⌘,) or by opening the app again, which is the way in
when the icon is hidden. Every change applies as you make it. There is nothing to set about the Touch ID key
itself.

| Page | What is on it |
|---|---|
| **General** | Launch at login · Show in menu bar · Updates · Quit · Uninstall |
| **System** | the way back to the welcome wizard |
| **Health** | whether SherlockMe is watching the Touch ID key, when it last locked the Mac and last caught an unlock |
| **Tip** | everything is free and stays free · a one-time tip on Ko-fi |

The menu-bar item carries Launch at Login, what SherlockMe is doing, Settings and Quit.
```

and replace

```markdown
- **macOS 26 or later**, and a Swift toolchain to build it.
- **No permission.** The only thing the app ever sends over the network is its own update check.
```

with

```markdown
- **macOS 26 or later**, and a Swift toolchain to build it.
- **A Touch ID key**: built into the Mac, or on a Magic Keyboard with Touch ID.
- **An administrator account.** SherlockMe watches the key through the Mac's own log, which only an
  administrator can read. On any other account it does nothing and says so.
- **No permission.** The only thing the app ever sends over the network is its own update check.
```

- [ ] **Step 11: `CHANGELOG.md`.** Replace

```markdown
- TEMPLATE: the feature, in the words a user would use.
- A menu-bar item with Launch at Login, Settings and Quit. A three-page Settings window: General, System,
  Tip.
```

with

```markdown
- **The Touch ID key locks, and the Mac stays locked.** A click on the key locks the Mac the instant it goes
  down, and when the finger still on the key unlocks it, SherlockMe locks it again half a second later, once.
  An unlock you make on purpose is never undone. It needs an administrator account and asks for no
  permission.
- A menu-bar item with Launch at Login, what SherlockMe is doing, Settings and Quit. A four-page Settings
  window: General, System, Health, Tip.
```

- [ ] **Step 12: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 107, Platform 19, both passed.

- [ ] **Step 13: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/StringsOnboarding.swift Sources/SherlockMeApp/OnboardingWindow.swift \
        Tests/SherlockMeCoreTests/LocalizationTests.swift scripts/dmg-background.swift docs/functional.md \
        docs/manual-test-checklist.md docs/README.md README.md CHANGELOG.md
git commit -m "feat: the wizard, the README and the changelog say what SherlockMe does" \
           -m "<attribution trailers>"
```

---

### Task 8: The last placeholders, and the documents that record the build

**Model:** sonnet. **Reviewer:** opus (every document against the code at this commit).

**Files:**
- Modify: `Sources/SherlockMeCore/Settings.swift`, `Tests/SherlockMeCoreTests/SettingsTests.swift`,
  `Sources/SherlockMeApp/SettingsView.swift`, `Sources/SherlockMeApp/SettingsSystemPage.swift`,
  `Sources/SherlockMeCore/StringsSystemPage.swift`, `Sources/SherlockMeCore/StringsGeneralPage.swift`,
  `Sources/SherlockMeCore/StringsSettings.swift`, `Sources/SherlockMeApp/GrantCatalogue.swift`,
  `Sources/SherlockMePlatform/Uninstall.swift`, `Package.swift`
- Modify: `docs/macOS.md`, `docs/pitfalls.md`, `docs/manual-test-checklist.md` §1, `CLAUDE.md` (*Traps*,
  *Status*), `docs/superpowers/specs/2026-09-23-sherlockme-core-design.md`

**Interfaces:** none: comments and documents only.

- [ ] **Step 1: The placeholders that assume a setting, a feature page or a permission SherlockMe does not
  have.** Make each replacement exactly:

1. `Sources/SherlockMeCore/Settings.swift`: replace

```swift
/// TEMPLATE: a user-facing setting is a stored property here and a control in the Settings window; every
/// other number is a `static let` in `Constants.swift`, deliberately not reachable by `defaults write`.
/// `SettingsTests` pins the roster.
```

with

```swift
/// SherlockMe has no setting of its own (`docs/functional.md` §1): the switches here are the family's. A
/// user-facing setting would be a stored property here and a control in the Settings window; every other
/// number is a `static let` in `Constants.swift`, deliberately not reachable by `defaults write`.
/// `SettingsTests` pins the roster.
```

2. `Tests/SherlockMeCoreTests/SettingsTests.swift`: replace

```swift
/// from resetting the rest. TEMPLATE: every stored property the app adds gets a line in each test below.
```

with

```swift
/// from resetting the rest. Every stored property gets a line in each test below.
```

3. `Sources/SherlockMeApp/SettingsView.swift`: replace

```swift
/// system, then its health, then the tip jar last. TEMPLATE: a feature page goes between `general` and
/// `system`, with its title and symbol below and its `Settings<Feature>Page.swift` beside the others.
```

with

```swift
/// system, then its health, then the tip jar last. SherlockMe has no setting of its own, so it has no
/// feature page; one would go between `general` and `system`.
```

and replace

```swift
    @Published private(set) var loginItem: LoginItemState
    // TEMPLATE: `@Published private(set) var accessibilityGranted: Bool`, read in `refresh()` with the
    // permission's reader and never its ask, for an app that needs a permission.
```

with

```swift
    @Published private(set) var loginItem: LoginItemState
```

4. `Sources/SherlockMeApp/SettingsSystemPage.swift`: replace

```swift
/// What the app needs from macOS, and whether it has it. This app needs nothing yet, so the page holds only
/// the way back to the wizard.
///
/// TEMPLATE: a permission is one group here, and a state the user can fix is three things: the row
/// (`StatusRow`, green *Granted* or red *Denied*); while it is denied, a `ButtonRow` to the pane it is fixed
/// in and a warning naming the exact switch; once granted, the button and the warning go and the row stays,
/// so the link between the app and the permission stays visible. `status` follows the system while the
/// window is open. The `macos-building-settings-pages` skill has the rest.
```

with

```swift
/// What the app needs from macOS, and whether it has it. SherlockMe asks for no permission, so the page holds
/// only the way back to the wizard. An account that cannot read the log is not here either: nothing in the
/// app can change that, and a state with nothing to press beside it goes on Health (the
/// `macos-building-settings-pages` skill).
```

5. `Sources/SherlockMeCore/StringsSystemPage.swift`: replace

```swift
/// The System page: what the app needs from macOS, and whether it has it.
///
/// TEMPLATE: a permission's group is a title, a hint saying what the app does with it, a note reassuring
/// about what never leaves the Mac, a warning quoting the switch **as the Privacy and Security pane names
/// it** (read it again with `plutil -extract fr xml1` after a macOS release), the row's own name, and the
/// button that opens the pane.
```

with

```swift
/// The System page: what the app needs from macOS, and whether it has it. SherlockMe asks for no permission,
/// so the page holds only Start over.
```

6. `Sources/SherlockMeCore/StringsGeneralPage.swift`: replace

```swift
    // MARK: Uninstall

    // TEMPLATE: an app that was granted a permission says so in the hint, the warning and the confirmation:
    // "Gives back the Accessibility permission, removes the entry in Login Items, and …", and adds the
    // sentence shown when giving it back failed.

    public var uninstallTitle: String {
```

with

```swift
    // MARK: Uninstall

    public var uninstallTitle: String {
```

7. `Sources/SherlockMeCore/StringsSettings.swift`: replace

```swift
/// per page. TEMPLATE: a feature page adds its title here and its own `Strings<Feature>Page.swift`.
```

with

```swift
/// per page.
```

8. `Sources/SherlockMeApp/GrantCatalogue.swift`: replace

```swift
    case openAtLogin, menuBarIcon
    // TEMPLATE: one case per permission the app needs, for instance `accessibility`.
```

with

```swift
    case openAtLogin, menuBarIcon
```

and replace

```swift
enum GrantCatalogue {
    // TEMPLATE: an app that needs a permission adds a `permissions` list here, one `GrantItem` per grant,
    // required when the app cannot work without it, `mayOpen: systemSettings` on every one of them, and
    // a list page for it in `OnboardingWindowController.make`. The `macos-building-onboarding` skill names
    // the reader and the ask for each grant, and where the row's sentences go.

```

with

```swift
enum GrantCatalogue {
```

9. `Sources/SherlockMePlatform/Uninstall.swift`: replace

```swift
    case storedState
    // TEMPLATE: one case per system registration the app makes and must give back, for instance a
    // `permissionGrant` reset with `tccutil`, or a launch agent booted out.
}
```

with

```swift
    case storedState
}
```

and replace

```swift
    ///
    /// TEMPLATE: a permission the app was granted is given back here first, with
    /// `run("/usr/bin/tccutil", ["reset", "<Service>", bundleIdentifier])`; it exits non-zero when it had
    /// nothing to reset as well as when it failed, so the sentence the user reads names where to look
    /// either way.
```

with

```swift
    ///
    /// SherlockMe is granted no permission: the login item and the notification authorization are all it
    /// registers.
```

10. `Package.swift`: replace

```swift
// TEMPLATE: the four names SwiftPM cannot read from scripts/signing.env are the target names below and the
// directories under Sources/ and Tests/ they point at. scripts/new-app.sh renames all of them together.
```

with

```swift
// The four names SwiftPM cannot read from scripts/signing.env are the target names below and the
// directories under Sources/ and Tests/ they point at: a rename changes them with that file, and
// scripts/new-app.sh in ~/Projects/macos-app-template does all of it at once.
```

- [ ] **Step 2: What is left**

Run: `rg -n 'TEMPLATE:' --glob '!docs/shared/**' --glob '!.build/**' .`
Expected: exactly the icon's two, which wait for the icon: `Sources/SherlockMeApp/MenuBarController.swift`
(the placeholder mark) and `Sources/SherlockMeApp/OnboardingWindow.swift` (the brand colour), plus the
lines of `docs/manual-test-checklist.md` §1 that Step 5 replaces, if Step 5 is not done yet.

- [ ] **Step 3: `docs/macOS.md`.** Replace

```markdown
Not measured yet: the built-in button's timeline (every run used the Magic Keyboard, the lid closed),
whether an event tap sees the subtype-16 event of either keyboard, and whether loginwindow's own lock,
arriving on a Mac SherlockMe has already locked, changes anything (the design's first open question).

TEMPLATE: the APIs the feature calls, what each one answers, and what was measured on which macOS. Every
API named here has a call site in `Sources/`.
```

with

```markdown
Not measured yet, and what the app does meanwhile:

- **The built-in button's timeline**: every run used the Magic Keyboard, the lid closed. If its press does
  not reach biometrickitd's key line, SherlockMe follows the press from loginwindow's own lock on it: the
  relock still works, and the lock is macOS's own, 0.31 s after the key.
- **loginwindow's own lock arriving on a Mac SherlockMe has already locked.** Read from loginwindow, not
  measured: its handler declines while the shield is up, and SherlockMe's lock, 0.09 to 0.14 s after the
  key, is in place before loginwindow hears of the key at 0.31 s. SherlockMe takes no hold, so nothing stops
  loginwindow either way; `docs/manual-test-checklist.md` §1 is where it is looked at.
- Whether an event tap sees the subtype-16 event of either keyboard. SherlockMe has no event tap.

## What the app calls

| Call | Where | What it answers |
|---|---|---|
| `/usr/bin/log stream --style ndjson --predicate …` | `TouchIDLogStream` | one JSON line per entry that matches `TouchIDLog.predicate`, until it is stopped; started only on an administrator account |
| `SACLockScreenImmediate()`, login.framework, through `dlsym` | `SessionAgent.lockScreen` | an `int32`, 0 on success; the screen locked 0.09 to 0.14 s after the key's line when called on it (macOS 27.0, 26A428) |
| `CGSessionCopyCurrentDictionary()`, `CGSSessionScreenIsLocked` | `LoginSession.screenIsLocked` | whether the screen is locked; read each time a stream starts |
| `CBUserIdentity.isMember(ofGroup:)` against the `admin` group (80) | `LoginSession.userIsAdministrator` | whether the account may read the log; the functions of `<membership.h>` are not visible to Swift |
```

- [ ] **Step 4: `docs/pitfalls.md`, entry 10.** Replace

```markdown
- **What holds.** Until the design's first open question is answered, the hold is given back on every way
  out, and SherlockMe locks on loginwindow's "declined because of a hold" line when it has not locked for
  that press. A crash still leaves the key not locking for up to 60 s.
```

with

```markdown
- **What holds.** SherlockMe takes no hold: its own lock comes 0.09 to 0.14 s after the key, before
  loginwindow hears of the key at 0.31 s, so there is nothing to stop, and a crash leaves the key as macOS
  makes it.
- **Rule.** A hold comes back only with a measurement that SherlockMe's lock alone is not enough, and then
  with a way to give it back that survives a crash.
```

- [ ] **Step 5: `docs/manual-test-checklist.md` §1.** Replace

```markdown
TEMPLATE: one line per thing to do and what to expect, as `- [ ]` items.
```

with

```markdown
**Every item locks the Mac: the owner at the keyboard, and nobody else.** Keep
`/usr/bin/log stream --predicate 'subsystem == "dev.rubens.SherlockMe" AND category == "touchid"'` open in a
Terminal: it says what SherlockMe decided at each press.

- [ ] The menu's status line reads *Watching the Touch ID key*.
- [ ] Click the Touch ID key and lift the finger: the Mac locks at once, and stays locked.
- [ ] Click it and leave the finger on the key: the Mac locks, may show the desktop for about half a second,
      then locks again and stays locked until you unlock it. The log says "locked again".
- [ ] Unlock with a touch once the lock screen is up: it stays unlocked. The log says "unlock left alone".
- [ ] Click the key on the lock screen to unlock: it stays unlocked.
- [ ] Unlock with the password: it stays unlocked.
- [ ] Click the key within 3 s of unlocking: it locks (macOS alone ignores such a press).
- [ ] With the lid open, the same presses on the built-in button. If the log says "macOS locked on a press
      whose key line was not read", its press does not reach biometrickitd's key line: write it in
      `docs/macOS.md`.
- [ ] At every press, nothing odd when loginwindow's own lock arrives after SherlockMe's: no second lock
      screen, no flash, the login box there. Anything seen goes in `docs/pitfalls.md`.
- [ ] Quit SherlockMe: `pgrep -lf 'log stream --style ndjson'` lists nothing of SherlockMe's, and a click with
      the finger left on the key locks and unlocks again, as macOS does alone.
```

- [ ] **Step 6: `CLAUDE.md`.** Replace

```markdown
`docs/shared/pitfalls.md` is the family's list and `docs/pitfalls.md` this app's own, with the measurements.
TEMPLATE: the five or six that cost the most, one line each, once the app has some.
```

with

```markdown
`docs/shared/pitfalls.md` is the family's list and `docs/pitfalls.md` this app's own, with the measurements.
The six that cost the most:

- A lock that waits for the key to come up does not stop a resting finger, and neither does putting the
  displays to sleep first (pitfalls 1, 2).
- `bioutil` wants the user's password, and switching Touch ID for unlock off and on again makes macOS demand
  it at the next unlock (pitfalls 3, 4).
- Relocking at once leaves a lock screen with no login box; 0.5 s is the owner's number (pitfalls 5).
- A relock decided by time alone undoes a deliberate unlock: each condition of the rule is what keeps it
  from doing so (pitfalls 6).
- `DisableScreenLockImmediate` stops every immediate lock, SherlockMe's included, and outlives the app
  (pitfalls 7).
- A Touch ID hold outlives the process that took it, for up to 60 s (pitfalls 10).
```

and replace everything from `Known limitations, in plain words:` to the end of the file with:

```markdown
Known limitations, in plain words:

- **Nothing is published**, so every update check answers *No release published yet* until the repository is
  public and carries a release.
- **The feature has not been walked on hardware.** It was built while the owner was away, and not installed.
  `docs/manual-test-checklist.md` §1 is the walk, with the built-in button (every measurement used the Magic
  Keyboard, the lid closed) and loginwindow's own lock arriving after SherlockMe's.
- **The replay of the owner's recorded presses** (`Tools/touchprobe/fixtures/`) through the rule is written
  in the build plan, `docs/superpowers/plans/2026-09-23-sherlockme-core.md` Task H, and not in the tree yet.
- The icon is the template's placeholder (`Resources/ICON-NOTES.md`).
```

- [ ] **Step 7: The design records what the build decided.** In
  `docs/superpowers/specs/2026-09-23-sherlockme-core-design.md`, replace

```markdown
hardware. The mechanism was approved by the owner; this document waits for the owner's review before the
build plan is written. The platform facts it rests on are in `docs/macOS.md`; the approaches that were
tried and fail are in `docs/pitfalls.md`, with their measurements. **Read both before changing anything
here.**
```

with

```markdown
hardware. The owner approved the mechanism and this document; the build followed
`docs/superpowers/plans/2026-09-23-sherlockme-core.md`, and the last section here is what it decided. Since
the build, **`docs/functional.md` is the authority on behaviour**. The platform facts it rests on are in
`docs/macOS.md`; the approaches that were tried and fail are in `docs/pitfalls.md`, with their
measurements. **Read both before changing anything here.**
```

and append at the end of the file:

```markdown

## What the build decided

The owner approved this document and asked for the build to run to its end without questions, so the four
open questions were answered without a new measurement. Each answer is reversible.

1. **No hold.** SherlockMe's lock lands 0.09 to 0.14 s after the key goes down, before loginwindow hears of
   the key at 0.31 s, and loginwindow's handler declines while the shield is up (read from loginwindow, not
   measured with SherlockMe running). Without the hold there is no crash window: SherlockMe gone is macOS's
   own behaviour at once. `docs/manual-test-checklist.md` §1 looks at loginwindow's own lock arriving second.
2. **The built-in button** is not measured. The rule also follows a press known only from loginwindow's own
   lock on it (`handleSystemEvent:` … `calling to lock screen immediate`), so a keyboard whose press never
   reaches biometrickitd's key line still gets the relock; only the instant lock is then macOS's.
3. **No launch agent.** Without the hold a crash costs the protection and nothing else; the family's login
   item starts SherlockMe at login, and the Health page shows the crash.
4. **An account that is not an administrator**: nothing is started, and the menu's line, the Health page and
   the wizard's last page say so. Not the System page: it holds only what has a button beside it, and nothing
   in the app can make an account an administrator.

Two things differ in shape from the sections above: the Health page has one check, *Watching the Touch ID
key*, whatever stops it (one cause, one line), and its readings are the last lock and the last unlock caught.
The replay of the owner's recorded presses is written and held for the owner (the plan's Task H).
```

- [ ] **Step 8: Verify the whole tree**

Run: `swift build 2>&1 | grep -E 'warning|error' ; swift test 2>&1 | grep -E -A1 "xctest' (passed|failed)"`
Expected: no warning; Core 107, Platform 19, both passed. Then
`rg -n 'TEMPLATE:' --glob '!docs/shared/**' --glob '!.build/**' .` prints the icon's two lines only, and
`sh ~/Projects/macos-app-template/scripts/sync-shared-docs.sh --check` reports no drift for sherlock-me.

- [ ] **Step 9: Commit** (the controller, after review)

```bash
git add Sources/SherlockMeCore/Settings.swift Tests/SherlockMeCoreTests/SettingsTests.swift \
        Sources/SherlockMeApp/SettingsView.swift Sources/SherlockMeApp/SettingsSystemPage.swift \
        Sources/SherlockMeCore/StringsSystemPage.swift Sources/SherlockMeCore/StringsGeneralPage.swift \
        Sources/SherlockMeCore/StringsSettings.swift Sources/SherlockMeApp/GrantCatalogue.swift \
        Sources/SherlockMePlatform/Uninstall.swift Package.swift docs/macOS.md docs/pitfalls.md \
        docs/manual-test-checklist.md CLAUDE.md docs/superpowers/specs/2026-09-23-sherlockme-core-design.md
git commit -m "docs: the placeholders filled, and what the build decided" -m "<attribution trailers>"
```

---

### Task H: Replay the owner's recordings (held for the owner)

**Not executed by the build.** Running this replay was refused in the session that wrote the plan; the
owner runs it, or asks for it to be run. It is written out so that it is ready.

The design's test: the owner's own presses, `Tools/touchprobe/fixtures/*.ndjson` (time, process, message),
played through the rule. Its expectations are the design's: each morning bug gives one relock; run 9 gives
its ten relocks and none of its deliberate unlocks. **If one fails, report it to the owner; never change an
expected value to match the rule.**

- [ ] **Step 1:** create `Tests/SherlockMeCoreTests/LockRuleReplayTests.swift`:

```swift
import XCTest
import SherlockMeCore

/// The owner's own presses, recorded with `Tools/touchprobe` and kept in `Tools/touchprobe/fixtures/`, played
/// through the rule with the times they were logged. The design says what each recording must give.
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
```

- [ ] **Step 2:** `swift test --filter LockRuleReplayTests`: 3 tests, 0 failures expected.
- [ ] **Step 3:** commit it, `test(core): the owner's recorded presses, replayed through the rule`, and
  remove the replay's line from `CLAUDE.md` *Status*.

---

## After Task 8 (the controller)

- [ ] Whole-branch review by `fable-xhigh-reviewer`, from the first commit to the last, against this plan,
  the spec and `functional.md` §0.
- [ ] Fix what it finds, each fix reviewed and committed like a task.
- [ ] The final report for the owner: what was built, the commits, the test counts, *Decisions made without
  the owner* one by one, what was not done (Task H, the icon, the walk of `manual-test-checklist.md` §1 with
  the owner at the keyboard, `make install`), and why each was not.
