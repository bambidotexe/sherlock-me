// The Touch ID probe: a developer tool for designing SherlockMe, never put in the bundle
// (scripts/make-app.sh copies one executable, and this is not it).
//
// It prints what happens around each press of a Touch ID key, the built-in one or a Magic Keyboard's,
// read off the unified log: the key going down and up, loginwindow locking or declining to, the lock
// screen starting to read the sensor, the finger arriving and leaving, the match, the screen locking and
// unlocking. An administrator account reads the log without sudo. It creates no event tap and asks for
// no permission.
//
//   touchprobe watch      [--seconds 90]
//       changes nothing.
//   touchprobe hold       [--seconds 90] [--then immediate|sleep|none] [--delay-ms 600]
//       takes loginwindow's own "a Touch ID press must not lock" hold, so the key no longer locks, and
//       locks the Mac itself --delay-ms after the key comes up: `immediate` locks at once, `sleep` puts
//       the displays to sleep and then locks, `none` does not lock (the hold alone). The hold is given
//       back while the screen is locked, so the lock screen behaves as macOS makes it.
//   touchprobe sleepfirst [--seconds 90]
//       no hold: puts the displays to sleep the moment the key goes down, and macOS locks as it does.
//   touchprobe relock     [--seconds 90] [--relock-after-ms 0]
//       takes the same hold and locks the Mac the moment the key goes down; when the lock screen then
//       unlocks with a finger that was already on the sensor as it started reading (seen within 0.5 s),
//       locks it again --relock-after-ms later, once a press; a press on the lock screen cancels it.
//   touchprobe sleeponly  [--seconds 90] [--at down|up] [--delay-ms 150]
//       takes the same hold and only puts the displays to sleep, when the key goes down or --delay-ms
//       after it comes up; with "require password" set to immediately, the displays going to sleep is
//       the lock, and the lock screen waits for the user before it starts.
//   touchprobe touchid    [--seconds 90] [--on-after-ms 2000]
//       takes the same hold; the moment the key goes down it switches Touch ID for unlock off for the whole
//       Mac with /usr/bin/bioutil (as root, through sudo -n and /etc/sudoers.d/sherlockme), locks the Mac,
//       and switches it back on --on-after-ms later. It runs only while the rule is there and Touch ID for
//       unlock is on, and switches it back on before it ends.
//   touchprobe replay --start "YYYY-MM-DD HH:MM:SS" --end "YYYY-MM-DD HH:MM:SS"
//       the same timeline, read from the stored log.
//
// Every live run ends by itself after --seconds, giving the hold back first. A hold left behind by a
// probe that was killed expires in loginwindow after 60 s (`touchIDBlockScreenLockAssertionTimeout`); a
// `touchid` probe killed with Touch ID off leaves it off until `sudo bioutil -w -s -u 1`.

import CoreGraphics
import Foundation

// MARK: - Options

enum Mode: String { case watch, hold, relock, sleepfirst, sleeponly, touchid, replay }
enum Then: String { case immediate, sleep, none }
enum At: String { case down, up }

struct Options {
    var mode = Mode.watch
    var seconds = 90.0
    var then = Then.immediate
    var at = At.up
    var delayMs = 600
    var onAfterMs = 2000
    var relockAfterMs = 0
    var start: String?
    var end: String?
}

func usage() -> Never {
    FileHandle.standardError.write(Data("""
        usage: touchprobe watch      [--seconds 90]
               touchprobe hold       [--seconds 90] [--then immediate|sleep|none] [--delay-ms 600]
               touchprobe sleepfirst [--seconds 90]
               touchprobe relock     [--seconds 90] [--relock-after-ms 0]
               touchprobe sleeponly  [--seconds 90] [--at down|up] [--delay-ms 150]
               touchprobe touchid    [--seconds 90] [--on-after-ms 2000]
               touchprobe replay     --start "YYYY-MM-DD HH:MM:SS" --end "YYYY-MM-DD HH:MM:SS"

        """.utf8))
    exit(2)
}

func parseOptions() -> Options {
    var args = Array(CommandLine.arguments.dropFirst())
    guard let first = args.first, let mode = Mode(rawValue: first) else { usage() }
    args.removeFirst()
    var options = Options()
    options.mode = mode
    while !args.isEmpty {
        let flag = args.removeFirst()
        guard !args.isEmpty else { usage() }
        let value = args.removeFirst()
        switch flag {
        case "--seconds":
            guard let v = Double(value), v > 0, v <= 600 else { usage() }
            options.seconds = v
        case "--then":
            guard let v = Then(rawValue: value) else { usage() }
            options.then = v
        case "--at":
            guard let v = At(rawValue: value) else { usage() }
            options.at = v
        case "--delay-ms":
            guard let v = Int(value), v >= 0, v <= 10_000 else { usage() }
            options.delayMs = v
        case "--on-after-ms":
            guard let v = Int(value), v >= 0, v <= 30_000 else { usage() }
            options.onAfterMs = v
        case "--relock-after-ms":
            guard let v = Int(value), v >= 0, v <= 5_000 else { usage() }
            options.relockAfterMs = v
        case "--start": options.start = value
        case "--end": options.end = value
        default: usage()
        }
    }
    if mode == .replay, options.start == nil || options.end == nil { usage() }
    return options
}

// MARK: - What the log says

enum Kind: String {
    case keyDown = "key down"
    case keyUp = "key up"
    case macLocks = "loginwindow locks"
    case macHeld = "loginwindow does not lock: a hold is active"
    case macDebounce = "loginwindow does not lock: just unlocked"
    case macPref = "loginwindow does not lock: DisableScreenLockImmediate"
    case locked = "screen locked"
    case lockReason = "lock reason"
    case unlockUI = "lock screen comes up"
    case readStart = "sensor read starts"
    case fingerOn = "finger on"
    case fingerOff = "finger off"
    case match = "MATCH"
    case noMatch = "no match"
    case unlocked = "screen UNLOCKED"
    case touchIDActive = "lock screen: Touch ID active"
    case touchIDInactive = "lock screen: Touch ID inactive"
    case passwordToEnable = "loginwindow: password required to enable Touch ID"
    case probeUnlockOff = "probe: Touch ID for unlock OFF"
    case probeUnlockOn = "probe: Touch ID for unlock ON"
    case probeHold = "probe: hold taken"
    case probeRelease = "probe: hold given back"
    case probeSleep = "probe: displays to sleep"
    case probeLock = "probe: lock"
    case probeRelock = "probe: RELOCK, a resting finger got in"
}

/// The lines this probe reads, as measured on macOS 27 (26A428). biometrickitd reports the key and the
/// sensor for the built-in button and the Magic Keyboard alike; the finger's status codes (63 on, 64 off)
/// are only reported while something is reading the sensor.
let predicate = """
    (process == "biometrickitd" AND (eventMessage BEGINSWITH "touchIDButtonPressed" \
    OR eventMessage BEGINSWITH "match:withOptions" OR eventMessage BEGINSWITH "matchResult" \
    OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 63," \
    OR eventMessage BEGINSWITH "statusMessage:withData:timestamp: 64,")) \
    OR (process == "loginwindow" AND (eventMessage CONTAINS "calling to lock screen immediate" \
    OR eventMessage CONTAINS "touchID Screenlock blocked assertion" OR eventMessage CONTAINS "ignore touchID press" \
    OR eventMessage CONTAINS "but pref blocks with DisableScreenLockImmediate" \
    OR eventMessage CONTAINS "sendDistributedNotification: com.apple.screenIs" \
    OR eventMessage CONTAINS "TouchID state:" OR eventMessage CONTAINS "Password required to enable Touch ID" \
    OR eventMessage CONTAINS "startScreenLock:] | entered" OR eventMessage CONTAINS "startUnlock:] | entered"))
    """

/// What a line means, and for the lock's reason and the lock screen's, loginwindow's own name for why.
func classify(process: String, message: String) -> (Kind, String)? {
    switch process {
    case "biometrickitd":
        if message.hasPrefix("touchIDButtonPressed: 1") { return (.keyDown, "") }
        if message.hasPrefix("touchIDButtonPressed: 0") { return (.keyUp, "") }
        if message.hasPrefix("match:withOptions") { return (.readStart, "") }
        if message.hasPrefix("statusMessage:withData:timestamp: 63,") { return (.fingerOn, "") }
        if message.hasPrefix("statusMessage:withData:timestamp: 64,") { return (.fingerOff, "") }
        if message.hasPrefix("matchResult:timestamp: MATCH") { return (.match, "") }
        if message.hasPrefix("matchResult:timestamp:") { return (.noMatch, "") }
    case "loginwindow":
        if message.contains("calling to lock screen immediate") { return (.macLocks, "") }
        if message.contains("touchID Screenlock blocked assertion") { return (.macHeld, "") }
        if message.contains("ignore touchID press") { return (.macDebounce, "") }
        if message.contains("but pref blocks with DisableScreenLockImmediate") { return (.macPref, "") }
        if message.contains("sendDistributedNotification: com.apple.screenIsLocked") { return (.locked, "") }
        if message.contains("sendDistributedNotification: com.apple.screenIsUnlocked") { return (.unlocked, "") }
        if message.contains("TouchID state:3") { return (.touchIDActive, "") }
        if message.contains("TouchID state:2") { return (.touchIDInactive, "") }
        if message.contains("Password required to enable Touch ID") { return (.passwordToEnable, "") }
        if message.contains("startScreenLock:] | entered") { return (.lockReason, loginwindowReason(in: message)) }
        if message.contains("startUnlock:] | entered") { return (.unlockUI, loginwindowReason(in: message)) }
    default:
        break
    }
    return nil
}

/// The first `kLW…` word of a loginwindow line: `kLWLockFromDirectLock`, `kLWUnlockFromUserActive`.
func loginwindowReason(in message: String) -> String {
    message.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        .first { $0.hasPrefix("kLW") }.map(String.init) ?? ""
}

let logTimestamp: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZ"
    return f
}()

/// One `--style ndjson` line: when, which process, what it said.
func parseLogLine(_ line: Data) -> (Date, String, String)? {
    guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
          let stamp = object["timestamp"] as? String, let date = logTimestamp.date(from: stamp),
          let path = object["processImagePath"] as? String,
          let message = object["eventMessage"] as? String
    else { return nil }
    return (date, (path as NSString).lastPathComponent, message)
}

// MARK: - The timeline

final class Timeline {
    struct Mark {
        let kind: Kind
        let date: Date
        let detail: String
    }

    final class Press {
        let start: Date
        let whileLocked: Bool
        var marks: [Mark] = []
        init(start: Date, whileLocked: Bool) {
            self.start = start
            self.whileLocked = whileLocked
        }
    }

    /// A mark this long after a press still belongs to it, unless another press came first.
    static let window = 15.0

    private(set) var presses: [Press] = []
    private var screenLocked = false
    private let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func record(_ kind: Kind, at date: Date, _ detail: String = "") {
        if kind == .keyDown { presses.append(Press(start: date, whileLocked: screenLocked)) }
        if kind == .locked { screenLocked = true }
        if kind == .unlocked { screenLocked = false }
        var relative = String(repeating: " ", count: 8)
        if let press = presses.last {
            let offset = date.timeIntervalSince(press.start)
            if offset > -0.05, offset < Timeline.window {
                relative = String(format: "%+7.3fs", offset)
                press.marks.append(Mark(kind: kind, date: date, detail: detail))
            }
        }
        print("\(clock.string(from: date))  \(relative)  \(kind.rawValue)\(detail.isEmpty ? "" : "  (\(detail))")")
    }

    func summary() {
        print("\n==== \(presses.count) press(es)")
        for (index, press) in presses.enumerated() {
            func first(_ kind: Kind) -> Mark? { press.marks.first { $0.kind == kind } }
            func offset(_ mark: Mark) -> String { String(format: "%+.3f", mark.date.timeIntervalSince(press.start)) }
            let held = first(.keyUp).map { String(format: "%.2f s", $0.date.timeIntervalSince(press.start)) } ?? "?"
            print("Press \(index + 1)  \(clock.string(from: press.start))  key held \(held)"
                  + (press.whileLocked ? "  (pressed while the screen was locked)" : ""))
            let order: [Kind] = [.macLocks, .macHeld, .macDebounce, .macPref, .probeUnlockOff, .probeSleep,
                                 .probeLock, .locked, .lockReason, .unlockUI, .touchIDInactive, .probeUnlockOn,
                                 .passwordToEnable, .touchIDActive, .readStart, .fingerOn, .fingerOff, .match,
                                 .noMatch, .unlocked]
            let parts = order.compactMap { kind in
                first(kind).map { "\(kind.rawValue)\($0.detail.isEmpty ? "" : " [\($0.detail)]") \(offset($0))" }
            }
            print("  " + parts.joined(separator: " · "))
            let unlocks = press.marks.filter { $0.kind == .unlocked }
            let relocks = press.marks.filter { $0.kind == .probeRelock }.count
            var verdict: String
            if relocks > 0 {
                verdict = "\(relocks) unlock(s) by a resting finger, each locked again"
                if unlocks.count > relocks, let last = unlocks.last {
                    verdict += String(format: "; then unlocked %.2f s after the press", last.date.timeIntervalSince(press.start))
                } else {
                    verdict += "; ended locked"
                }
            } else if let unlocked = unlocks.first {
                verdict = String(format: "UNLOCKED %.2f s after the press", unlocked.date.timeIntervalSince(press.start))
            } else if first(.locked) != nil {
                verdict = "stayed locked"
            } else {
                verdict = press.whileLocked ? "no lock (the screen was already locked)" : "never locked"
            }
            print("  => \(verdict)")
        }
    }
}

// MARK: - login.framework

/// loginwindow's session agent, reached through the private login.framework. Each call is a synchronous
/// round trip that answers 0 on success. On macOS 27 all three are in `LFSessionAgentListenerPublicInterface`,
/// the part of the interface that needs no entitlement.
final class SessionAgent {
    private typealias Call = @convention(c) () -> Int32
    private let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_NOW)

    private func call(_ symbol: String) -> Int32 {
        guard let handle, let address = dlsym(handle, symbol) else { return -1 }
        return unsafeBitCast(address, to: Call.self)()
    }

    func takeHold() -> Int32 { call("SACAssertScreenLockViaTouchIDBlocked") }
    func giveBackHold() -> Int32 { call("SACRemoveAssertScreenLockViaTouchIDBlocked") }
    func lockNow() -> Int32 { call("SACLockScreenImmediate") }
}

// MARK: - bioutil

/// "Use Touch ID to unlock your Mac", through Apple's own tool: the one process that carries the
/// entitlement biometrickitd asks for. It answers in about 10 ms. Written for the user, it wants the
/// user's password on its input (measured: "Enter user's (501) password"), so this probe switches the
/// whole Mac's setting instead, as root, through `sudo -n` and /etc/sudoers.d/sherlockme, which allows
/// exactly `bioutil -w -s -u 0` and `bioutil -w -s -u 1`.
enum Bioutil {
    /// Every call goes through one queue, so a switch off and a switch on never overtake each other.
    static let queue = DispatchQueue(label: "touchprobe.bioutil")

    /// Runs a command with no input, so a tool that asks for a password gets none and fails at once.
    static func run(_ command: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command[0])
        process.arguments = Array(command.dropFirst())
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, output.replacingOccurrences(of: "\n", with: " / "))
    }

    /// Touch ID for unlock for the whole Mac: on for `true`, off for `false`.
    static func switchWholeMac(on: Bool) -> (status: Int32, output: String) {
        run(["/usr/bin/sudo", "-n", "/usr/bin/bioutil", "-w", "-s", "-u", on ? "1" : "0"])
    }

    /// Whether the rule lets this user run both switches without a password.
    static func ruleInstalled() -> Bool {
        [false, true].allSatisfy { on in
            run(["/usr/bin/sudo", "-n", "-l", "/usr/bin/bioutil", "-w", "-s", "-u", on ? "1" : "0"]).status == 0
        }
    }

    /// `Effective biometrics for unlock: 1` in `bioutil -r`: the user's setting and the whole Mac's
    /// together. nil when the answer cannot be read.
    static func effectiveUnlock() -> Bool? {
        let (status, output) = run(["/usr/bin/bioutil", "-r"])
        guard status == 0 else { return nil }
        for part in output.components(separatedBy: " / ") {
            let line = part.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Effective biometrics for unlock:") { return line.hasSuffix("1") }
        }
        return nil
    }
}

// MARK: - The live probe

final class Probe {
    let options: Options
    let timeline = Timeline()
    private let agent = SessionAgent()
    private var holding = false
    private var screenLocked = false
    /// A key went down while the screen was unlocked, and its release has not been acted on yet.
    private var pressPending = false
    /// Counts the `touchid` switches off, so that a switch back on scheduled for one of them does not
    /// act once a later one has begun.
    private var cycle = 0
    /// `relock`: when this probe last locked the Mac, when the lock screen then started reading the
    /// sensor, when the resting finger was seen in that read and when it left, and how many times this
    /// press was locked again.
    private var ownLockAt: Date?
    private var readStartAt: Date?
    private var restingOnAt: Date?
    private var restingOffAt: Date?
    private var relocks = 0
    private var logProcess: Process?
    private var buffer = Data()
    private var observers: [NSObjectProtocol] = []
    private var renewal: DispatchSourceTimer?

    /// A finger seen this soon after the lock screen starts reading was already on the sensor. Measured
    /// on the owner's presses: resting fingers 0.001 to 0.42 s into the read, deliberate touches 0.97 s
    /// and later.
    static let restingFingerWithin = 0.5
    /// A finger that leaves this soon was the key coming up, not a finger resting (measured: 17 ms).
    static let blipShorterThan = 0.1
    /// A resting finger that left this long before the unlock did not do it: the match lands 0.2 to 0.25 s
    /// after the finger that gave the image leaves, and a later touch was deliberate.
    static let matchAfterLiftWithin = 0.5
    /// An unlock this soon after the probe's own lock is one it may undo.
    static let relockWindow = 6.0
    /// Once: in every run a Mac locked again stayed locked, and every later unlock was the user's.
    static let relocksPerPress = 1

    init(options: Options) { self.options = options }

    /// `hold`, `relock`, `sleeponly` and `touchid` keep the key from locking the Mac by itself.
    private var holdsTheKey: Bool { [.hold, .relock, .sleeponly, .touchid].contains(options.mode) }

    func start() {
        screenLocked = Probe.sessionIsLocked()
        let centre = DistributedNotificationCenter.default()
        observers.append(centre.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenDidLock()
        })
        observers.append(centre.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.screenDidUnlock()
        })
        startReadingTheLog()
        if holdsTheKey, !screenLocked { takeHold() }
        if holdsTheKey {
            // loginwindow drops a hold 60 s after it was last taken; taking it again resets that.
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 20, repeating: 20)
            timer.setEventHandler { [weak self] in
                guard let self, self.holding else { return }
                let result = self.agent.takeHold()
                if result != 0 { self.timeline.record(.probeHold, at: Date(), "renewal FAILED, result \(result)") }
            }
            timer.resume()
            renewal = timer
        }
    }

    func finish() -> Never {
        if options.mode == .touchid {
            // A switch still under way finishes first; then Touch ID is put back on if it is off, which is
            // how this mode found it.
            Bioutil.queue.sync {}
            if Bioutil.effectiveUnlock() != true {
                let (status, output) = Bioutil.switchWholeMac(on: true)
                timeline.record(.probeUnlockOn, at: Date(), "on the way out, status \(status): \(output)")
            }
        }
        giveBackHold()
        logProcess?.terminate()
        timeline.summary()
        if options.mode == .touchid {
            let now = Bioutil.effectiveUnlock().map { $0 ? "on" : "OFF (sudo bioutil -w -s -u 1 puts it back)" }
                ?? "unreadable"
            print("Touch ID for unlock is now \(now).")
        }
        exit(0)
    }

    static func sessionIsLocked() -> Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (session["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    private func takeHold() {
        let result = agent.takeHold()
        holding = result == 0
        timeline.record(.probeHold, at: Date(), "result \(result)")
    }

    private func giveBackHold() {
        guard holding else { return }
        let result = agent.giveBackHold()
        holding = false
        timeline.record(.probeRelease, at: Date(), "result \(result)")
    }

    private func screenDidLock() {
        screenLocked = true
        pressPending = false
        if holdsTheKey { giveBackHold() }
    }

    private func screenDidUnlock() {
        screenLocked = false
        if holdsTheKey { takeHold() }
        if options.mode == .relock { relockIfTheRestingFingerDidIt() }
    }

    /// `relock`: an unlock soon after this probe's own lock, by the finger the lock screen found on the
    /// sensor as it started reading (still there, or gone just before the match), was the finger that
    /// pressed the key. The Mac is locked again at once.
    private func relockIfTheRestingFingerDidIt() {
        let now = Date()
        defer {
            readStartAt = nil
            restingOnAt = nil
            restingOffAt = nil
        }
        guard let lock = ownLockAt, now.timeIntervalSince(lock) < Probe.relockWindow,
              let read = readStartAt, let on = restingOnAt,
              restingOffAt.map({ now.timeIntervalSince($0) <= Probe.matchAfterLiftWithin }) ?? true,
              relocks < Probe.relocksPerPress
        else { return }
        relocks += 1
        timeline.record(.probeRelock, at: now, String(format: "finger seen %.2f s into the read, relock %d in %d ms",
                                                      on.timeIntervalSince(read), relocks, options.relockAfterMs))
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(options.relockAfterMs)) { [self] in
            // Unlocked on purpose meanwhile, or locked by someone else: nothing to undo.
            guard !screenLocked else { return }
            lockNow()
            ownLockAt = Date()
        }
    }

    /// `touchid`: Touch ID for unlock off, then the lock, then Touch ID back on after --on-after-ms. The
    /// lock waits for the switch, so the lock screen never starts with Touch ID on.
    private func switchOffThenLock() {
        cycle += 1
        let thisCycle = cycle
        let started = Date()
        // The probe lives until the process exits, so its closures hold it strongly.
        Bioutil.queue.async { [self] in
            let (status, output) = Bioutil.switchWholeMac(on: false)
            DispatchQueue.main.async { [self] in
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                timeline.record(.probeUnlockOff, at: Date(), "status \(status), \(ms) ms: \(output)")
                lockNow()
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(options.onAfterMs)) { [self] in
                    switchBackOn(cycle: thisCycle)
                }
            }
        }
    }

    private func switchBackOn(cycle thisCycle: Int) {
        guard thisCycle == cycle else { return }
        let started = Date()
        Bioutil.queue.async { [self] in
            let (status, output) = Bioutil.switchWholeMac(on: true)
            DispatchQueue.main.async { [self] in
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                timeline.record(.probeUnlockOn, at: Date(), "status \(status), \(ms) ms: \(output)")
            }
        }
    }

    private func sleepDisplays() {
        timeline.record(.probeSleep, at: Date())
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["displaysleepnow"]
        try? pmset.run()
    }

    private func lockNow() {
        let result = agent.lockNow()
        timeline.record(.probeLock, at: Date(), "result \(result)")
    }

    private func handle(_ kind: Kind, at date: Date, _ detail: String) {
        timeline.record(kind, at: date, detail)
        switch kind {
        case .keyDown:
            guard !screenLocked else {
                // A press on the lock screen is the user unlocking: nothing after it is undone.
                if options.mode == .relock { ownLockAt = nil }
                return
            }
            pressPending = true
            if options.mode == .sleepfirst { sleepDisplays() }
            if options.mode == .sleeponly, options.at == .down { sleepDisplays() }
            if options.mode == .touchid { switchOffThenLock() }
            if options.mode == .relock {
                relocks = 0
                readStartAt = nil
                restingOnAt = nil
                restingOffAt = nil
                lockNow()
                ownLockAt = Date()
            }
        case .readStart:
            guard options.mode == .relock, let lock = ownLockAt else { return }
            let sinceLock = date.timeIntervalSince(lock)
            if sinceLock > -0.5, sinceLock < 3 {
                readStartAt = date
                restingOnAt = nil
                restingOffAt = nil
            }
        case .fingerOn:
            guard options.mode == .relock, let read = readStartAt, restingOnAt == nil else { return }
            if date.timeIntervalSince(read) <= Probe.restingFingerWithin { restingOnAt = date }
        case .fingerOff:
            guard options.mode == .relock, let on = restingOnAt, restingOffAt == nil else { return }
            if date.timeIntervalSince(on) < Probe.blipShorterThan {
                restingOnAt = nil
            } else {
                restingOffAt = date
            }
        case .keyUp:
            guard pressPending else { return }
            pressPending = false
            guard !screenLocked else { return }
            if options.mode == .hold {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(options.delayMs)) { [weak self] in
                    self?.actAfterRelease()
                }
            }
            if options.mode == .sleeponly, options.at == .up {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(options.delayMs)) { [weak self] in
                    guard let self, !self.screenLocked else { return }
                    self.sleepDisplays()
                }
            }
        default:
            break
        }
    }

    private func actAfterRelease() {
        guard !screenLocked else { return }
        switch options.then {
        case .immediate:
            lockNow()
        case .sleep:
            sleepDisplays()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(150)) { [weak self] in self?.lockNow() }
        case .none:
            break
        }
    }

    private func startReadingTheLog() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = ["stream", "--style", "ndjson", "--predicate", predicate]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            DispatchQueue.main.async { self?.consume(chunk) }
        }
        process.terminationHandler = { process in
            DispatchQueue.main.async {
                print("log stream stopped (status \(process.terminationStatus)); an administrator account is needed")
            }
        }
        do {
            try process.run()
        } catch {
            print("cannot start log stream: \(error)")
            exit(1)
        }
        logProcess = process
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let (date, process, message) = parseLogLine(Data(line)),
                  let (kind, detail) = classify(process: process, message: message) else { continue }
            handle(kind, at: date, detail)
        }
    }
}

// MARK: - Main

setvbuf(stdout, nil, _IOLBF, 0)
let options = parseOptions()

if options.mode == .replay {
    let show = Process()
    show.executableURL = URL(fileURLWithPath: "/usr/bin/log")
    show.arguments = ["show", "--style", "ndjson", "--start", options.start!, "--end", options.end!,
                      "--predicate", predicate]
    let pipe = Pipe()
    show.standardOutput = pipe
    show.standardError = FileHandle.nullDevice
    try show.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    show.waitUntilExit()
    let timeline = Timeline()
    for line in output.split(separator: UInt8(ascii: "\n")) {
        guard let (date, process, message) = parseLogLine(Data(line)),
              let (kind, detail) = classify(process: process, message: message) else { continue }
        timeline.record(kind, at: date, detail)
    }
    timeline.summary()
    exit(0)
}

let probe = Probe(options: options)
switch options.mode {
case .watch:
    print("Watching for \(Int(options.seconds)) s. Press the Touch ID key as you usually do, unlock, repeat.")
case .hold:
    print("For \(Int(options.seconds)) s the Touch ID key does not lock the Mac by itself; this probe locks it"
          + " \(options.delayMs) ms after the key comes up (then: \(options.then.rawValue)).")
case .sleepfirst:
    print("For \(Int(options.seconds)) s the displays go to sleep the moment the Touch ID key goes down;"
          + " macOS locks as usual.")
case .relock:
    print("For \(Int(options.seconds)) s this probe locks the Mac the moment the Touch ID key goes down, and locks it"
          + " again \(options.relockAfterMs) ms after the finger that pressed the key unlocks it.")
case .sleeponly:
    print("For \(Int(options.seconds)) s the Touch ID key does not lock the Mac by itself; this probe puts the"
          + " displays to sleep " + (options.at == .down ? "the moment the key goes down"
                                                        : "\(options.delayMs) ms after the key comes up")
          + ", and nothing else.")
case .touchid:
    guard Bioutil.ruleInstalled() else {
        print("The rule in /etc/sudoers.d/sherlockme is missing: sudo -n cannot run bioutil -w -s -u 0 and 1.")
        exit(1)
    }
    guard Bioutil.effectiveUnlock() == true else {
        print("Touch ID for unlock is not on (bioutil -r); this mode runs only while it is.")
        exit(1)
    }
    print("For \(Int(options.seconds)) s, the moment the Touch ID key goes down this probe switches Touch ID for"
          + " unlock off for the whole Mac, locks it, and switches it back on \(options.onAfterMs) ms later."
          + " If it is killed with Touch ID off: sudo bioutil -w -s -u 1")
case .replay:
    break
}
probe.start()
DispatchQueue.main.asyncAfter(deadline: .now() + options.seconds) { probe.finish() }
var signalSources: [DispatchSourceSignal] = []
for number in [SIGINT, SIGTERM] {
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
    source.setEventHandler { probe.finish() }
    source.resume()
    signalSources.append(source)
}
dispatchMain()
