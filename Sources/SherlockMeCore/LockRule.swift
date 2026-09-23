import Foundation

/// SherlockMe's behaviour, as a value: what the log says, with the time it says it, in; what to do, out. It
/// never reads a clock and never touches the Mac, so every sentence below is a test (`LockRuleTests`), and a
/// recording of the log plays through it (`RulePlayer`). `docs/functional.md` §1 states the same rule in words.
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
